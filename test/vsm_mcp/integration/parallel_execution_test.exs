defmodule VsmMcp.Integration.ParallelExecutionTest do
  @moduledoc """
  Tests for parallel execution and fault tolerance in the VSM-MCP system.
  
  Tests:
  - Concurrent capability discovery
  - Parallel MCP server installation
  - Race condition handling
  - Fault tolerance and recovery
  - Performance under load
  """
  
  use ExUnit.Case, async: false
  alias VsmMcp.Integration.{DynamicSpawner, Installer, Verifier}
  alias VsmMcp.Core.{MCPDiscovery, VarietyCalculator}
  
  @test_timeout 30_000
  
  setup do
    # Start required processes
    start_supervised!(MCPDiscovery)
    start_supervised!(VarietyCalculator)
    
    # Create test directory
    test_dir = Path.join(System.tmp_dir!(), "vsm_mcp_parallel_test_#{:rand.uniform(10000)}")
    File.mkdir_p!(test_dir)
    
    on_exit(fn ->
      File.rm_rf!(test_dir)
    end)
    
    {:ok, %{test_dir: test_dir}}
  end
  
  describe "concurrent capability discovery" do
    test "handles multiple simultaneous discovery requests" do
      # Create 10 concurrent discovery tasks
      tasks = for i <- 1..10 do
        Task.async(fn ->
          {:ok, servers} = MCPDiscovery.search_servers(%{
            capability: "test_capability_#{i}",
            requirements: ["async", "concurrent"]
          })
          {i, servers}
        end)
      end
      
      # Wait for all tasks with timeout
      results = Task.await_many(tasks, @test_timeout)
      
      # All should complete successfully
      assert length(results) == 10
      assert Enum.all?(results, fn {_i, servers} -> is_list(servers) end)
    end
    
    test "maintains consistency under concurrent reads" do
      # Seed with known data
      test_servers = [
        %{name: "server1", capabilities: ["cap1", "cap2"]},
        %{name: "server2", capabilities: ["cap2", "cap3"]},
        %{name: "server3", capabilities: ["cap1", "cap3"]}
      ]
      
      for server <- test_servers do
        MCPDiscovery.register_server(server)
      end
      
      # Concurrent reads for same capability
      tasks = for _ <- 1..20 do
        Task.async(fn ->
          MCPDiscovery.find_by_capability("cap2")
        end)
      end
      
      results = Task.await_many(tasks, @test_timeout)
      
      # All results should be identical
      first_result = hd(results)
      assert Enum.all?(results, &(&1 == first_result))
      assert length(first_result) == 2  # server1 and server2 have cap2
    end
  end
  
  describe "parallel installation" do
    test "installs multiple MCP servers concurrently", %{test_dir: test_dir} do
      # Mock servers to install
      servers = for i <- 1..5 do
        %{
          name: "test-server-#{i}",
          source: "mock://test-server-#{i}",
          version: "1.0.0"
        }
      end
      
      # Install all concurrently
      install_tasks = Enum.map(servers, fn server ->
        Task.async(fn ->
          Installer.install_server(server, test_dir)
        end)
      end)
      
      results = Task.await_many(install_tasks, @test_timeout)
      
      # All should succeed
      assert Enum.all?(results, fn
        {:ok, _} -> true
        _ -> false
      end)
      
      # Verify installations don't conflict
      installed = File.ls!(test_dir)
      assert length(installed) == 5
      assert Enum.all?(1..5, fn i -> "test-server-#{i}" in installed end)
    end
    
    test "handles installation failures gracefully" do
      servers = [
        %{name: "good-server", source: "mock://good", version: "1.0.0"},
        %{name: "bad-server", source: "invalid://bad", version: "1.0.0"},
        %{name: "another-good", source: "mock://good2", version: "1.0.0"}
      ]
      
      results = servers
      |> Enum.map(&Task.async(fn -> Installer.install_server(&1, "/tmp") end))
      |> Task.await_many(@test_timeout)
      
      # Should have mixed results
      assert {:ok, _} = Enum.at(results, 0)
      assert {:error, _} = Enum.at(results, 1)
      assert {:ok, _} = Enum.at(results, 2)
    end
  end
  
  describe "race condition handling" do
    test "prevents duplicate installations" do
      server = %{name: "singleton-server", source: "mock://singleton", version: "1.0.0"}
      test_dir = Path.join(System.tmp_dir!(), "race_test_#{:rand.uniform(10000)}")
      File.mkdir_p!(test_dir)
      
      try do
        # Try to install same server 10 times concurrently
        tasks = for _ <- 1..10 do
          Task.async(fn ->
            Installer.install_server(server, test_dir)
          end)
        end
        
        results = Task.await_many(tasks, @test_timeout)
        
        # Only one should succeed, others should get "already installed" error
        success_count = Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)
        
        assert success_count == 1
        
        error_count = Enum.count(results, fn
          {:error, :already_installed} -> true
          _ -> false
        end)
        
        assert error_count == 9
      after
        File.rm_rf!(test_dir)
      end
    end
    
    test "handles concurrent variety calculations" do
      # Trigger multiple variety calculations
      tasks = for i <- 1..20 do
        Task.async(fn ->
          VarietyCalculator.calculate_variety(%{
            system: "test-#{i}",
            timestamp: System.system_time()
          })
        end)
      end
      
      results = Task.await_many(tasks, @test_timeout)
      
      # All should complete without errors
      assert length(results) == 20
      assert Enum.all?(results, fn {:ok, variety} -> 
        is_number(variety.operational) and is_number(variety.environmental)
      end)
    end
  end
  
  describe "fault tolerance" do
    test "recovers from crashed discovery process" do
      # Get discovery process
      discovery_pid = Process.whereis(MCPDiscovery)
      assert discovery_pid
      
      # Kill it
      Process.exit(discovery_pid, :kill)
      
      # Wait for restart
      Process.sleep(100)
      
      # Should be able to use it again
      assert {:ok, _} = MCPDiscovery.search_servers(%{capability: "test"})
      
      # New process should be running
      new_pid = Process.whereis(MCPDiscovery)
      assert new_pid
      assert new_pid != discovery_pid
    end
    
    test "handles timeouts in parallel operations" do
      # Create tasks with different timeouts
      tasks = [
        Task.async(fn -> 
          Process.sleep(100)
          {:ok, "fast"}
        end),
        Task.async(fn -> 
          Process.sleep(5000)  # Will timeout
          {:ok, "slow"}
        end),
        Task.async(fn -> 
          Process.sleep(200)
          {:ok, "medium"}
        end)
      ]
      
      # Use shorter timeout
      results = tasks
      |> Enum.map(fn task ->
        case Task.yield(task, 1000) || Task.shutdown(task) do
          {:ok, result} -> result
          nil -> {:error, :timeout}
        end
      end)
      
      assert {:ok, "fast"} in results
      assert {:error, :timeout} in results
      assert {:ok, "medium"} in results
    end
    
    test "maintains system stability under load" do
      # Generate high load
      load_tasks = for i <- 1..100 do
        Task.async(fn ->
          operation = rem(i, 4)
          
          case operation do
            0 -> MCPDiscovery.search_servers(%{capability: "load-test"})
            1 -> VarietyCalculator.calculate_variety(%{})
            2 -> DynamicSpawner.spawn_for_capability(%{type: "test"})
            3 -> Verifier.verify_capability(%{name: "test"}, "load-test")
          end
        end)
      end
      
      # Should handle all without crashing
      results = load_tasks
      |> Enum.map(&Task.yield(&1, 5000))
      |> Enum.reject(&is_nil/1)
      
      # Most should complete (allow some timeouts under load)
      completion_rate = length(results) / 100
      assert completion_rate > 0.8  # 80% completion rate
    end
  end
  
  describe "performance optimizations" do
    test "caches discovery results appropriately" do
      capability = "cached-capability"
      
      # First call - should hit external source
      {time1, {:ok, result1}} = :timer.tc(fn ->
        MCPDiscovery.search_servers(%{capability: capability})
      end)
      
      # Second call - should hit cache
      {time2, {:ok, result2}} = :timer.tc(fn ->
        MCPDiscovery.search_servers(%{capability: capability})
      end)
      
      # Cache should make it faster
      assert time2 < time1 / 2
      assert result1 == result2
    end
    
    test "batches operations efficiently" do
      # Queue multiple operations
      operations = for i <- 1..50 do
        %{type: :discover, capability: "batch-test-#{rem(i, 5)}"}
      end
      
      # Process in batches
      {time, results} = :timer.tc(fn ->
        operations
        |> Enum.chunk_every(10)
        |> Enum.map(fn batch ->
          Task.async_stream(batch, fn op ->
            MCPDiscovery.search_servers(op)
          end, max_concurrency: 10)
          |> Enum.to_list()
        end)
        |> List.flatten()
      end)
      
      # Should complete quickly with batching
      assert length(results) == 50
      assert time < 5_000_000  # Less than 5 seconds for 50 ops
    end
  end
  
  describe "integration scenarios" do
    test "full parallel discovery and installation flow", %{test_dir: test_dir} do
      # Simulate variety gap detection
      {:ok, variety} = VarietyCalculator.calculate_variety(%{
        required_capabilities: ["web-search", "data-analysis", "ml-inference"],
        current_capabilities: ["file-ops"]
      })
      
      assert variety.gap > 0
      
      # Discover servers for missing capabilities
      discovery_tasks = ["web-search", "data-analysis", "ml-inference"]
      |> Enum.map(fn cap ->
        Task.async(fn ->
          {:ok, servers} = MCPDiscovery.search_servers(%{capability: cap})
          {cap, List.first(servers)}
        end)
      end)
      
      discoveries = Task.await_many(discovery_tasks, @test_timeout)
      
      # Install discovered servers in parallel
      install_tasks = discoveries
      |> Enum.reject(fn {_, server} -> is_nil(server) end)
      |> Enum.map(fn {cap, server} ->
        Task.async(fn ->
          {:ok, path} = Installer.install_server(server, test_dir)
          {cap, path}
        end)
      end)
      
      installations = Task.await_many(install_tasks, @test_timeout)
      
      # Verify all installed
      assert length(installations) > 0
      
      # Spawn processes for new capabilities
      spawn_tasks = installations
      |> Enum.map(fn {cap, path} ->
        Task.async(fn ->
          DynamicSpawner.spawn_server(path, %{capability: cap})
        end)
      end)
      
      spawned = Task.await_many(spawn_tasks, @test_timeout)
      
      # All should be running
      assert Enum.all?(spawned, fn {:ok, pid} -> Process.alive?(pid) end)
    end
  end
end