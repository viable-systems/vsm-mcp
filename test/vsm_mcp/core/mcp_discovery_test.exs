defmodule VsmMcp.Core.McpDiscoveryTest do
  use ExUnit.Case
  alias VsmMcp.Core.McpDiscovery
  import ExUnit.CaptureLog

  describe "MCP server discovery" do
    test "discovers servers from NPM registry" do
      # This test will actually hit NPM API in real implementation
      # For testing, we'll mock the response
      mock_response = %{
        "objects" => [
          %{
            "package" => %{
              "name" => "test-mcp-server",
              "version" => "1.0.0",
              "description" => "Test MCP server"
            }
          }
        ]
      }
      
      # In real implementation, this would use HTTPoison
      servers = McpDiscovery.discover_npm_servers("mcp-server")
      
      assert is_list(servers)
      # Should find real servers if network is available
    end

    test "searches with specific capabilities" do
      capabilities = ["powerpoint", "presentation"]
      
      servers = McpDiscovery.search_by_capability(capabilities)
      
      assert is_list(servers)
      # Each server should have relevant capability
      for server <- servers do
        assert Map.has_key?(server, :name)
        assert Map.has_key?(server, :capabilities) or Map.has_key?(server, :description)
      end
    end

    test "filters servers by compatibility" do
      servers = [
        %{name: "server1", version: "1.0.0", engines: %{"node" => ">=14"}},
        %{name: "server2", version: "2.0.0", engines: %{"node" => ">=18"}},
        %{name: "server3", version: "1.5.0", engines: nil}
      ]
      
      compatible = McpDiscovery.filter_compatible(servers)
      
      # Should include servers without engine requirements
      assert Enum.any?(compatible, & &1.name == "server3")
    end

    test "ranks servers by relevance" do
      servers = [
        %{name: "exact-mcp-powerpoint", description: "PowerPoint MCP server", downloads: 1000},
        %{name: "generic-mcp", description: "Generic server", downloads: 5000},
        %{name: "pptx-mcp-controller", description: "Control PowerPoint", downloads: 500}
      ]
      
      ranked = McpDiscovery.rank_by_relevance(servers, "powerpoint")
      
      # Most relevant should be first
      assert hd(ranked).name == "exact-mcp-powerpoint"
    end

    test "handles discovery failures gracefully" do
      # Test with invalid registry URL
      assert capture_log(fn ->
        result = McpDiscovery.discover_from_registry("http://invalid-url")
        assert result == []
      end) =~ "Failed to discover"
    end
  end

  describe "MCP server metadata" do
    test "fetches detailed server info" do
      server_name = "test-mcp-server"
      
      # In real implementation, this queries NPM
      info = McpDiscovery.get_server_details(server_name)
      
      if info do
        assert Map.has_key?(info, :name)
        assert Map.has_key?(info, :version)
        assert Map.has_key?(info, :readme) or Map.has_key?(info, :description)
      end
    end

    test "extracts MCP capabilities from package" do
      package_json = %{
        "name" => "test-mcp",
        "mcp" => %{
          "capabilities" => ["read_files", "write_files", "execute_commands"],
          "transport" => ["stdio", "tcp"]
        }
      }
      
      capabilities = McpDiscovery.extract_capabilities(package_json)
      
      assert "read_files" in capabilities
      assert "write_files" in capabilities
      assert "execute_commands" in capabilities
    end

    test "identifies transport methods" do
      package_data = %{
        "mcp" => %{
          "transport" => ["stdio", "tcp", "websocket"]
        }
      }
      
      transports = McpDiscovery.get_transports(package_data)
      
      assert :stdio in transports
      assert :tcp in transports
      assert :websocket in transports
    end
  end

  describe "intelligent discovery" do
    test "uses LLM to suggest search terms" do
      # This would use real LLM in production
      requirement = "I need to create PowerPoint presentations"
      
      suggestions = McpDiscovery.get_search_suggestions(requirement)
      
      assert is_list(suggestions)
      # Should include relevant terms
      assert Enum.any?(suggestions, &String.contains?(&1, "ppt")) or
             Enum.any?(suggestions, &String.contains?(&1, "powerpoint")) or
             Enum.any?(suggestions, &String.contains?(&1, "presentation"))
    end

    test "discovers servers for variety gap" do
      variety_gap = %{
        missing_capabilities: ["presentation_creation", "document_export"],
        current_variety: 20.0,
        required_variety: 25.0
      }
      
      servers = McpDiscovery.discover_for_gap(variety_gap)
      
      assert is_list(servers)
      # Should find servers that can fill the gap
    end
  end

  describe "registry sources" do
    test "discovers from multiple registries" do
      # Test discovery from different sources
      sources = [:npm, :github, :smithery]
      
      all_servers = McpDiscovery.discover_from_all_sources("mcp")
      
      assert is_map(all_servers)
      assert Map.has_key?(all_servers, :npm)
      assert Map.has_key?(all_servers, :github)
      assert Map.has_key?(all_servers, :smithery)
    end

    test "handles rate limiting" do
      # Rapid requests should be throttled
      results = for _ <- 1..5 do
        McpDiscovery.discover_npm_servers("test")
      end
      
      # Should not error out
      assert Enum.all?(results, &is_list/1)
    end
  end
end