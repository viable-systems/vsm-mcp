defmodule VsmMcp.Core.MCPDiscovery do
  @moduledoc """
  MCP Discovery and Capability Acquisition.
  
  Automatically discovers and integrates MCP servers to acquire new capabilities
  when variety gaps are detected.
  """
  use GenServer
  require Logger
  
  @mcp_registry_url "https://mcp-registry.anthropic.com/api/v1"
  @npm_registry_url "https://registry.npmjs.org"
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def discover_and_acquire(required_capabilities) do
    GenServer.call(__MODULE__, {:discover_acquire, required_capabilities}, 30_000)
  end
  
  def search_mcp_servers(search_terms) do
    GenServer.call(__MODULE__, {:search, search_terms})
  end
  
  def install_mcp_server(server_info) do
    GenServer.call(__MODULE__, {:install, server_info}, 60_000)
  end
  
  def list_installed_servers do
    GenServer.call(__MODULE__, :list_installed)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    state = %{
      installed_servers: %{},
      discovery_cache: %{},
      installation_path: opts[:path] || "/tmp/vsm_mcp_servers",
      sandbox_enabled: opts[:sandbox] || true,
      metrics: %{
        searches_performed: 0,
        servers_discovered: 0,
        servers_installed: 0,
        capabilities_acquired: 0
      }
    }
    
    # Ensure installation directory exists
    File.mkdir_p!(state.installation_path)
    
    Logger.info("MCP Discovery initialized - installation path: #{state.installation_path}")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:discover_acquire, required_capabilities}, _from, state) do
    Logger.info("Starting capability acquisition for: #{inspect(required_capabilities)}")
    
    # Search for relevant MCP servers
    search_results = search_for_capabilities(required_capabilities, state)
    
    # Rank and select best matches
    selected_servers = select_best_servers(search_results, required_capabilities)
    
    # Install selected servers
    {installed, new_state} = install_servers(selected_servers, state)
    
    # Map capabilities to installed servers
    capability_mapping = map_capabilities_to_servers(installed, required_capabilities)
    
    result = %{
      searched: length(search_results),
      selected: length(selected_servers),
      installed: length(installed),
      capabilities: capability_mapping,
      success: length(installed) > 0
    }
    
    {:reply, {:ok, result}, new_state}
  end
  
  @impl true
  def handle_call({:search, search_terms}, _from, state) do
    results = perform_search(search_terms, state)
    
    new_state = update_metrics(state, :searches_performed)
    {:reply, {:ok, results}, new_state}
  end
  
  @impl true
  def handle_call({:install, server_info}, _from, state) do
    case install_server(server_info, state) do
      {:ok, installation} ->
        new_state = state
          |> Map.update!(:installed_servers, &Map.put(&1, server_info.name, installation))
          |> update_metrics(:servers_installed)
        
        {:reply, {:ok, installation}, new_state}
      
      {:error, reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:list_installed, _from, state) do
    {:reply, {:ok, state.installed_servers}, state}
  end
  
  # Private Functions
  
  defp search_for_capabilities(capabilities, state) do
    capabilities
    |> Enum.flat_map(fn capability ->
      search_terms = capability.search_terms
      perform_search(search_terms, state)
    end)
    |> Enum.uniq_by(& &1.name)
  end
  
  defp perform_search(search_terms, state) do
    # Check cache first
    cache_key = :erlang.phash2(search_terms)
    
    case Map.get(state.discovery_cache, cache_key) do
      nil ->
        # Perform actual search
        results = search_mcp_sources(search_terms)
        
        # Cache results for 1 hour
        Process.send_after(self(), {:clear_cache, cache_key}, 3600_000)
        
        results
      
      cached ->
        cached
    end
  end
  
  defp search_mcp_sources(search_terms) do
    # Search multiple sources
    npm_results = search_npm(search_terms)
    github_results = search_github(search_terms)
    registry_results = search_mcp_registry(search_terms)
    
    # Combine and deduplicate
    (npm_results ++ github_results ++ registry_results)
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(& &1.relevance_score, :desc)
  end
  
  defp search_npm(search_terms) do
    query = Enum.join(search_terms, "+")
    url = "#{@npm_registry_url}/-/v1/search?text=mcp+#{query}&size=10"
    
    case HTTPoison.get(url) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"objects" => objects}} ->
            objects
            |> Enum.filter(&is_mcp_package?/1)
            |> Enum.map(&npm_to_server_info/1)
          
          _ ->
            []
        end
      
      _ ->
        []
    end
  end
  
  defp search_github(search_terms) do
    # GitHub search implementation
    # For now, return empty list
    []
  end
  
  defp search_mcp_registry(search_terms) do
    # Official MCP registry search
    # For now, return empty list
    []
  end
  
  defp is_mcp_package?(package) do
    name = get_in(package, ["package", "name"]) || ""
    description = get_in(package, ["package", "description"]) || ""
    keywords = get_in(package, ["package", "keywords"]) || []
    
    String.contains?(name, "mcp") or
    String.contains?(description, "Model Context Protocol") or
    "mcp" in keywords
  end
  
  defp npm_to_server_info(npm_package) do
    package = npm_package["package"]
    
    %{
      name: package["name"],
      version: package["version"],
      description: package["description"],
      source: :npm,
      install_command: "npm install #{package["name"]}",
      relevance_score: npm_package["score"]["final"] || 0.5,
      capabilities: extract_capabilities_from_description(package["description"]),
      author: get_in(package, ["author", "name"]),
      repository: get_in(package, ["links", "repository"])
    }
  end
  
  defp extract_capabilities_from_description(description) do
    # Simple keyword extraction
    capability_keywords = [
      "file", "database", "api", "web", "search", "analyze",
      "process", "transform", "monitor", "optimize", "generate"
    ]
    
    description = String.downcase(description || "")
    
    capability_keywords
    |> Enum.filter(&String.contains?(description, &1))
    |> Enum.map(&String.to_atom/1)
  end
  
  defp select_best_servers(search_results, required_capabilities) do
    search_results
    |> Enum.map(fn server ->
      score = calculate_capability_match_score(server, required_capabilities)
      {server, score}
    end)
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
    |> Enum.take(3)  # Take top 3 matches
    |> Enum.map(fn {server, _} -> server end)
  end
  
  defp calculate_capability_match_score(server, required_capabilities) do
    server_caps = MapSet.new(server.capabilities)
    
    required_capabilities
    |> Enum.map(fn req_cap ->
      required_terms = MapSet.new(req_cap.search_terms |> Enum.map(&String.to_atom/1))
      
      # Calculate overlap
      overlap = MapSet.intersection(server_caps, required_terms) |> MapSet.size()
      total = MapSet.size(required_terms)
      
      if total > 0, do: overlap / total, else: 0
    end)
    |> Enum.sum()
    |> Kernel.*(server.relevance_score)
  end
  
  defp install_servers(servers, state) do
    installed = servers
      |> Enum.map(fn server ->
        case install_server(server, state) do
          {:ok, installation} ->
            {server.name, installation}
          {:error, reason} ->
            Logger.error("Failed to install #{server.name}: #{reason}")
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()
    
    new_state = state
      |> Map.update!(:installed_servers, &Map.merge(&1, installed))
      |> update_metrics(:servers_installed, map_size(installed))
    
    {installed, new_state}
  end
  
  defp install_server(server_info, state) do
    install_dir = Path.join(state.installation_path, server_info.name)
    
    try do
      # Create installation directory
      File.mkdir_p!(install_dir)
      
      # Install based on source
      case server_info.source do
        :npm ->
          install_npm_server(server_info, install_dir, state)
        
        :github ->
          install_github_server(server_info, install_dir, state)
        
        _ ->
          {:error, "Unknown source: #{server_info.source}"}
      end
    rescue
      e ->
        {:error, "Installation failed: #{Exception.message(e)}"}
    end
  end
  
  defp install_npm_server(server_info, install_dir, state) do
    # Run npm install in sandbox if enabled
    cmd = if state.sandbox_enabled do
      "cd #{install_dir} && npm init -y && #{server_info.install_command} --no-save"
    else
      "cd #{install_dir} && npm init -y && #{server_info.install_command}"
    end
    
    case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Successfully installed #{server_info.name}")
        
        installation = %{
          name: server_info.name,
          version: server_info.version,
          path: install_dir,
          capabilities: server_info.capabilities,
          installed_at: DateTime.utc_now(),
          status: :active
        }
        
        {:ok, installation}
      
      {output, exit_code} ->
        {:error, "npm install failed with code #{exit_code}: #{output}"}
    end
  end
  
  defp install_github_server(server_info, install_dir, state) do
    # GitHub installation implementation
    {:error, "GitHub installation not yet implemented"}
  end
  
  defp map_capabilities_to_servers(installed_servers, required_capabilities) do
    required_capabilities
    |> Enum.map(fn req_cap ->
      matching_servers = installed_servers
        |> Enum.filter(fn {_, installation} ->
          Enum.any?(installation.capabilities, fn cap ->
            cap in req_cap.search_terms
          end)
        end)
        |> Enum.map(fn {name, _} -> name end)
      
      {req_cap.type, matching_servers}
    end)
    |> Map.new()
  end
  
  defp update_metrics(state, metric, count \\ 1) do
    Map.update_in(state, [:metrics, metric], &(&1 + count))
  end
  
  @impl true
  def handle_info({:clear_cache, cache_key}, state) do
    new_cache = Map.delete(state.discovery_cache, cache_key)
    {:noreply, Map.put(state, :discovery_cache, new_cache)}
  end
end