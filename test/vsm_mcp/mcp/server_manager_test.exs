defmodule VsmMcp.MCP.ServerManagerTest do
  use ExUnit.Case, async: false
  
  alias VsmMcp.MCP.ServerManager
  alias VsmMcp.MCP.ServerManager.ServerConfig
  
  setup do
    # Ensure a fresh manager for each test
    {:ok, manager} = ServerManager.start_link(name: :test_manager)
    
    on_exit(fn ->
      if Process.alive?(manager) do
        GenServer.stop(manager)
      end
    end)
    
    {:ok, manager: manager}
  end
  
  describe "server lifecycle" do
    test "starts and stops internal server", %{manager: manager} do
      config = ServerConfig.create_preset(:tcp, port: 5555, id: "test_tcp")
      
      assert {:ok, server_id} = ServerManager.start_server(manager, config)
      assert server_id == "test_tcp"
      
      # Verify server is running
      assert {:ok, status} = ServerManager.get_status(manager)
      assert length(status.servers) == 1
      assert hd(status.servers).id == "test_tcp"
      assert hd(status.servers).status == :running
      
      # Stop server
      assert :ok = ServerManager.stop_server(manager, server_id)
      
      # Verify server is stopped
      assert {:ok, status} = ServerManager.get_status(manager)
      assert length(status.servers) == 0
    end
    
    test "handles server not found", %{manager: manager} do
      assert {:error, :server_not_found} = ServerManager.stop_server(manager, "nonexistent")
    end
    
    test "prevents duplicate server IDs", %{manager: manager} do
      config = ServerConfig.create_preset(:tcp, port: 5556, id: "duplicate_test")
      
      assert {:ok, _} = ServerManager.start_server(manager, config)
      assert {:error, :server_already_exists} = ServerManager.start_server(manager, config)
    end
  end
  
  describe "custom servers" do
    test "starts custom server with function", %{manager: manager} do
      test_pid = self()
      
      config = %{
        type: :custom,
        id: "custom_test",
        start_fn: fn _config ->
          pid = spawn(fn ->
            send(test_pid, :custom_server_started)
            receive do
              :stop -> :ok
            end
          end)
          {:ok, %{pid: pid}}
        end
      }
      
      assert {:ok, "custom_test"} = ServerManager.start_server(manager, config)
      assert_receive :custom_server_started, 1_000
    end
  end
  
  describe "restart policies" do
    test "permanent restart policy", %{manager: manager} do
      test_pid = self()
      start_count = :counters.new(1, [])
      
      config = %{
        type: :custom,
        id: "permanent_test",
        restart_policy: :permanent,
        start_fn: fn _config ->
          :counters.add(start_count, 1, 1)
          count = :counters.get(start_count, 1)
          
          pid = spawn(fn ->
            send(test_pid, {:started, count})
            if count == 1 do
              # Crash on first start
              Process.exit(self(), :crash)
            else
              # Stay alive on restart
              receive do
                :stop -> :ok
              end
            end
          end)
          
          {:ok, %{pid: pid}}
        end
      }
      
      assert {:ok, _} = ServerManager.start_server(manager, config)
      
      # Wait for initial start and crash
      assert_receive {:started, 1}, 1_000
      
      # Wait for restart
      assert_receive {:started, 2}, 5_000
      
      # Verify server was restarted
      assert {:ok, status} = ServerManager.get_status(manager)
      server = Enum.find(status.servers, &(&1.id == "permanent_test"))
      assert server.restart_count >= 1
    end
    
    test "temporary restart policy", %{manager: manager} do
      test_pid = self()
      
      config = %{
        type: :custom,
        id: "temporary_test",
        restart_policy: :temporary,
        start_fn: fn _config ->
          pid = spawn(fn ->
            send(test_pid, :temporary_started)
            Process.exit(self(), :crash)
          end)
          
          {:ok, %{pid: pid}}
        end
      }
      
      assert {:ok, _} = ServerManager.start_server(manager, config)
      assert_receive :temporary_started, 1_000
      
      # Wait a bit to ensure no restart
      Process.sleep(2_000)
      
      # Verify server was not restarted
      assert {:ok, status} = ServerManager.get_status(manager)
      assert length(status.servers) == 0
    end
  end
  
  describe "health monitoring" do
    test "monitors server health", %{manager: manager} do
      health_status = :sys.replace_state(self(), fn _ -> :healthy end)
      
      config = %{
        type: :custom,
        id: "health_test",
        start_fn: fn _config ->
          {:ok, %{pid: self()}}
        end,
        health_check: %{
          type: :custom,
          interval_ms: 100,
          check_fn: fn _pid ->
            status = :sys.get_state(self())
            {:ok, status}
          end
        }
      }
      
      assert {:ok, server_id} = ServerManager.start_server(manager, config)
      
      # Wait for health check
      Process.sleep(500)
      
      assert {:ok, health} = ServerManager.get_health(manager, server_id)
      assert health.status == :healthy
    end
  end
  
  describe "bulk operations" do
    test "starts multiple servers", %{manager: manager} do
      configs = for i <- 1..3 do
        ServerConfig.create_preset(:tcp, port: 6000 + i, id: "bulk_#{i}")
      end
      
      assert {:ok, result} = ServerManager.start_servers(manager, configs)
      assert result.successful == 3
      assert result.failed == 0
      
      assert {:ok, status} = ServerManager.get_status(manager)
      assert length(status.servers) == 3
    end
    
    test "stops multiple servers", %{manager: manager} do
      # Start servers first
      configs = for i <- 1..3 do
        ServerConfig.create_preset(:tcp, port: 6100 + i, id: "bulk_stop_#{i}")
      end
      
      {:ok, _} = ServerManager.start_servers(manager, configs)
      
      # Stop them
      server_ids = Enum.map(1..3, &"bulk_stop_#{&1}")
      assert {:ok, results} = ServerManager.stop_servers(manager, server_ids)
      assert length(results) == 3
      assert Enum.all?(results, &match?({:ok, _}, &1))
      
      assert {:ok, status} = ServerManager.get_status(manager)
      assert length(status.servers) == 0
    end
  end
  
  describe "resource management" do
    test "tracks process resources", %{manager: manager} do
      config = %{
        type: :custom,
        id: "resource_test",
        start_fn: fn _config ->
          pid = spawn(fn ->
            # Allocate some memory
            data = :binary.copy(<<0>>, 1_000_000)  # 1MB
            Process.put(:data, data)
            receive do
              :stop -> :ok
            end
          end)
          
          {:ok, %{pid: pid}}
        end
      }
      
      assert {:ok, _} = ServerManager.start_server(manager, config)
      
      # Give it time to allocate memory
      Process.sleep(100)
      
      assert {:ok, status} = ServerManager.get_status(manager)
      assert status.resource_usage.processes > 0
      assert status.resource_usage.total_memory > 0
    end
  end
  
  describe "connection pooling" do
    test "manages connection pool", %{manager: manager} do
      config = %{
        type: :internal,
        id: "pool_test",
        pool_size: 2,
        max_overflow: 1,
        server_opts: [
          transport: :tcp,
          port: 7777,
          auto_start: true
        ]
      }
      
      assert {:ok, server_id} = ServerManager.start_server(manager, config)
      
      # Get connections up to pool size
      assert {:ok, _conn1} = ServerManager.get_connection(manager, server_id)
      assert {:ok, _conn2} = ServerManager.get_connection(manager, server_id)
      
      # This should create an overflow connection
      assert {:ok, _conn3} = ServerManager.get_connection(manager, server_id)
      
      # This should fail (max overflow reached)
      # Note: This would normally timeout, but in tests we might handle differently
    end
  end
  
  describe "configuration updates" do
    test "updates server configuration", %{manager: manager} do
      config = ServerConfig.create_preset(:tcp, port: 8888, id: "update_test")
      
      assert {:ok, server_id} = ServerManager.start_server(manager, config)
      
      # Update configuration
      new_config = %{pool_size: 20, restart_policy: :transient}
      assert :ok = ServerManager.update_config(manager, server_id, new_config)
      
      # Verify update
      assert {:ok, status} = ServerManager.get_status(manager)
      server = Enum.find(status.servers, &(&1.id == server_id))
      assert server.config.pool_size == 20
      assert server.config.restart_policy == :transient
    end
  end
  
  describe "metrics" do
    test "tracks operational metrics", %{manager: manager} do
      config = ServerConfig.create_preset(:tcp, port: 9999, id: "metrics_test")
      
      # Start and stop a server
      assert {:ok, server_id} = ServerManager.start_server(manager, config)
      assert :ok = ServerManager.stop_server(manager, server_id)
      
      # Check metrics
      assert {:ok, metrics} = ServerManager.get_metrics(manager)
      assert metrics.started >= 1
      assert metrics.stopped >= 1
    end
  end
end