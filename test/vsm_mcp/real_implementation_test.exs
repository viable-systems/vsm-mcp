defmodule VsmMcp.RealImplementationTest do
  use ExUnit.Case
  alias VsmMcp.RealImplementation
  import ExUnit.CaptureIO

  describe "real MCP discovery" do
    @tag :integration
    test "discovers real MCP servers from NPM" do
      # This test actually hits the NPM API
      output = capture_io(fn ->
        servers = RealImplementation.discover_real_mcp_servers()
        assert is_list(servers)
        assert length(servers) > 0
        
        # Should have found real packages
        for server <- servers do
          assert Map.has_key?(server, :name)
          assert Map.has_key?(server, :version)
        end
      end)
      
      assert output =~ "Searching NPM"
    end

    test "searches for specific capability" do
      servers = RealImplementation.search_for_capability("powerpoint")
      
      assert is_list(servers)
      # Should find PowerPoint-related servers if any exist
    end
  end

  describe "real variety calculations" do
    test "calculates variety from actual system metrics" do
      variety = RealImplementation.calculate_real_variety()
      
      assert is_map(variety)
      assert Map.has_key?(variety, :operational)
      assert Map.has_key?(variety, :environmental)
      assert Map.has_key?(variety, :ratio)
      assert Map.has_key?(variety, :status)
      
      # Should use real system metrics
      assert variety.operational > 0
      assert variety.environmental > 0
      assert variety.ratio > 0 and variety.ratio <= 100
    end

    test "variety calculation uses actual CPU and memory" do
      variety_data = RealImplementation.calculate_real_variety()
      
      # Verify it's using real system info
      cpu_count = :erlang.system_info(:logical_processors)
      memory = :erlang.memory()
      
      # Variety should reflect system complexity
      assert variety_data.metrics.cpu_cores == cpu_count
      assert variety_data.metrics.memory_mb > 0
      assert variety_data.metrics.processes == length(:erlang.processes())
    end
  end

  describe "real LLM integration" do
    @tag :integration
    @tag :requires_api_key
    test "queries LLM for search suggestions" do
      # Only run if API key is configured
      if System.get_env("ANTHROPIC_API_KEY") do
        suggestions = RealImplementation.get_llm_suggestions("create presentations")
        
        assert is_list(suggestions)
        assert length(suggestions) > 0
        assert Enum.all?(suggestions, &is_binary/1)
      else
        assert true  # Skip if no API key
      end
    end
  end

  describe "capability installation" do
    @tag :integration
    test "simulates MCP server installation" do
      server = %{
        name: "test-mcp-server",
        version: "1.0.0"
      }
      
      output = capture_io(fn ->
        result = RealImplementation.install_mcp_server(server)
        assert result == :ok or match?({:ok, _path}, result)
      end)
      
      assert String.contains?(output, "Installing") or String.contains?(output, "Would install")
    end

    test "verifies installation directory structure" do
      base_dir = Path.expand("~/.vsm-mcp/servers")
      
      # Should be able to create directory
      if not File.exists?(base_dir) do
        assert File.mkdir_p(base_dir) == :ok
      end
      
      assert File.dir?(base_dir)
    end
  end

  describe "end-to-end demonstration" do
    test "complete variety acquisition workflow" do
      output = capture_io(fn ->
        # 1. Calculate initial variety
        initial = RealImplementation.calculate_real_variety()
        assert initial.ratio <= 100
        
        # 2. Simulate variety gap
        gap = RealImplementation.simulate_variety_gap(initial)
        assert gap.ratio < initial.ratio
        
        # 3. Discover servers
        servers = RealImplementation.discover_real_mcp_servers()
        assert length(servers) > 0
        
        # 4. Simulate integration
        result = RealImplementation.simulate_integration(hd(servers))
        assert result == :ok
        
        # 5. Verify variety improvement
        final = RealImplementation.calculate_improved_variety(initial)
        assert final.ratio > gap.ratio
      end)
      
      # Should show complete workflow
      assert output =~ "Variety"
      assert output =~ "Searching"
    end
  end

  describe "PowerPoint creation" do
    @tag :integration
    test "demonstrates PowerPoint capability acquisition" do
      # This is what the system actually did in the demo
      output = capture_io(fn ->
        # 1. Detect need for PowerPoint
        need = RealImplementation.detect_capability_need("create powerpoint")
        assert need == :powerpoint_creation
        
        # 2. Find PowerPoint MCP servers
        servers = RealImplementation.search_for_capability("powerpoint pptx")
        
        if length(servers) > 0 do
          # 3. Would install and use
          server = hd(servers)
          assert Map.has_key?(server, :name)
        end
      end)
      
      assert output =~ "powerpoint" or output =~ "pptx" or output =~ "presentation"
    end
  end

  describe "real metrics tracking" do
    test "tracks actual system performance" do
      metrics = RealImplementation.get_system_metrics()
      
      assert Map.has_key?(metrics, :cpu_usage)
      assert Map.has_key?(metrics, :memory_usage)
      assert Map.has_key?(metrics, :process_count)
      assert Map.has_key?(metrics, :uptime)
      
      # All metrics should be real
      assert metrics.cpu_usage >= 0
      assert metrics.memory_usage > 0
      assert metrics.process_count > 0
      assert metrics.uptime >= 0
    end

    test "monitors variety changes over time" do
      # Take multiple measurements
      measurements = for _ <- 1..3 do
        Process.sleep(100)
        RealImplementation.calculate_real_variety()
      end
      
      # Should have different timestamps
      timestamps = Enum.map(measurements, & &1.timestamp)
      assert length(Enum.uniq(timestamps)) == 3
    end
  end
end