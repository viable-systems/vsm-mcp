defmodule VsmMcp.Integration.CapabilityMatcherOptimized do
  @moduledoc """
  Optimized Capability Matcher with parallel processing and intelligent caching.
  
  Key optimizations:
  - Parallel server scoring using Task.async_stream
  - Vector-based similarity matching using :math functions
  - ETS-based caching for repeated matches
  - Batch processing for multiple variety gaps
  - Pre-computed capability vectors
  """
  
  require Logger
  use GenStage
  
  @mcp_catalog_url "https://raw.githubusercontent.com/modelcontextprotocol/servers/main/README.md"
  @min_match_score 0.6
  @vector_dimensions 50
  
  # ETS tables
  @match_cache :capability_match_cache
  @vector_cache :capability_vector_cache
  @catalog_cache :mcp_catalog_cache
  
  # Performance settings
  @max_concurrent_scoring 20
  @cache_ttl_ms 600_000  # 10 minutes
  
  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Finds MCP servers that can fill variety gaps using parallel processing.
  """
  def find_matching_servers_parallel(variety_gaps) when is_list(variety_gaps) do
    variety_gaps
    |> Task.async_stream(
      &find_matching_servers_single/1,
      max_concurrency: @max_concurrent_scoring,
      timeout: 10_000
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, _} -> {:error, :timeout}
    end)
  end
  
  def find_matching_servers_parallel(variety_gap) do
    find_matching_servers_single(variety_gap)
  end
  
  @doc """
  Batch process multiple variety gaps efficiently.
  """
  def match_capabilities_batch(variety_gaps, servers) do
    # Pre-compute server vectors
    server_vectors = servers
      |> Task.async_stream(
        fn server ->
          vector = compute_capability_vector(server)
          {server, vector}
        end,
        max_concurrency: System.schedulers_online()
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Map.new()
    
    # Process variety gaps in parallel
    variety_gaps
    |> Task.async_stream(
      fn gap ->
        gap_vector = compute_gap_vector(gap)
        matches = find_best_matches_vectorized(gap_vector, server_vectors)
        {gap, matches}
      end,
      max_concurrency: @max_concurrent_scoring
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end
  
  # GenStage callbacks for streaming processing
  
  @impl true
  def init(opts) do
    # Create ETS tables
    :ets.new(@match_cache, [:named_table, :public, :set, {:read_concurrency, true}])
    :ets.new(@vector_cache, [:named_table, :public, :set, {:read_concurrency, true}])
    :ets.new(@catalog_cache, [:named_table, :public, :set])
    
    # Start background tasks
    Process.send_after(self(), :cleanup_cache, @cache_ttl_ms)
    Process.send_after(self(), :refresh_catalog, 1_000)
    
    {:producer_consumer, %{demand: 0}, subscribe_to: opts[:subscribe_to] || []}
  end
  
  @impl true
  def handle_events(variety_gaps, _from, state) do
    # Process variety gaps as they come in
    matches = find_matching_servers_parallel(variety_gaps)
    
    {:noreply, matches, state}
  end
  
  @impl true
  def handle_info(:cleanup_cache, state) do
    cleanup_expired_cache()
    Process.send_after(self(), :cleanup_cache, @cache_ttl_ms)
    {:noreply, [], state}
  end
  
  @impl true
  def handle_info(:refresh_catalog, state) do
    Task.start_link(&refresh_catalog_async/0)
    Process.send_after(self(), :refresh_catalog, 3_600_000)  # Refresh hourly
    {:noreply, [], state}
  end
  
  # Private functions
  
  defp find_matching_servers_single(variety_gap) do
    cache_key = :erlang.phash2(variety_gap)
    
    case get_from_cache(@match_cache, cache_key) do
      {:ok, cached_result} ->
        cached_result
      
      :not_found ->
        with {:ok, catalog} <- fetch_mcp_catalog_cached(),
             {:ok, parsed_servers} <- parse_catalog_optimized(catalog),
             scored_servers <- score_servers_parallel(parsed_servers, variety_gap),
             filtered_servers <- filter_by_threshold_optimized(scored_servers) do
          
          result = {:ok, filtered_servers}
          put_in_cache(@match_cache, cache_key, result, @cache_ttl_ms)
          result
        end
    end
  end
  
  defp fetch_mcp_catalog_cached do
    case get_from_cache(@catalog_cache, :catalog) do
      {:ok, catalog} ->
        {:ok, catalog}
      
      :not_found ->
        # In production, fetch from actual URL
        # For now, use mock catalog
        catalog = get_mock_catalog()
        put_in_cache(@catalog_cache, :catalog, catalog, 3_600_000)  # Cache for 1 hour
        {:ok, catalog}
    end
  end
  
  defp parse_catalog_optimized(catalog) do
    # Parse catalog in parallel chunks
    servers = catalog
      |> String.split("###")
      |> Enum.drop(1)  # Skip header
      |> Task.async_stream(
        &parse_server_entry/1,
        max_concurrency: System.schedulers_online()
      )
      |> Enum.map(fn
        {:ok, server} -> server
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)
    
    {:ok, servers}
  end
  
  defp parse_server_entry(entry) do
    lines = String.split(entry, "\n", trim: true)
    
    name = hd(lines) |> String.trim()
    
    # Extract metadata using regex
    source = extract_field(entry, ~r/\*\*Source\*\*: (.+?) - `(.+?)`/)
    capabilities = extract_field(entry, ~r/\*\*Capabilities\*\*: (.+)/)
    description = extract_field(entry, ~r/\*\*Description\*\*: (.+)/)
    
    %{
      name: name,
      source_type: parse_source_type(elem(source, 0)),
      package_name: elem(source, 1),
      capabilities: parse_capabilities_optimized(capabilities),
      description: description,
      keywords: extract_keywords_optimized(name, capabilities, description),
      vector: nil  # Will be computed on demand
    }
  end
  
  defp extract_field(text, regex) do
    case Regex.run(regex, text) do
      [_, field | rest] -> {field, List.first(rest)}
      _ -> {"", ""}
    end
  end
  
  defp parse_capabilities_optimized(capabilities_str) when is_binary(capabilities_str) do
    capabilities_str
    |> String.split(",")
    |> Stream.map(&String.trim/1)
    |> Stream.map(&String.downcase/1)
    |> Enum.to_list()
  end
  
  defp parse_capabilities_optimized(_), do: []
  
  defp extract_keywords_optimized(name, capabilities, description) do
    # Use MapSet for efficient deduplication
    text = [name, capabilities, description]
      |> Enum.join(" ")
      |> String.downcase()
    
    words = Regex.scan(~r/\w{3,}/, text)
      |> List.flatten()
      |> MapSet.new()
    
    # Add domain keywords
    domain_keywords = extract_domain_keywords_optimized(name)
    
    MapSet.union(words, MapSet.new(domain_keywords))
    |> MapSet.to_list()
  end
  
  defp extract_domain_keywords_optimized(name) do
    name_lower = String.downcase(name)
    
    cond do
      String.contains?(name_lower, ["database", "sql", "postgres", "mysql"]) ->
        ["sql", "query", "data", "storage", "database"]
      
      String.contains?(name_lower, ["search", "find"]) ->
        ["search", "find", "query", "web", "discover"]
      
      String.contains?(name_lower, ["file", "filesystem"]) ->
        ["file", "directory", "storage", "io", "filesystem"]
      
      String.contains?(name_lower, ["github", "git"]) ->
        ["git", "repository", "version", "code", "development"]
      
      String.contains?(name_lower, ["slack", "discord", "chat"]) ->
        ["message", "communication", "chat", "notify"]
      
      true ->
        []
    end
  end
  
  defp score_servers_parallel(servers, variety_gap) do
    gap_analysis = analyze_variety_gap_optimized(variety_gap)
    gap_vector = compute_gap_vector(gap_analysis)
    
    servers
    |> Task.async_stream(
      fn server ->
        score = calculate_match_score_vectorized(server, gap_analysis, gap_vector)
        Map.put(server, :match_score, score)
      end,
      max_concurrency: @max_concurrent_scoring,
      timeout: 5_000
    )
    |> Enum.map(fn {:ok, server} -> server end)
    |> Enum.sort_by(&(&1.match_score), :desc)
  end
  
  defp calculate_match_score_vectorized(server, gap_analysis, gap_vector) do
    # Get or compute server vector
    server_vector = case get_from_cache(@vector_cache, server.name) do
      {:ok, vector} -> vector
      :not_found ->
        vector = compute_capability_vector(server)
        put_in_cache(@vector_cache, server.name, vector, @cache_ttl_ms)
        vector
    end
    
    # Calculate similarity scores
    scores = [
      cosine_similarity(server_vector, gap_vector) * 0.4,
      keyword_match_score_optimized(server, gap_analysis) * 0.3,
      domain_match_score_optimized(server, gap_analysis) * 0.2,
      quality_score_enhanced(server) * 0.1
    ]
    
    Enum.sum(scores)
  end
  
  defp compute_capability_vector(item) do
    # Create a vector representation of capabilities
    keywords = case item do
      %{keywords: kw} -> kw
      %{required_capabilities: caps} -> caps
      _ -> []
    end
    
    # Use a simple bag-of-words approach with hashing
    vector = :array.new(@vector_dimensions, default: 0.0)
    
    Enum.reduce(keywords, vector, fn keyword, vec ->
      # Hash keyword to dimension
      dimension = :erlang.phash2(keyword, @vector_dimensions)
      current = :array.get(dimension, vec)
      :array.set(dimension, current + 1.0, vec)
    end)
    |> normalize_vector()
  end
  
  defp compute_gap_vector(gap_analysis) do
    keywords = gap_analysis.keywords ++ 
               gap_analysis.required_capabilities ++
               [Atom.to_string(gap_analysis.domain)]
    
    compute_capability_vector(%{keywords: keywords})
  end
  
  defp cosine_similarity(vector1, vector2) do
    # Compute cosine similarity between two vectors
    dot_product = compute_dot_product(vector1, vector2)
    magnitude1 = compute_magnitude(vector1)
    magnitude2 = compute_magnitude(vector2)
    
    if magnitude1 == 0 or magnitude2 == 0 do
      0.0
    else
      dot_product / (magnitude1 * magnitude2)
    end
  end
  
  defp compute_dot_product(vec1, vec2) do
    :array.sparse_foldl(
      fn idx, val1, acc ->
        val2 = :array.get(idx, vec2)
        acc + (val1 * val2)
      end,
      0.0,
      vec1
    )
  end
  
  defp compute_magnitude(vector) do
    sum_squares = :array.sparse_foldl(
      fn _idx, val, acc -> acc + (val * val) end,
      0.0,
      vector
    )
    
    :math.sqrt(sum_squares)
  end
  
  defp normalize_vector(vector) do
    magnitude = compute_magnitude(vector)
    
    if magnitude == 0 do
      vector
    else
      :array.map(fn _idx, val -> val / magnitude end, vector)
    end
  end
  
  defp keyword_match_score_optimized(server, gap_analysis) do
    # Use MapSet for O(1) lookups
    server_keywords = MapSet.new(server.keywords)
    gap_keywords = MapSet.new(gap_analysis.keywords)
    
    intersection_size = MapSet.intersection(server_keywords, gap_keywords) |> MapSet.size()
    union_size = MapSet.union(server_keywords, gap_keywords) |> MapSet.size()
    
    if union_size == 0, do: 0.0, else: intersection_size / union_size
  end
  
  defp domain_match_score_optimized(server, gap_analysis) do
    server_domain = identify_server_domain_cached(server)
    gap_domain = gap_analysis.domain
    
    cond do
      server_domain == gap_domain -> 1.0
      domains_related_optimized?(server_domain, gap_domain) -> 0.7
      true -> 0.3
    end
  end
  
  defp identify_server_domain_cached(server) do
    case get_from_cache(@vector_cache, {:domain, server.name}) do
      {:ok, domain} -> domain
      :not_found ->
        domain = identify_server_domain_internal(server)
        put_in_cache(@vector_cache, {:domain, server.name}, domain, @cache_ttl_ms)
        domain
    end
  end
  
  defp identify_server_domain_internal(server) do
    name = String.downcase(server.name)
    capabilities = Enum.join(server.capabilities, " ")
    
    domain_patterns = [
      {:data, ~r/database|sql|postgres|mysql|mongo|redis/},
      {:storage, ~r/file|filesystem|storage|s3|blob/},
      {:search, ~r/search|find|query|elastic|solr/},
      {:communication, ~r/slack|discord|chat|email|sms/},
      {:development, ~r/github|git|version|code|deploy/},
      {:knowledge, ~r/memory|knowledge|persist|cache/},
      {:web, ~r/web|http|browser|scrape|fetch/},
      {:api, ~r/api|rest|graphql|webhook/}
    ]
    
    Enum.find_value(domain_patterns, :general, fn {domain, pattern} ->
      if Regex.match?(pattern, name) or Regex.match?(pattern, capabilities) do
        domain
      else
        nil
      end
    end)
  end
  
  defp domains_related_optimized?(domain1, domain2) do
    # Pre-computed domain relationships
    @related_domains
    |> Map.get(domain1, [])
    |> Enum.member?(domain2)
  end
  
  @related_domains %{
    data: [:storage, :search, :api],
    storage: [:data, :knowledge],
    search: [:data, :knowledge, :web],
    communication: [:api, :web],
    development: [:api, :storage],
    knowledge: [:storage, :data, :search],
    web: [:api, :search, :communication],
    api: [:data, :web, :communication, :development]
  }
  
  defp quality_score_enhanced(server) do
    base_score = 0.5
    
    # Check for official packages
    if String.starts_with?(server.package_name || "", "@anthropic/") do
      base_score + 0.3
    else
      # Additional quality indicators
      indicators = [
        {server[:stars] || 0 > 100, 0.1},
        {server[:downloads] || 0 > 1000, 0.1},
        {length(server.capabilities) > 3, 0.05},
        {String.length(server.description || "") > 50, 0.05}
      ]
      
      bonus = indicators
        |> Enum.filter(fn {condition, _} -> condition end)
        |> Enum.map(fn {_, score} -> score end)
        |> Enum.sum()
      
      min(base_score + bonus, 1.0)
    end
  end
  
  defp filter_by_threshold_optimized(scored_servers) do
    # Use Stream for memory efficiency with large lists
    scored_servers
    |> Stream.filter(&(&1.match_score >= @min_match_score))
    |> Enum.to_list()
  end
  
  defp analyze_variety_gap_optimized(variety_gap) do
    %{
      keywords: extract_keywords_from_gap(variety_gap),
      required_capabilities: extract_required_capabilities_optimized(variety_gap),
      domain: identify_gap_domain(variety_gap),
      priority: calculate_priority_optimized(variety_gap)
    }
  end
  
  defp extract_keywords_from_gap(variety_gap) do
    text = extract_gap_text(variety_gap)
    
    # Use parallel processing for large texts
    if String.length(text) > 1000 do
      text
      |> String.split(" ", trim: true)
      |> Enum.chunk_every(100)
      |> Task.async_stream(
        fn chunk ->
          chunk
          |> Enum.filter(&(String.length(&1) > 2))
          |> Enum.reject(&common_word_optimized?/1)
        end,
        max_concurrency: 4
      )
      |> Enum.flat_map(fn {:ok, words} -> words end)
      |> Enum.uniq()
    else
      text
      |> String.downcase()
      |> String.split(~r/\W+/)
      |> Enum.filter(&(String.length(&1) > 2))
      |> Enum.reject(&common_word_optimized?/1)
      |> Enum.uniq()
    end
  end
  
  defp extract_gap_text(variety_gap) do
    case variety_gap do
      %{description: desc} -> desc
      %{need: need} -> need
      %{gap: gap} -> to_string(gap)
      _ -> inspect(variety_gap)
    end
  end
  
  @common_words MapSet.new(~w(the and for with from into that this these those can need want should must will would could may might))
  
  defp common_word_optimized?(word) do
    MapSet.member?(@common_words, word)
  end
  
  defp extract_required_capabilities_optimized(variety_gap) do
    case variety_gap do
      %{capabilities: caps} when is_list(caps) -> caps
      %{required: reqs} when is_list(reqs) -> reqs
      %{needs: needs} when is_list(needs) -> needs
      _ -> []
    end
  end
  
  defp identify_gap_domain(variety_gap) do
    keywords = extract_keywords_from_gap(variety_gap)
    
    domain_keywords = %{
      data: ~w(database sql query data analytics warehouse),
      storage: ~w(file directory storage archive backup),
      search: ~w(search find discover index query),
      communication: ~w(chat message notify alert email),
      development: ~w(git code deploy build test),
      web: ~w(web http api rest browser),
      knowledge: ~w(memory learn adapt persist cache)
    }
    
    # Score each domain based on keyword matches
    domain_scores = domain_keywords
      |> Enum.map(fn {domain, domain_words} ->
        score = Enum.count(keywords, &(&1 in domain_words))
        {domain, score}
      end)
      |> Enum.sort_by(fn {_, score} -> score end, :desc)
    
    case domain_scores do
      [{domain, score} | _] when score > 0 -> domain
      _ -> :general
    end
  end
  
  defp calculate_priority_optimized(variety_gap) do
    case variety_gap do
      %{priority: p} when p in [:high, :critical] -> 1.0
      %{priority: :medium} -> 0.7
      %{priority: :low} -> 0.4
      %{urgent: true} -> 0.9
      %{importance: i} when is_number(i) -> i
      _ -> 0.5
    end
  end
  
  defp find_best_matches_vectorized(gap_vector, server_vectors) do
    server_vectors
    |> Enum.map(fn {server, server_vector} ->
      similarity = cosine_similarity(gap_vector, server_vector)
      {server, similarity}
    end)
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {server, _} -> server end)
  end
  
  # Cache management
  
  defp get_from_cache(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value, expiry}] ->
        if System.monotonic_time(:millisecond) < expiry do
          {:ok, value}
        else
          :ets.delete(table, key)
          :not_found
        end
      [] ->
        :not_found
    end
  end
  
  defp put_in_cache(table, key, value, ttl_ms) do
    expiry = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(table, {key, value, expiry})
  end
  
  defp cleanup_expired_cache do
    now = System.monotonic_time(:millisecond)
    
    [@match_cache, @vector_cache, @catalog_cache]
    |> Enum.each(fn table ->
      :ets.select_delete(table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    end)
  end
  
  defp refresh_catalog_async do
    # In production, this would fetch the latest catalog
    Logger.info("Refreshing MCP catalog in background")
  end
  
  defp parse_source_type(source_type) do
    case String.downcase(String.trim(source_type)) do
      "npm" -> :npm
      "git" -> :git
      "github" -> :git
      _ -> :unknown
    end
  end
  
  defp get_mock_catalog do
    """
    ## Available MCP Servers
    
    ### Brave Search
    - **Source**: NPM - `@anthropic/mcp-server-brave-search`
    - **Capabilities**: Web search, news search, API integration
    - **Description**: Search the web using Brave's search API
    
    ### Filesystem
    - **Source**: NPM - `@anthropic/mcp-server-filesystem`  
    - **Capabilities**: File operations, directory management
    - **Description**: Secure file system operations with configurable access controls
    
    ### GitHub
    - **Source**: NPM - `@anthropic/mcp-server-github`
    - **Capabilities**: Repository management, PR operations, issue tracking
    - **Description**: Interact with GitHub repositories, issues, and PRs
    
    ### PostgreSQL
    - **Source**: NPM - `@anthropic/mcp-server-postgres`
    - **Capabilities**: Database queries, schema management, data analysis
    - **Description**: Connect to PostgreSQL databases for analysis and querying
    
    ### Slack
    - **Source**: NPM - `@anthropic/mcp-server-slack`
    - **Capabilities**: Message posting, channel management, user interactions
    - **Description**: Read and post messages to Slack workspaces
    
    ### Memory
    - **Source**: NPM - `@anthropic/mcp-server-memory`
    - **Capabilities**: Knowledge storage, retrieval, persistence
    - **Description**: Simple knowledge graph implementation for persistent memory
    
    ### Puppeteer
    - **Source**: NPM - `@anthropic/mcp-server-puppeteer`
    - **Capabilities**: Web scraping, browser automation, screenshot capture
    - **Description**: Browser automation and web scraping
    
    ### Fetch
    - **Source**: NPM - `@anthropic/mcp-server-fetch`
    - **Capabilities**: HTTP requests, API calls, web content fetching
    - **Description**: Make HTTP requests and fetch web content
    """
  end
end