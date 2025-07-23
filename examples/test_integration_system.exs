#!/usr/bin/env elixir

# Test the dynamic capability integration system

require Logger

defmodule IntegrationTest do
  @moduledoc """
  Tests the integration system with real variety gaps and MCP servers.
  """
  
  def run do
    Logger.info("Starting integration system test...")
    
    # Start required applications
    {:ok, _} = Application.ensure_all_started(:jason)
    {:ok, _} = Application.ensure_all_started(:httpoison)
    
    # Start the integration system
    {:ok, _pid} = VsmMcp.Integration.start_link()
    
    # Define test variety gaps
    variety_gaps = [
      %{
        id: "gap_001",
        description: "Need web search capability for research tasks",
        required_capabilities: ["web search", "api integration"],
        priority: :high,
        performance_requirements: %{
          max_response_time: 2000,
          min_throughput: 50
        }
      },
      %{
        id: "gap_002", 
        description: "Need file system access for data processing",
        required_capabilities: ["file operations", "directory management"],
        priority: :medium,
        performance_requirements: %{
          max_response_time: 500
        }
      },
      %{
        id: "gap_003",
        description: "Need persistent memory for knowledge storage",
        required_capabilities: ["knowledge storage", "retrieval", "persistence"],
        priority: :high
      }
    ]
    
    # Test integration for each variety gap
    Enum.each(variety_gaps, fn gap ->
      test_integration_for_gap(gap)
    end)
    
    # Show final status
    show_integration_status()
  end
  
  defp test_integration_for_gap(variety_gap) do
    Logger.info("\n=== Testing integration for variety gap: #{variety_gap.id} ===")
    Logger.info("Description: #{variety_gap.description}")
    
    case VsmMcp.Integration.integrate_capability(variety_gap) do
      {:ok, capability} ->
        Logger.info("✅ Successfully integrated capability: #{capability.id}")
        Logger.info("   - MCP Server: #{capability.mcp_server.name}")
        Logger.info("   - Match Score: #{capability.mcp_server.match_score}")
        Logger.info("   - Installation Path: #{capability.installation_path}")
        
        # Test the integrated capability
        test_capability_usage(capability)
        
      {:error, reason} ->
        Logger.error("❌ Failed to integrate capability: #{inspect(reason)}")
    end
  end
  
  defp test_capability_usage(capability) do
    Logger.info("\n   Testing capability usage...")
    
    # Simulate using the capability
    case GenServer.call(capability.process, {:execute, "test/echo", %{message: "Hello MCP!"}}) do
      {:ok, result} ->
        Logger.info("   ✅ Capability test successful: #{inspect(result)}")
        
      {:error, reason} ->
        Logger.error("   ❌ Capability test failed: #{inspect(reason)}")
    end
  end
  
  defp show_integration_status do
    Logger.info("\n=== Integration System Status ===")
    
    case VsmMcp.Integration.list_capabilities() do
      {:ok, capabilities} ->
        Logger.info("Total integrated capabilities: #{length(capabilities)}")
        
        Enum.each(capabilities, fn cap ->
          Logger.info("\n📦 Capability: #{cap.id}")
          Logger.info("   - Server: #{cap.mcp_server.name}")
          Logger.info("   - Variety Gap: #{cap.variety_gap.id}")
          Logger.info("   - Verified: #{cap.verified_at}")
          
          # Get runtime stats
          case GenServer.call(cap.process, :get_stats) do
            {:ok, stats} ->
              Logger.info("   - Requests: #{stats.requests}")
              Logger.info("   - Errors: #{stats.errors}")
              Logger.info("   - Last Used: #{stats.last_used}")
              
            _ -> :ok
          end
        end)
        
      _ ->
        Logger.error("Failed to retrieve capabilities")
    end
  end
end

# Run the test
IntegrationTest.run()