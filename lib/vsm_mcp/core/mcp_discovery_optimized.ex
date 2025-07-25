defmodule VsmMcp.Core.MCPDiscoveryOptimized do
  @moduledoc """
  Optimized MCP Discovery with parallel execution and connection pooling.
  
  Key optimizations:
  - Parallel MCP server discovery using Task.async_stream
  - Connection pooling for HTTP requests using Finch
  - Batch processing for multiple capability searches
  - Non-blocking installation processes
  - Concurrent server installations
  - ETS-based discovery cache
  """
  use GenServer
  require Logger
  
  @mcp_registry_url "https://mcp-registry.anthropic.com/api/v1"
  @npm_registry_url "https://registry.npmjs.org"
  @github_api_url "https://api.github.com"
  
  # ETS tables
  @discovery_cache :mcp_discovery_cache
  @capability_index :mcp_capability_index
  
  # Performance settings
  @max_concurrent_searches 10
  @max_concurrent_installs 5
  @http_pool_size 20
  @http_timeout 10_000
  @cache_ttl_ms 300_000  # 5 minutes
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def discover_and_acquire_parallel(required_capabilities) do
    GenServer.call(__MODULE__, {:discover_acquire_parallel, required_capabilities}, 60_000)
  end
  
  def search_mcp_servers_parallel(search_terms_list) do
    GenServer.call(__MODULE__, {:search_parallel, search_terms_list}, 30_000)
  end
  
  def install_mcp_servers_batch(server_infos) do
    GenServer.call(__MODULE__, {:install_batch, server_infos}, 120_000)
  end
  
  def prefetch_popular_servers do
    GenServer.cast(__MODULE__, :prefetch_popular)
  end
  
  def build_capability_index do
    GenServer.cast(__MODULE__, :build_index)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    # Create ETS tables
    :ets.new(@discovery_cache, [:named_table, :public, :set, {:read_concurrency, true}])
    :ets.new(@capability_index, [:named_table, :public, :bag, {:read_concurrency, true}])
    
    # Start Finch HTTP pool
    children = [
      {Finch, name: MCPFinch, pools: %{
        default: [size: @http_pool_size, count: 1]
      }}
    ]
    
    Supervisor.start_link(children, strategy: :one_for_one, name: MCPDiscoverySupervisor)
    
    state = %{
      installed_servers: %{},
      installation_path: opts[:path] || "/tmp/vsm_mcp_servers",
      sandbox_enabled: opts[:sandbox] || true,
      metrics: %{
        searches_performed: 0,
        parallel_searches: 0,
        servers_discovered: 0,
        servers_installed: 0,
        capabilities_acquired: 0,
        cache_hits: 0,
        http_requests: 0
      },
      popular_servers: [
        "@anthropic/mcp-server-filesystem",
        "@anthropic/mcp-server-github",
        "@anthropic/mcp-server-postgres",
        "@anthropic/mcp-server-brave-search"
      ]
    }
    
    # Ensure installation directory exists
    File.mkdir_p!(state.installation_path)
    
    # Start background tasks
    Process.send_after(self(), :cleanup_cache, @cache_ttl_ms)
    Process.send_after(self(), :prefetch_popular, 5_000)
    
    Logger.info("Optimized MCP Discovery initialized - installation path: #{state.installation_path}")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:discover_acquire_parallel, required_capabilities}, _from, state) do
    Logger.info("Starting parallel capability acquisition for: #{inspect(required_capabilities)}")
    
    # Parallel search for all capabilities
    {search_results, search_time} = :timer.tc(fn ->
      search_for_capabilities_parallel(required_capabilities, state)
    end)
    
    Logger.info("Parallel search completed in #{search_time / 1000}ms, found #{length(search_results)} servers")
    
    # Rank and select best matches
    selected_servers = select_best_servers_optimized(search_results, required_capabilities)
    
    # Install selected servers in parallel
    {installed, install_time, new_state} = :timer.tc(fn ->
      install_servers_parallel(selected_servers, state)
    end)
    
    Logger.info("Parallel installation completed in #{install_time / 1000}ms")
    
    # Map capabilities to installed servers
    capability_mapping = map_capabilities_optimized(installed, required_capabilities)
    
    result = %{
      searched: length(search_results),
      selected: length(selected_servers),
      installed: map_size(installed),
      capabilities: capability_mapping,
      success: map_size(installed) > 0,
      performance: %{
        search_time_ms: search_time / 1000,
        install_time_ms: install_time / 1000
      }
    }
    
    {:reply, {:ok, result}, new_state}
  end
  
  @impl true
  def handle_call({:search_parallel, search_terms_list}, _from, state) do
    results = search_terms_list
      |> Task.async_stream(
        fn terms -> perform_search_cached(terms, state) end,
        max_concurrency: @max_concurrent_searches,
        timeout: @http_timeout
      )
      |> Enum.flat_map(fn
        {:ok, results} -> results
        {:exit, _} -> []
      end)
      |> Enum.uniq_by(& &1.name)
    
    new_state = state
      |> update_metrics(:searches_performed, length(search_terms_list))
      |> update_metrics(:parallel_searches)
    
    {:reply, {:ok, results}, new_state}
  end
  
  @impl true
  def handle_call({:install_batch, server_infos}, _from, state) do
    {installed, new_state} = install_servers_parallel(server_infos, state)
    
    {:reply, {:ok, installed}, new_state}
  end
  
  @impl true
  def handle_cast(:prefetch_popular, state) do
    # Prefetch popular servers in background
    Task.start_link(fn ->
      Enum.each(state.popular_servers, fn server_name ->
        search_terms = [server_name]
        perform_search_cached(search_terms, state)
      end)
    end)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast(:build_index, state) do
    # Build capability index in background
    Task.start_link(fn ->
      build_capability_index_async(state)
    end)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:cleanup_cache, state) do
    # Clean expired cache entries
    now = System.monotonic_time(:millisecond)
    
    :ets.select_delete(@discovery_cache, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    
    # Schedule next cleanup
    Process.send_after(self(), :cleanup_cache, @cache_ttl_ms)
    
    {:noreply, state}
  end
  
  # Private Functions - Parallel Search
  
  defp search_for_capabilities_parallel(capabilities, state) do
    # Create search tasks for each capability
    search_tasks = capabilities
      |> Enum.map(fn capability ->
        Task.async(fn ->
          perform_search_cached(capability.search_terms, state)
        end)
      end)
    
    # Wait for all searches to complete
    search_tasks
    |> Task.await_many(@http_timeout)
    |> Enum.flat_map(& &1)
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(& &1.relevance_score, :desc)
  end
  
  defp perform_search_cached(search_terms, state) do
    cache_key = :erlang.phash2(search_terms)
    
    case get_from_cache(cache_key) do
      {:ok, cached_results} ->
        update_metrics_async(:cache_hits)
        cached_results
      
      :not_found ->
        results = search_mcp_sources_parallel(search_terms, state)
        put_in_cache(cache_key, results, @cache_ttl_ms)
        results
    end
  end
  
  defp search_mcp_sources_parallel(search_terms, state) do
    # Search multiple sources in parallel
    search_tasks = [
      Task.async(fn -> search_npm_optimized(search_terms, state) end),
      Task.async(fn -> search_github_optimized(search_terms, state) end),
      Task.async(fn -> search_mcp_registry_optimized(search_terms, state) end),
      Task.async(fn -> search_capability_index(search_terms) end)
    ]
    
    results = search_tasks
      |> Task.await_many(@http_timeout)
      |> Enum.flat_map(& &1)
      |> Enum.uniq_by(& &1.name)
      |> Enum.sort_by(& &1.relevance_score, :desc)
    
    update_metrics_async(:servers_discovered, length(results))
    results
  end
  
  defp search_npm_optimized(search_terms, state) do
    query = Enum.join(search_terms, "+")
    url = "#{@npm_registry_url}/-/v1/search?text=mcp+#{query}&size=20"
    
    case http_get(url) do
      {:ok, %{"objects" => objects}} ->
        objects
        |> Stream.filter(&is_mcp_package?/1)
        |> Stream.map(&npm_to_server_info_optimized/1)
        |> Enum.to_list()
      
      _ ->
        []
    end
  end
  
  defp search_github_optimized(search_terms, state) do
    query = "mcp+server+" <> Enum.join(search_terms, "+")
    url = "#{@github_api_url}/search/repositories?q=#{query}&sort=stars&per_page=10"
    
    case http_get(url) do
      {:ok, %{"items" => items}} ->
        items
        |> Stream.filter(&is_mcp_repository?/1)
        |> Stream.map(&github_to_server_info/1)
        |> Enum.to_list()
      
      _ ->
        []
    end
  end
  
  defp search_mcp_registry_optimized(search_terms, state) do
    # Search official MCP registry (when available)
    []
  end
  
  defp search_capability_index(search_terms) do
    # Search pre-built capability index
    search_terms
    |> Enum.flat_map(fn term ->
      case :ets.lookup(@capability_index, String.to_atom(term)) do
        results -> Enum.map(results, fn {_, server_info} -> server_info end)
      end
    end)
    |> Enum.uniq_by(& &1.name)
  end
  
  # HTTP client with connection pooling
  
  defp http_get(url) do
    request = Finch.build(:get, url, [{"User-Agent", "VSM-MCP/1.0"}])
    
    case Finch.request(request, MCPFinch) do
      {:ok, %{status: 200, body: body}} ->
        update_metrics_async(:http_requests)
        Jason.decode(body)
      
      {:ok, %{status: status}} ->
        Logger.warning("HTTP request failed with status #{status}: #{url}")
        {:error, :http_error}
      
      {:error, reason} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Optimized server selection
  
  defp select_best_servers_optimized(search_results, required_capabilities) do
    # Score servers in parallel
    scored_servers = search_results
      |> Task.async_stream(
        fn server ->
          score = calculate_capability_match_score_optimized(server, required_capabilities)
          {server, score}
        end,
        max_concurrency: System.schedulers_online()
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.sort_by(fn {_, score} -> score end, :desc)
      |> Enum.take(5)  # Take top 5 matches
      |> Enum.map(fn {server, _} -> server end)
    
    scored_servers
  end
  
  defp calculate_capability_match_score_optimized(server, required_capabilities) do
    server_caps = MapSet.new(server.capabilities)
    
    # Parallel scoring for each required capability
    scores = required_capabilities
      |> Task.async_stream(
        fn req_cap ->
          required_terms = MapSet.new(req_cap.search_terms |> Enum.map(&String.to_atom/1))
          
          overlap = MapSet.intersection(server_caps, required_terms) |> MapSet.size()
          total = MapSet.size(required_terms)
          
          base_score = if total > 0, do: overlap / total, else: 0
          
          # Boost score based on priority
          priority_multiplier = case req_cap.priority do
            :high -> 2.0
            :medium -> 1.5
            _ -> 1.0
          end
          
          base_score * priority_multiplier
        end,
        max_concurrency: 4
      )
      |> Enum.map(fn {:ok, score} -> score end)
      |> Enum.sum()
    
    # Factor in server quality
    scores * server.relevance_score * quality_score(server)
  end
  
  defp quality_score(server) do
    # Enhanced quality scoring
    base_score = 0.5
    
    # Boost for official packages
    base_score = if String.starts_with?(server.name, "@anthropic/"), do: base_score + 0.3, else: base_score
    
    # Boost for recent updates
    base_score = if server[:last_updated] && recent?(server.last_updated), do: base_score + 0.1, else: base_score
    
    # Boost for popularity
    base_score = if server[:downloads] && server.downloads > 1000, do: base_score + 0.1, else: base_score
    
    min(base_score, 1.0)
  end
  
  defp recent?(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        Date.diff(Date.utc_today(), date) < 180  # Updated within 6 months
      _ ->
        false
    end
  end
  
  # Parallel installation
  
  defp install_servers_parallel(servers, state) do
    # Install servers concurrently with limited parallelism
    results = servers
      |> Task.async_stream(
        fn server ->
          case install_server_optimized(server, state) do
            {:ok, installation} ->
              # Update capability index
              update_capability_index(server, installation)
              {server.name, installation}
            
            {:error, reason} ->
              Logger.error("Failed to install #{server.name}: #{reason}")
              nil
          end
        end,
        max_concurrency: @max_concurrent_installs,
        timeout: 30_000
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, _} -> nil
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()
    
    new_state = state
      |> Map.update!(:installed_servers, &Map.merge(&1, results))
      |> update_metrics(:servers_installed, map_size(results))
    
    {results, new_state}
  end
  
  defp install_server_optimized(server_info, state) do
    install_dir = Path.join(state.installation_path, server_info.name)
    
    # Check if already installed
    if Map.has_key?(state.installed_servers, server_info.name) do
      {:ok, state.installed_servers[server_info.name]}
    else
      try do
        File.mkdir_p!(install_dir)
        
        case server_info.source do
          :npm -> install_npm_server_optimized(server_info, install_dir, state)
          :github -> install_github_server_optimized(server_info, install_dir, state)
          _ -> {:error, "Unknown source: #{server_info.source}"}
        end
      rescue
        e ->
          {:error, "Installation failed: #{Exception.message(e)}"}
      end
    end
  end
  
  defp install_npm_server_optimized(server_info, install_dir, state) do
    # Use npm ci for faster, more reliable installs
    init_cmd = "cd #{install_dir} && npm init -y --silent"
    install_cmd = if state.sandbox_enabled do
      "cd #{install_dir} && npm install #{server_info.package_name} --no-save --prefer-offline --no-audit --silent"
    else
      "cd #{install_dir} && npm ci #{server_info.package_name} --prefer-offline --no-audit --silent"
    end
    
    with {_, 0} <- System.cmd("sh", ["-c", init_cmd], stderr_to_stdout: true),
         {_, 0} <- System.cmd("sh", ["-c", install_cmd], stderr_to_stdout: true) do
      
      installation = %{
        name: server_info.name,
        version: server_info.version,
        path: install_dir,
        capabilities: server_info.capabilities,
        installed_at: DateTime.utc_now(),
        status: :active,
        metadata: extract_server_metadata(install_dir, server_info)
      }
      
      {:ok, installation}
    else
      {output, exit_code} ->
        {:error, "npm install failed with code #{exit_code}: #{output}"}
    end
  end
  
  defp install_github_server_optimized(server_info, install_dir, state) do
    clone_cmd = "git clone --depth 1 #{server_info.repository} #{install_dir}"
    install_cmd = "cd #{install_dir} && npm install --production --prefer-offline --no-audit --silent"
    
    with {_, 0} <- System.cmd("sh", ["-c", clone_cmd], stderr_to_stdout: true),
         {_, 0} <- System.cmd("sh", ["-c", install_cmd], stderr_to_stdout: true) do
      
      installation = %{
        name: server_info.name,
        version: "latest",
        path: install_dir,
        capabilities: server_info.capabilities,
        installed_at: DateTime.utc_now(),
        status: :active,
        metadata: extract_server_metadata(install_dir, server_info)
      }
      
      {:ok, installation}
    else
      {output, exit_code} ->
        {:error, "GitHub installation failed with code #{exit_code}: #{output}"}
    end
  end
  
  defp extract_server_metadata(install_dir, server_info) do
    # Extract additional metadata from package.json
    package_json_path = Path.join(install_dir, "package.json")
    
    case File.read(package_json_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, package_data} ->
            %{
              description: package_data["description"],
              author: package_data["author"],
              keywords: package_data["keywords"] || [],
              mcp_version: package_data["mcp"] || package_data["mcpVersion"]
            }
          _ ->
            %{}
        end
      _ ->
        %{}
    end
  end
  
  # Capability mapping and indexing
  
  defp map_capabilities_optimized(installed_servers, required_capabilities) do
    # Build reverse index for fast lookup
    capability_to_servers = installed_servers
      |> Enum.reduce(%{}, fn {server_name, installation}, acc ->
        Enum.reduce(installation.capabilities, acc, fn cap, acc2 ->
          Map.update(acc2, cap, [server_name], &[server_name | &1])
        end)
      end)
    
    # Map required capabilities to servers
    required_capabilities
    |> Enum.map(fn req_cap ->
      matching_servers = req_cap.search_terms
        |> Enum.flat_map(fn term ->
          Map.get(capability_to_servers, String.to_atom(term), [])
        end)
        |> Enum.uniq()
      
      {req_cap.type, matching_servers}
    end)
    |> Map.new()
  end
  
  defp update_capability_index(server_info, installation) do
    # Update ETS capability index
    Enum.each(installation.capabilities, fn capability ->
      :ets.insert(@capability_index, {capability, server_info})
    end)
    
    # Also index by keywords
    metadata = installation[:metadata] || %{}
    keywords = metadata[:keywords] || []
    
    Enum.each(keywords, fn keyword ->
      :ets.insert(@capability_index, {String.to_atom(keyword), server_info})
    end)
  end
  
  defp build_capability_index_async(state) do
    # Build comprehensive capability index from installed servers
    Enum.each(state.installed_servers, fn {_, installation} ->
      server_info = %{
        name: installation.name,
        capabilities: installation.capabilities,
        relevance_score: 0.8
      }
      
      update_capability_index(server_info, installation)
    end)
    
    Logger.info("Capability index built with #{:ets.info(@capability_index, :size)} entries")
  end
  
  # Helper functions
  
  defp is_mcp_package?(package) do
    name = get_in(package, ["package", "name"]) || ""
    description = get_in(package, ["package", "description"]) || ""
    keywords = get_in(package, ["package", "keywords"]) || []
    
    String.contains?(name, "mcp") or
    String.contains?(description, "Model Context Protocol") or
    "mcp" in keywords or
    "model-context-protocol" in keywords
  end
  
  defp is_mcp_repository?(repo) do
    name = repo["name"] || ""
    description = repo["description"] || ""
    topics = repo["topics"] || []
    
    String.contains?(name, "mcp") or
    String.contains?(description, "Model Context Protocol") or
    "mcp" in topics or
    "model-context-protocol" in topics
  end
  
  defp npm_to_server_info_optimized(npm_package) do
    package = npm_package["package"]
    
    %{
      name: package["name"],
      version: package["version"],
      description: package["description"],
      source: :npm,
      package_name: package["name"],
      relevance_score: get_in(npm_package, ["score", "final"]) || 0.5,
      capabilities: extract_capabilities_optimized(package),
      author: get_in(package, ["author", "name"]),
      repository: get_in(package, ["links", "repository"]),
      last_updated: package["date"],
      downloads: get_in(npm_package, ["score", "detail", "popularity"]) || 0
    }
  end
  
  defp github_to_server_info(repo) do
    %{
      name: repo["name"],
      version: "latest",
      description: repo["description"],
      source: :github,
      repository: repo["clone_url"],
      relevance_score: calculate_github_relevance(repo),
      capabilities: extract_capabilities_from_topics(repo["topics"]),
      author: get_in(repo, ["owner", "login"]),
      last_updated: repo["updated_at"],
      stars: repo["stargazers_count"]
    }
  end
  
  defp calculate_github_relevance(repo) do
    stars = repo["stargazers_count"] || 0
    forks = repo["forks_count"] || 0
    
    # Simple relevance calculation
    base_score = 0.5
    star_bonus = min(stars / 1000, 0.3)
    fork_bonus = min(forks / 100, 0.2)
    
    base_score + star_bonus + fork_bonus
  end
  
  defp extract_capabilities_optimized(package) do
    # Extract from multiple sources
    description = String.downcase(package["description"] || "")
    keywords = package["keywords"] || []
    
    # Capability patterns
    capability_patterns = %{
      file: ~r/file|fs|filesystem|directory/,
      database: ~r/database|db|sql|postgres|mysql|sqlite/,
      api: ~r/api|rest|graphql|http/,
      web: ~r/web|browser|scrape|fetch/,
      search: ~r/search|find|query/,
      analyze: ~r/analyze|analysis|insight/,
      process: ~r/process|transform|convert/,
      monitor: ~r/monitor|watch|observe/,
      optimize: ~r/optimize|improve|enhance/,
      generate: ~r/generate|create|build/
    }
    
    # Find matching capabilities
    capabilities = capability_patterns
      |> Enum.filter(fn {_, pattern} ->
        Regex.match?(pattern, description) or
        Enum.any?(keywords, &Regex.match?(pattern, String.downcase(&1)))
      end)
      |> Enum.map(fn {capability, _} -> capability end)
    
    # Add keywords as capabilities
    keyword_capabilities = keywords
      |> Enum.map(&String.to_atom/1)
      |> Enum.filter(&(&1 in [:mcp, :ai, :llm, :tool]))
    
    Enum.uniq(capabilities ++ keyword_capabilities)
  end
  
  defp extract_capabilities_from_topics(topics) do
    topics
    |> Enum.map(&String.to_atom/1)
    |> Enum.filter(fn topic ->
      topic in [:mcp, :ai, :database, :api, :file, :web, :search]
    end)
  end
  
  # Cache management
  
  defp get_from_cache(key) do
    case :ets.lookup(@discovery_cache, key) do
      [{^key, value, expiry}] ->
        if System.monotonic_time(:millisecond) < expiry do
          {:ok, value}
        else
          :ets.delete(@discovery_cache, key)
          :not_found
        end
      [] ->
        :not_found
    end
  end
  
  defp put_in_cache(key, value, ttl_ms) do
    expiry = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(@discovery_cache, {key, value, expiry})
  end
  
  # Metrics
  
  defp update_metrics(state, metric, count \\ 1) do
    put_in(state.metrics[metric], Map.get(state.metrics, metric, 0) + count)
  end
  
  defp update_metrics_async(metric, count \\ 1) do
    Task.start(fn ->
      :ets.update_counter(@discovery_cache, {:metrics, metric}, {2, count}, {{:metrics, metric}, 0})
    end)
  end
end