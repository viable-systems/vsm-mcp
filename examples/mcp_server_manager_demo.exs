#!/usr/bin/env elixir

# MCP Server Manager Demo
# Demonstrates the bulletproof process management capabilities

require Logger

defmodule MCPServerManagerDemo do
  alias VsmMcp.MCP.ServerManager
  alias VsmMcp.MCP.ServerManager.ServerConfig
  
  def run do
    Logger.info("Starting MCP Server Manager Demo...")
    
    # Start the application
    {:ok, _} = Application.ensure_all_started(:vsm_mcp)
    
    # Demo 1: Start multiple server types
    demo_server_lifecycle()
    
    # Demo 2: Health monitoring and auto-restart
    demo_health_monitoring()
    
    # Demo 3: Resource management
    demo_resource_management()
    
    # Demo 4: Connection pooling
    demo_connection_pooling()
    
    # Demo 5: Bulk operations
    demo_bulk_operations()
    
    Logger.info("Demo completed!")
  end
  
  defp demo_server_lifecycle do
    Logger.info("\n=== Server Lifecycle Demo ===")
    
    # Create configurations for different server types
    stdio_config = ServerConfig.create_preset(:stdio, 
      command: "npx",
      args: ["some-mcp-server"],
      id: "stdio_server_1"
    )
    
    tcp_config = ServerConfig.create_preset(:tcp,
      port: 3334,
      id: "tcp_server_1"
    )
    
    # Start servers
    {:ok, stdio_id} = ServerManager.start_server(stdio_config)
    Logger.info("Started stdio server: #{stdio_id}")
    
    {:ok, tcp_id} = ServerManager.start_server(tcp_config)
    Logger.info("Started TCP server: #{tcp_id}")
    
    # Get status
    {:ok, status} = ServerManager.get_status()
    Logger.info("Server status: #{inspect(status, pretty: true)}")
    
    # Stop servers gracefully
    :ok = ServerManager.stop_server(stdio_id, graceful: true)
    :ok = ServerManager.stop_server(tcp_id)
    
    Logger.info("Servers stopped successfully")
  end
  
  defp demo_health_monitoring do
    Logger.info("\n=== Health Monitoring Demo ===")
    
    # Create a server with health checks
    config = %{
      type: :custom,
      id: "health_test_server",
      restart_policy: :permanent,
      start_fn: fn _config ->
        # Simulate a server that becomes unhealthy
        {:ok, spawn(fn ->
          Process.register(self(), :health_test_process)
          health_loop(:healthy, 0)
        end)}
      end,
      health_check: %{
        type: :custom,
        interval_ms: 2_000,
        check_fn: fn pid ->
          if Process.alive?(pid) do
            send(pid, {:health_check, self()})
            receive do
              {:health_status, status} -> {:ok, status}
            after
              1_000 -> {:ok, :unhealthy}
            end
          else
            {:ok, :unhealthy}
          end
        end
      }
    }
    
    {:ok, server_id} = ServerManager.start_server(config)
    Logger.info("Started health test server")
    
    # Monitor health for a while
    for i <- 1..5 do
      Process.sleep(3_000)
      {:ok, health} = ServerManager.get_health(server_id)
      Logger.info("Health check #{i}: #{inspect(health)}")
    end
    
    # Simulate server becoming unhealthy
    if pid = Process.whereis(:health_test_process) do
      send(pid, :become_unhealthy)
    end
    
    Process.sleep(10_000)
    
    # Check if server was restarted
    {:ok, status} = ServerManager.get_status()
    server = Enum.find(status.servers, &(&1.id == server_id))
    Logger.info("Server restart count: #{server.restart_count}")
    
    ServerManager.stop_server(server_id)
  end
  
  defp demo_resource_management do
    Logger.info("\n=== Resource Management Demo ===")
    
    # Create memory-intensive servers
    configs = for i <- 1..3 do
      %{
        type: :custom,
        id: "memory_server_#{i}",
        restart_policy: :temporary,
        start_fn: fn _config ->
          {:ok, spawn(fn ->
            # Allocate some memory
            data = :binary.copy(<<0>>, 10_000_000)  # 10MB
            Process.put(:data, data)
            receive do
              :stop -> :ok
            end
          end)}
        end
      }
    end
    
    # Start all servers
    server_ids = Enum.map(configs, fn config ->
      {:ok, id} = ServerManager.start_server(config)
      id
    end)
    
    # Check resource usage
    {:ok, status} = ServerManager.get_status()
    Logger.info("Resource usage: #{inspect(status.resource_usage, pretty: true)}")
    
    # Get metrics
    {:ok, metrics} = ServerManager.get_metrics()
    Logger.info("Manager metrics: #{inspect(metrics, pretty: true)}")
    
    # Clean up
    Enum.each(server_ids, &ServerManager.stop_server/1)
  end
  
  defp demo_connection_pooling do
    Logger.info("\n=== Connection Pooling Demo ===")
    
    # Create a server with connection pooling
    config = %{
      type: :internal,
      id: "pooled_server",
      pool_size: 5,
      max_overflow: 2,
      server_opts: [
        transport: :tcp,
        port: 3335,
        auto_start: true
      ]
    }
    
    {:ok, server_id} = ServerManager.start_server(config)
    Logger.info("Started server with connection pool")
    
    # Simulate multiple connection requests
    tasks = for i <- 1..10 do
      Task.async(fn ->
        case ServerManager.get_connection(server_id) do
          {:ok, conn} ->
            Logger.info("Task #{i} got connection: #{inspect(conn)}")
            Process.sleep(1_000)
            # Return connection to pool
            {:ok, i}
            
          {:error, reason} ->
            Logger.warning("Task #{i} failed to get connection: #{reason}")
            {:error, i}
        end
      end)
    end
    
    results = Task.await_many(tasks)
    successful = Enum.count(results, &match?({:ok, _}, &1))
    Logger.info("Connection requests: #{successful}/10 successful")
    
    ServerManager.stop_server(server_id)
  end
  
  defp demo_bulk_operations do
    Logger.info("\n=== Bulk Operations Demo ===")
    
    # Create multiple server configurations
    configs = for i <- 1..5 do
      ServerConfig.create_preset(:tcp,
        port: 4000 + i,
        id: "bulk_server_#{i}"
      )
    end
    
    # Start all servers at once
    {:ok, start_result} = ServerManager.start_servers(configs)
    Logger.info("Bulk start result: #{inspect(start_result)}")
    
    # Get all server IDs
    server_ids = Enum.map(1..5, &"bulk_server_#{&1}")
    
    # Update configuration for all servers
    for id <- server_ids do
      ServerManager.update_config(id, %{pool_size: 20})
    end
    
    # Stop all servers at once
    {:ok, stop_result} = ServerManager.stop_servers(server_ids)
    Logger.info("Bulk stop result: #{inspect(stop_result)}")
  end
  
  # Helper function for health monitoring demo
  defp health_loop(status, check_count) do
    receive do
      {:health_check, from} ->
        send(from, {:health_status, status})
        health_loop(status, check_count + 1)
        
      :become_unhealthy ->
        Logger.info("Server becoming unhealthy after #{check_count} checks")
        health_loop(:unhealthy, check_count)
        
      :stop ->
        :ok
    end
  end
end

# Run the demo
MCPServerManagerDemo.run()