defmodule VsmMcpBasicTest do
  use ExUnit.Case
  doctest VsmMcp

  setup_all do
    # Start hackney for HTTP requests
    Application.ensure_all_started(:hackney)
    :ok
  end

  describe "basic VSM functionality" do
    test "module exists" do
      assert Code.ensure_loaded?(VsmMcp)
    end

    test "core modules are available" do
      # Check that key modules exist
      modules = [
        VsmMcp.Systems.System1,
        VsmMcp.Systems.System2,
        VsmMcp.Systems.System3,
        VsmMcp.Systems.System4,
        VsmMcp.Systems.System5,
        VsmMcp.ConsciousnessInterface,
        VsmMcp.Core.VarietyCalculator,
        VsmMcp.Core.MCPDiscovery,
        VsmMcp.RealImplementation
      ]
      
      for module <- modules do
        assert Code.ensure_loaded?(module), "Module #{module} should be loaded"
      end
    end
  end

  describe "real implementation functions" do
    test "can calculate real variety" do
      variety = VsmMcp.RealImplementation.calculate_real_variety()
      
      assert is_map(variety)
      assert Map.has_key?(variety, :operational_variety)
      assert Map.has_key?(variety, :environmental_variety)
      assert variety.operational_variety > 0
      assert variety.environmental_variety > 0
    end

    test "can discover MCP servers" do
      # This test might fail if network is unavailable
      servers = VsmMcp.RealImplementation.discover_real_mcp_servers()
      
      assert is_list(servers)
      # Should find at least some servers (or empty list if offline)
    end
  end

  describe "variety calculations" do
    test "calculates variety gap" do
      operational = 20.0
      environmental = 25.0
      
      gap = VsmMcp.Core.VarietyCalculator.calculate_variety_gap(operational, environmental)
      
      assert gap == 5.0
    end
  end
end