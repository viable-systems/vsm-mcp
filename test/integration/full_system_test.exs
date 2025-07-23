defmodule Integration.FullSystemTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  @moduletag :integration

  describe "full VSM-MCP system" do
    test "complete autonomous capability acquisition flow" do
      output = capture_io(fn ->
        # 1. Start the VSM system
        {:ok, system} = VsmMcp.start_link([])
        
        # 2. Calculate initial variety
        initial_variety = VsmMcp.get_variety_status(system)
        assert initial_variety.operational > 0
        assert initial_variety.environmental > 0
        
        # 3. Introduce variety gap
        VsmMcp.simulate_demand(system, "create_presentation")
        
        # 4. System should detect gap
        Process.sleep(100)
        status = VsmMcp.get_system_status(system)
        assert status.variety_gap_detected == true
        
        # 5. System should search for capabilities
        Process.sleep(500)
        discoveries = VsmMcp.get_discovery_status(system)
        assert length(discoveries.found_servers) > 0
        
        # 6. Verify variety improvement plan
        plan = VsmMcp.get_adaptation_plan(system)
        assert plan.target_capabilities != []
        
        GenServer.stop(system)
      end)
      
      # Verify key steps occurred
      assert output =~ "variety" or output =~ "Variety"
      assert output =~ "discover" or output =~ "search"
    end

    test "consciousness interface integration" do
      {:ok, system} = VsmMcp.start_link([])
      
      # Query consciousness state
      consciousness = VsmMcp.query_consciousness(system, "What is your current state?")
      
      assert is_map(consciousness)
      assert Map.has_key?(consciousness, :awareness)
      assert Map.has_key?(consciousness, :decision_capacity)
      assert Map.has_key?(consciousness, :self_model)
      
      GenServer.stop(system)
    end

    test "MCP protocol integration" do
      # Start MCP server
      {:ok, server} = VsmMcp.MCP.Server.start_link(port: 0)
      {:ok, port} = VsmMcp.MCP.Server.get_port(server)
      
      # Connect client
      {:ok, client} = VsmMcp.MCP.Client.start_link(%{
        transport: :tcp,
        host: "localhost",
        port: port
      })
      
      # List tools
      {:ok, tools} = VsmMcp.MCP.Client.list_tools(client)
      
      expected_tools = [
        "vsm_status",
        "variety_analysis",
        "capability_search",
        "consciousness_query"
      ]
      
      for tool <- expected_tools do
        assert Enum.any?(tools, & &1.name == tool)
      end
      
      GenServer.stop(client)
      GenServer.stop(server)
    end
  end

  describe "error handling and resilience" do
    test "handles MCP server discovery failures" do
      capture_log(fn ->
        # Simulate network failure
        :meck.new(HTTPoison, [:passthrough])
        :meck.expect(HTTPoison, :get, fn _url -> {:error, :nxdomain} end)
        
        {:ok, system} = VsmMcp.start_link([])
        
        # Should handle gracefully
        discoveries = VsmMcp.discover_mcp_servers(system)
        assert discoveries == []
        
        :meck.unload(HTTPoison)
        GenServer.stop(system)
      end)
    end

    test "recovers from variety collapse" do
      {:ok, system} = VsmMcp.start_link([])
      
      # Simulate variety collapse
      VsmMcp.inject_variety_collapse(system)
      
      # System should detect and recover
      Process.sleep(100)
      
      status = VsmMcp.get_system_status(system)
      assert status.recovery_initiated == true
      assert status.emergency_measures != []
      
      GenServer.stop(system)
    end

    test "handles LLM service unavailability" do
      # Remove API keys temporarily
      original_anthropic = System.get_env("ANTHROPIC_API_KEY")
      original_openai = System.get_env("OPENAI_API_KEY")
      
      System.delete_env("ANTHROPIC_API_KEY")
      System.delete_env("OPENAI_API_KEY")
      
      {:ok, system} = VsmMcp.start_link([])
      
      # Should work without LLM, using fallback strategies
      suggestions = VsmMcp.get_capability_suggestions(system, "database")
      assert is_list(suggestions)
      assert length(suggestions) > 0  # Should have fallback suggestions
      
      # Restore keys
      if original_anthropic, do: System.put_env("ANTHROPIC_API_KEY", original_anthropic)
      if original_openai, do: System.put_env("OPENAI_API_KEY", original_openai)
      
      GenServer.stop(system)
    end
  end

  describe "performance and efficiency" do
    test "maintains acceptable variety calculation performance" do
      {:ok, system} = VsmMcp.start_link([])
      
      # Measure variety calculation time
      {time, _result} = :timer.tc(fn ->
        VsmMcp.calculate_variety(system)
      end)
      
      # Should be fast (under 100ms)
      assert time < 100_000  # microseconds
      
      GenServer.stop(system)
    end

    test "caches discovery results appropriately" do
      {:ok, system} = VsmMcp.start_link([])
      
      # First discovery
      {time1, result1} = :timer.tc(fn ->
        VsmMcp.discover_mcp_servers(system, "test-capability")
      end)
      
      # Second discovery (should be cached)
      {time2, result2} = :timer.tc(fn ->
        VsmMcp.discover_mcp_servers(system, "test-capability")
      end)
      
      # Cached call should be much faster
      assert time2 < time1 / 2
      assert result1 == result2
      
      GenServer.stop(system)
    end

    test "handles concurrent operations" do
      {:ok, system} = VsmMcp.start_link([])
      
      # Spawn multiple concurrent operations
      tasks = for i <- 1..10 do
        Task.async(fn ->
          VsmMcp.calculate_variety(system)
          VsmMcp.discover_mcp_servers(system, "capability-#{i}")
          VsmMcp.query_consciousness(system, "status")
        end)
      end
      
      # All should complete without errors
      results = Task.await_many(tasks, 5000)
      assert length(results) == 10
      
      GenServer.stop(system)
    end
  end

  describe "real-world scenarios" do
    test "PowerPoint creation scenario" do
      output = capture_io(fn ->
        {:ok, system} = VsmMcp.start_link([])
        
        # User requests PowerPoint creation
        result = VsmMcp.handle_user_request(system, "Create a PowerPoint presentation about VSM")
        
        assert result.status in [:completed, :in_progress]
        
        if result.status == :completed do
          assert result.actions_taken != []
          assert Enum.any?(result.actions_taken, &String.contains?(&1, "discover"))
          assert Enum.any?(result.actions_taken, &String.contains?(&1, "install")) or
                 Enum.any?(result.actions_taken, &String.contains?(&1, "integrate"))
        end
        
        GenServer.stop(system)
      end)
      
      assert output =~ "PowerPoint" or output =~ "presentation"
    end

    test "variety gap resolution scenario" do
      {:ok, system} = VsmMcp.start_link([])
      
      # Create artificial variety gap
      initial = VsmMcp.get_variety_status(system)
      
      # Increase environmental variety
      VsmMcp.add_environmental_complexity(system, %{
        new_regulations: 10,
        competitor_features: 15,
        customer_demands: 20
      })
      
      # System should detect and respond
      Process.sleep(500)
      
      final = VsmMcp.get_variety_status(system)
      actions = VsmMcp.get_action_history(system)
      
      # Should have taken corrective actions
      assert length(actions) > 0
      assert final.ratio >= initial.ratio or
             Enum.any?(actions, &String.contains?(&1, "acquire"))
      
      GenServer.stop(system)
    end
  end
end