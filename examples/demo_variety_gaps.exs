#!/usr/bin/env elixir

# Demonstrate variety gap detection and capability matching

defmodule VarietyGapDemo do
  @moduledoc """
  Demonstrates how the VSM system identifies variety gaps and
  finds matching MCP servers to fill them.
  """
  
  require Logger
  
  def run do
    Logger.info("=== VSM Variety Gap Analysis Demo ===\n")
    
    # Simulate a VSM system analyzing its current state
    current_system_variety = analyze_current_system()
    
    # Identify required variety based on environment
    required_variety = analyze_environment_requirements()
    
    # Calculate variety gaps
    variety_gaps = calculate_variety_gaps(current_system_variety, required_variety)
    
    # Display gaps
    display_variety_gaps(variety_gaps)
    
    # Find MCP servers to fill gaps
    find_mcp_solutions(variety_gaps)
  end
  
  defp analyze_current_system do
    %{
      capabilities: [
        "file_reading",
        "json_parsing", 
        "http_requests",
        "pattern_matching"
      ],
      performance: %{
        response_time_ms: 100,
        throughput_rps: 1000
      },
      domains: [:data_processing, :api_integration]
    }
  end
  
  defp analyze_environment_requirements do
    %{
      required_capabilities: [
        "file_reading",
        "file_writing",
        "database_queries",
        "web_search",
        "browser_automation",
        "slack_messaging",
        "github_integration",
        "persistent_memory"
      ],
      performance_requirements: %{
        response_time_ms: 500,
        throughput_rps: 500
      },
      required_domains: [:data_processing, :api_integration, :communication, :development, :search]
    }
  end
  
  defp calculate_variety_gaps(current, required) do
    missing_capabilities = required.required_capabilities -- current.capabilities
    missing_domains = required.required_domains -- current.domains
    
    # Generate variety gaps
    gaps = []
    
    # File operations gap
    if "file_writing" in missing_capabilities do
      gaps = [%{
        id: "gap_file_ops",
        type: :capability,
        description: "System lacks file writing capability for data persistence",
        missing: ["file_writing", "directory_management"],
        priority: :high,
        domain: :storage
      } | gaps]
    end
    
    # Database gap
    if "database_queries" in missing_capabilities do
      gaps = [%{
        id: "gap_database",
        type: :capability,
        description: "No database query capability for structured data analysis",
        missing: ["database_queries", "schema_management"],
        priority: :high,
        domain: :data
      } | gaps]
    end
    
    # Search gap
    if "web_search" in missing_capabilities do
      gaps = [%{
        id: "gap_search",
        type: :capability,
        description: "Cannot perform web searches for external information",
        missing: ["web_search", "result_parsing"],
        priority: :medium,
        domain: :search
      } | gaps]
    end
    
    # Communication gap
    if "slack_messaging" in missing_capabilities do
      gaps = [%{
        id: "gap_communication",
        type: :capability,
        description: "Unable to communicate via Slack for team coordination",
        missing: ["slack_messaging", "channel_management"],
        priority: :medium,
        domain: :communication
      } | gaps]
    end
    
    # Development gap
    if "github_integration" in missing_capabilities do
      gaps = [%{
        id: "gap_development",
        type: :capability,
        description: "Missing GitHub integration for code management",
        missing: ["github_integration", "pr_management"],
        priority: :medium,
        domain: :development
      } | gaps]
    end
    
    # Memory gap
    if "persistent_memory" in missing_capabilities do
      gaps = [%{
        id: "gap_memory",
        type: :capability,
        description: "No persistent memory for knowledge retention",
        missing: ["persistent_memory", "knowledge_graphs"],
        priority: :high,
        domain: :knowledge
      } | gaps]
    end
    
    gaps
  end
  
  defp display_variety_gaps(gaps) do
    Logger.info("📊 Identified #{length(gaps)} variety gaps:\n")
    
    Enum.each(gaps, fn gap ->
      Logger.info("🔴 Gap: #{gap.id}")
      Logger.info("   Type: #{gap.type}")
      Logger.info("   Description: #{gap.description}")
      Logger.info("   Missing: #{Enum.join(gap.missing, ", ")}")
      Logger.info("   Priority: #{gap.priority}")
      Logger.info("   Domain: #{gap.domain}")
      Logger.info("")
    end)
  end
  
  defp find_mcp_solutions(variety_gaps) do
    Logger.info("🔍 Finding MCP servers to fill variety gaps...\n")
    
    # Mock MCP catalog (in reality, this would fetch from the actual catalog)
    mcp_catalog = get_mock_mcp_catalog()
    
    Enum.each(variety_gaps, fn gap ->
      Logger.info("🎯 Matching servers for gap: #{gap.id}")
      
      # Score each server against the gap
      matches = Enum.map(mcp_catalog, fn server ->
        score = calculate_match_score(server, gap)
        {server, score}
      end)
      |> Enum.filter(fn {_, score} -> score > 0.5 end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(3)
      
      if Enum.empty?(matches) do
        Logger.info("   ❌ No suitable MCP servers found")
      else
        Enum.each(matches, fn {server, score} ->
          Logger.info("   ✅ #{server.name} (score: #{Float.round(score, 2)})")
          Logger.info("      Package: #{server.package}")
          Logger.info("      Capabilities: #{Enum.join(server.capabilities, ", ")}")
        end)
      end
      
      Logger.info("")
    end)
  end
  
  defp get_mock_mcp_catalog do
    [
      %{
        name: "Filesystem MCP",
        package: "@anthropic/mcp-server-filesystem",
        capabilities: ["file_reading", "file_writing", "directory_management"],
        domain: :storage
      },
      %{
        name: "PostgreSQL MCP", 
        package: "@anthropic/mcp-server-postgres",
        capabilities: ["database_queries", "schema_management", "data_analysis"],
        domain: :data
      },
      %{
        name: "Brave Search MCP",
        package: "@anthropic/mcp-server-brave-search", 
        capabilities: ["web_search", "news_search", "result_parsing"],
        domain: :search
      },
      %{
        name: "Slack MCP",
        package: "@anthropic/mcp-server-slack",
        capabilities: ["slack_messaging", "channel_management", "user_interactions"],
        domain: :communication
      },
      %{
        name: "GitHub MCP",
        package: "@anthropic/mcp-server-github",
        capabilities: ["github_integration", "pr_management", "issue_tracking"],
        domain: :development
      },
      %{
        name: "Memory MCP",
        package: "@anthropic/mcp-server-memory",
        capabilities: ["persistent_memory", "knowledge_graphs", "retrieval"],
        domain: :knowledge
      }
    ]
  end
  
  defp calculate_match_score(server, gap) do
    # Calculate how well the server matches the gap
    capability_overlap = MapSet.intersection(
      MapSet.new(server.capabilities),
      MapSet.new(gap.missing)
    ) |> MapSet.size()
    
    capability_score = capability_overlap / length(gap.missing)
    domain_score = if server.domain == gap.domain, do: 1.0, else: 0.5
    
    # Weighted average
    capability_score * 0.7 + domain_score * 0.3
  end
end

# Run the demo
VarietyGapDemo.run()