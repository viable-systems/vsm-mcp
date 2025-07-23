defmodule VsmMcp.Integration.CapabilityMatcher do
  @moduledoc """
  Matches MCP servers to variety gaps using intelligent analysis.
  
  Uses multiple strategies:
  - Keyword matching
  - Semantic similarity
  - Capability scoring
  - Historical performance
  """
  
  require Logger
  
  @mcp_catalog_url "https://raw.githubusercontent.com/modelcontextprotocol/servers/main/README.md"
  @min_match_score 0.6
  
  @doc """
  Finds MCP servers that can fill a specific variety gap.
  """
  def find_matching_servers(variety_gap) do
    Logger.info("Finding MCP servers for variety gap: #{inspect(variety_gap)}")
    
    with {:ok, catalog} <- fetch_mcp_catalog(),
         {:ok, parsed_servers} <- parse_catalog(catalog),
         scored_servers <- score_servers(parsed_servers, variety_gap),
         filtered_servers <- filter_by_threshold(scored_servers) do
      
      {:ok, filtered_servers}
    end
  end
  
  @doc """
  Calculates match score between a server and variety gap.
  """
  def calculate_match_score(server, variety_gap) do
    scores = [
      keyword_match_score(server, variety_gap) * 0.3,
      capability_match_score(server, variety_gap) * 0.4,
      domain_match_score(server, variety_gap) * 0.2,
      quality_score(server) * 0.1
    ]
    
    Enum.sum(scores)
  end
  
  @doc """
  Analyzes variety gap to extract matching criteria.
  """
  def analyze_variety_gap(variety_gap) do
    %{
      keywords: extract_keywords(variety_gap),
      required_capabilities: extract_required_capabilities(variety_gap),
      domain: identify_domain(variety_gap),
      priority: calculate_priority(variety_gap)
    }
  end
  
  ## Private Functions
  
  defp fetch_mcp_catalog do
    # In production, this would fetch from the actual catalog
    # For now, we'll use a mock catalog
    catalog = """
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
    
    {:ok, catalog}
  end
  
  defp parse_catalog(catalog) do
    servers = Regex.scan(~r/### (.+?)\n- \*\*Source\*\*: (.+?) - `(.+?)`\n- \*\*Capabilities\*\*: (.+?)\n- \*\*Description\*\*: (.+?)(?=\n\n|$)/s, catalog)
    |> Enum.map(fn [_match, name, source_type, package, capabilities, description] ->
      %{
        name: String.trim(name),
        source_type: parse_source_type(source_type),
        package_name: String.trim(package),
        capabilities: parse_capabilities(capabilities),
        description: String.trim(description),
        keywords: extract_server_keywords(name, capabilities, description)
      }
    end)
    
    {:ok, servers}
  end
  
  defp parse_source_type(source_type) do
    case String.downcase(String.trim(source_type)) do
      "npm" -> :npm
      "git" -> :git
      "github" -> :git
      _ -> :unknown
    end
  end
  
  defp parse_capabilities(capabilities_str) do
    capabilities_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.downcase/1)
  end
  
  defp extract_server_keywords(name, capabilities, description) do
    # Extract meaningful keywords from server metadata
    words = [name, capabilities, description]
    |> Enum.join(" ")
    |> String.downcase()
    |> String.split(~r/\W+/)
    |> Enum.filter(&(String.length(&1) > 2))
    |> Enum.uniq()
    
    # Add domain-specific keywords
    words ++ extract_domain_keywords(name)
  end
  
  defp extract_domain_keywords(name) do
    cond do
      String.contains?(String.downcase(name), "database") ->
        ["sql", "query", "data", "storage"]
        
      String.contains?(String.downcase(name), "search") ->
        ["search", "find", "query", "web"]
        
      String.contains?(String.downcase(name), "file") ->
        ["file", "directory", "storage", "io"]
        
      true ->
        []
    end
  end
  
  defp score_servers(servers, variety_gap) do
    gap_analysis = analyze_variety_gap(variety_gap)
    
    Enum.map(servers, fn server ->
      score = calculate_match_score(server, gap_analysis)
      Map.put(server, :match_score, score)
    end)
    |> Enum.sort_by(&(&1.match_score), :desc)
  end
  
  defp filter_by_threshold(scored_servers) do
    Enum.filter(scored_servers, fn server ->
      server.match_score >= @min_match_score
    end)
  end
  
  defp keyword_match_score(server, gap_analysis) do
    server_keywords = MapSet.new(server.keywords)
    gap_keywords = MapSet.new(gap_analysis.keywords)
    
    intersection_size = MapSet.intersection(server_keywords, gap_keywords) |> MapSet.size()
    union_size = MapSet.union(server_keywords, gap_keywords) |> MapSet.size()
    
    if union_size == 0, do: 0.0, else: intersection_size / union_size
  end
  
  defp capability_match_score(server, gap_analysis) do
    required_capabilities = gap_analysis.required_capabilities
    server_capabilities = server.capabilities
    
    if Enum.empty?(required_capabilities) do
      0.5  # Neutral score if no specific capabilities required
    else
      matched = Enum.count(required_capabilities, fn req ->
        Enum.any?(server_capabilities, fn cap ->
          capability_matches?(cap, req)
        end)
      end)
      
      matched / length(required_capabilities)
    end
  end
  
  defp capability_matches?(server_capability, required_capability) do
    # Fuzzy matching for capabilities
    server_cap = String.downcase(server_capability)
    required_cap = String.downcase(required_capability)
    
    String.contains?(server_cap, required_cap) or
    String.contains?(required_cap, server_cap) or
    calculate_string_similarity(server_cap, required_cap) > 0.8
  end
  
  defp calculate_string_similarity(str1, str2) do
    # Simple character-based similarity
    chars1 = String.graphemes(str1) |> MapSet.new()
    chars2 = String.graphemes(str2) |> MapSet.new()
    
    intersection = MapSet.intersection(chars1, chars2) |> MapSet.size()
    union = MapSet.union(chars1, chars2) |> MapSet.size()
    
    if union == 0, do: 0.0, else: intersection / union
  end
  
  defp domain_match_score(server, gap_analysis) do
    server_domain = identify_server_domain(server)
    gap_domain = gap_analysis.domain
    
    cond do
      server_domain == gap_domain -> 1.0
      domains_related?(server_domain, gap_domain) -> 0.7
      true -> 0.3
    end
  end
  
  defp identify_server_domain(server) do
    # Identify domain based on name and capabilities
    name = String.downcase(server.name)
    
    cond do
      String.contains?(name, ["database", "sql", "postgres", "mysql"]) -> :data
      String.contains?(name, ["file", "filesystem", "storage"]) -> :storage
      String.contains?(name, ["search", "find", "query"]) -> :search
      String.contains?(name, ["slack", "discord", "chat"]) -> :communication
      String.contains?(name, ["github", "git", "version"]) -> :development
      String.contains?(name, ["memory", "knowledge", "persist"]) -> :knowledge
      true -> :general
    end
  end
  
  defp domains_related?(domain1, domain2) do
    related_domains = %{
      data: [:storage, :search],
      storage: [:data, :knowledge],
      search: [:data, :knowledge],
      communication: [:general],
      development: [:general],
      knowledge: [:storage, :data]
    }
    
    domain2 in Map.get(related_domains, domain1, [])
  end
  
  defp quality_score(server) do
    # In production, this would consider:
    # - GitHub stars
    # - NPM downloads
    # - Last update time
    # - Issue count
    # - Documentation quality
    
    # For now, return a default score
    0.7
  end
  
  defp extract_keywords(variety_gap) do
    # Extract keywords from variety gap description
    text = case variety_gap do
      %{description: desc} -> desc
      %{need: need} -> need
      %{gap: gap} -> gap
      _ -> inspect(variety_gap)
    end
    
    text
    |> String.downcase()
    |> String.split(~r/\W+/)
    |> Enum.filter(&(String.length(&1) > 2))
    |> Enum.reject(&common_word?/1)
    |> Enum.uniq()
  end
  
  defp common_word?(word) do
    common_words = ~w(the and for with from into that this these those can need want should must)
    word in common_words
  end
  
  defp extract_required_capabilities(variety_gap) do
    # Extract specific capabilities needed
    case variety_gap do
      %{capabilities: caps} when is_list(caps) -> caps
      %{required: reqs} when is_list(reqs) -> reqs
      _ -> []
    end
  end
  
  defp identify_domain(variety_gap) do
    # Identify the domain of the variety gap
    keywords = extract_keywords(variety_gap)
    
    cond do
      Enum.any?(keywords, &(&1 in ~w(database sql query data))) -> :data
      Enum.any?(keywords, &(&1 in ~w(file directory storage))) -> :storage
      Enum.any?(keywords, &(&1 in ~w(search find web))) -> :search
      Enum.any?(keywords, &(&1 in ~w(chat message slack))) -> :communication
      Enum.any?(keywords, &(&1 in ~w(git github code))) -> :development
      true -> :general
    end
  end
  
  defp calculate_priority(variety_gap) do
    # Calculate priority based on gap metadata
    case variety_gap do
      %{priority: p} when p in [:high, :critical] -> 1.0
      %{priority: :medium} -> 0.7
      %{priority: :low} -> 0.4
      %{urgent: true} -> 0.9
      _ -> 0.5
    end
  end
end