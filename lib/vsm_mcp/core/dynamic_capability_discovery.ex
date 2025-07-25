defmodule VsmMcp.Core.DynamicCapabilityDiscovery do
  @moduledoc """
  Dynamically discovers MCP servers from multiple sources without hardcoded mappings.
  This is the truly autonomous version that learns and adapts.
  """
  
  use GenServer
  require Logger
  
  @npm_registry "https://registry.npmjs.org"
  @mcp_keywords ["mcp", "modelcontextprotocol", "mcp-server"]
  @capability_keywords [
    "filesystem", "database", "memory", "cache", "api", "web", "search",
    "git", "github", "slack", "docker", "kubernetes", "aws", "monitoring"
  ]
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Dynamically discover MCP servers for a capability without hardcoded mappings
  """
  def discover_for_capability(capability) do
    GenServer.call(__MODULE__, {:discover_capability, capability}, 30_000)
  end
  
  @doc """
  Search all of NPM for new MCP servers
  """
  def discover_all_mcp_servers do
    GenServer.call(__MODULE__, :discover_all, 60_000)
  end
  
  @doc """
  Learn from successful installations
  """
  def learn_mapping(capability, package_name, success_score) do
    GenServer.cast(__MODULE__, {:learn, capability, package_name, success_score})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      # Learned mappings from actual usage
      learned_mappings: %{},
      # Cache of discovered packages
      package_cache: %{},
      # Success scores for packages
      success_scores: %{},
      # Last full scan timestamp
      last_scan: nil
    }
    
    # Schedule periodic scans for new packages
    Process.send_after(self(), :periodic_scan, :timer.hours(24))
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:discover_capability, capability}, _from, state) do
    Logger.info("🔍 Dynamically discovering packages for capability: #{capability}")
    
    # 1. Check learned mappings first
    learned = Map.get(state.learned_mappings, capability, [])
    
    # 2. Search NPM dynamically
    discovered = search_npm_for_capability(capability)
    
    # 3. Check package cache for keyword matches
    cached = search_cache_for_capability(capability, state.package_cache)
    
    # 4. Combine and rank results
    all_packages = (learned ++ discovered ++ cached)
    |> Enum.uniq_by(& &1.name)
    |> rank_by_relevance(capability, state.success_scores)
    |> Enum.take(10)
    
    {:reply, {:ok, all_packages}, state}
  end
  
  @impl true
  def handle_call(:discover_all, _from, state) do
    Logger.info("🌐 Scanning NPM for all MCP servers...")
    
    # Search for various MCP-related terms
    packages = @mcp_keywords
    |> Enum.flat_map(&search_npm_keyword/1)
    |> Enum.uniq_by(& &1.name)
    
    # Update cache
    new_cache = Enum.reduce(packages, state.package_cache, fn pkg, acc ->
      Map.put(acc, pkg.name, pkg)
    end)
    
    new_state = %{state | 
      package_cache: new_cache,
      last_scan: DateTime.utc_now()
    }
    
    {:reply, {:ok, packages}, new_state}
  end
  
  @impl true
  def handle_cast({:learn, capability, package_name, success_score}, state) do
    # Update learned mappings
    new_mappings = Map.update(state.learned_mappings, capability, [package_name], fn existing ->
      [package_name | existing] |> Enum.uniq() |> Enum.take(5)
    end)
    
    # Update success scores
    new_scores = Map.update(state.success_scores, package_name, success_score, fn existing ->
      (existing + success_score) / 2
    end)
    
    Logger.info("📚 Learned: #{capability} → #{package_name} (score: #{success_score})")
    
    {:noreply, %{state | 
      learned_mappings: new_mappings,
      success_scores: new_scores
    }}
  end
  
  @impl true
  def handle_info(:periodic_scan, state) do
    # Periodic scan for new packages
    Task.start(fn ->
      {:ok, _packages} = discover_all_mcp_servers()
    end)
    
    # Schedule next scan
    Process.send_after(self(), :periodic_scan, :timer.hours(24))
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp search_npm_for_capability(capability) do
    # Build intelligent search queries
    search_terms = generate_search_terms(capability)
    
    search_terms
    |> Enum.flat_map(&search_npm_keyword/1)
    |> Enum.uniq_by(& &1.name)
    |> filter_relevant_packages(capability)
  end
  
  defp generate_search_terms(capability) do
    base_terms = [
      capability,
      "mcp #{capability}",
      "mcp-server-#{capability}",
      "@modelcontextprotocol/server-#{capability}"
    ]
    
    # Add semantic variations
    semantic_terms = case String.downcase(capability) do
      "enhanced_processing" -> ["memory", "cache", "optimize", "performance"]
      "pattern_recognition" -> ["analyze", "detect", "match", "ai"]
      "data_transformation" -> ["convert", "transform", "etl", "process"]
      _ -> []
    end
    
    base_terms ++ semantic_terms
  end
  
  defp search_npm_keyword(keyword) do
    encoded = URI.encode(keyword)
    url = "#{@npm_registry}/-/v1/search?text=#{encoded}&size=20"
    
    case HTTPoison.get(url, [], recv_timeout: 10_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"objects" => objects}} ->
            objects
            |> Enum.map(&parse_npm_package/1)
            |> Enum.filter(&relevant_mcp_package?/1)
          _ ->
            []
        end
      _ ->
        []
    end
  catch
    _ -> []
  end
  
  defp parse_npm_package(npm_object) do
    package = npm_object["package"]
    
    %{
      name: package["name"],
      version: package["version"],
      description: package["description"] || "",
      keywords: package["keywords"] || [],
      score: get_in(npm_object, ["score", "final"]) || 0.0,
      downloads: get_in(npm_object, ["score", "detail", "popularity"]) || 0.0,
      maintained: get_in(npm_object, ["score", "detail", "maintenance"]) || 0.0
    }
  end
  
  defp relevant_mcp_package?(package) do
    name = String.downcase(package.name)
    desc = String.downcase(package.description)
    
    # Check if it's likely an MCP server
    String.contains?(name, "mcp") or
    String.contains?(desc, "model context protocol") or
    String.contains?(desc, "mcp server") or
    Enum.any?(package.keywords, &(String.downcase(&1) == "mcp"))
  end
  
  defp filter_relevant_packages(packages, capability) do
    cap_lower = String.downcase(capability)
    
    packages
    |> Enum.map(fn pkg ->
      score = calculate_relevance_score(pkg, cap_lower)
      Map.put(pkg, :relevance_score, score)
    end)
    |> Enum.filter(& &1.relevance_score > 0.3)
  end
  
  defp calculate_relevance_score(package, capability) do
    name_score = string_similarity(package.name, capability) * 0.3
    desc_score = keyword_density(package.description, capability) * 0.3
    keyword_score = keyword_match_score(package.keywords, capability) * 0.2
    popularity_score = min(package.downloads, 1.0) * 0.1
    maintained_score = package.maintained * 0.1
    
    name_score + desc_score + keyword_score + popularity_score + maintained_score
  end
  
  defp string_similarity(str1, str2) do
    s1 = String.downcase(str1)
    s2 = String.downcase(str2)
    
    cond do
      String.contains?(s1, s2) -> 1.0
      String.contains?(s2, s1) -> 0.8
      true -> 
        # Simple character overlap
        chars1 = String.graphemes(s1) |> MapSet.new()
        chars2 = String.graphemes(s2) |> MapSet.new()
        
        intersection = MapSet.intersection(chars1, chars2) |> MapSet.size()
        union = MapSet.union(chars1, chars2) |> MapSet.size()
        
        if union > 0, do: intersection / union, else: 0.0
    end
  end
  
  defp keyword_density(text, keyword) do
    if text == "", do: 0.0, else: calculate_density(text, keyword)
  end
  
  defp calculate_density(text, keyword) do
    text_lower = String.downcase(text)
    keyword_lower = String.downcase(keyword)
    
    # Count occurrences
    count = text_lower
    |> String.split(~r/\W+/)
    |> Enum.count(&String.contains?(&1, keyword_lower))
    
    # Normalize by text length
    min(count / 10.0, 1.0)
  end
  
  defp keyword_match_score(keywords, capability) do
    if Enum.empty?(keywords), do: 0.0, else: calculate_keyword_score(keywords, capability)
  end
  
  defp calculate_keyword_score(keywords, capability) do
    cap_lower = String.downcase(capability)
    
    matches = Enum.count(keywords, fn kw ->
      String.contains?(String.downcase(kw), cap_lower) or
      String.contains?(cap_lower, String.downcase(kw))
    end)
    
    matches / length(keywords)
  end
  
  defp search_cache_for_capability(capability, cache) do
    cap_lower = String.downcase(capability)
    
    cache
    |> Map.values()
    |> Enum.filter(fn pkg ->
      calculate_relevance_score(pkg, cap_lower) > 0.4
    end)
  end
  
  defp rank_by_relevance(packages, capability, success_scores) do
    packages
    |> Enum.map(fn pkg ->
      base_score = Map.get(pkg, :relevance_score, 0.5)
      success_bonus = Map.get(success_scores, pkg.name, 0.0)
      
      final_score = base_score * 0.7 + success_bonus * 0.3
      Map.put(pkg, :final_score, final_score)
    end)
    |> Enum.sort_by(& &1.final_score, :desc)
  end
end