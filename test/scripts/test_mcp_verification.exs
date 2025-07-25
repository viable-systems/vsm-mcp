#!/usr/bin/env elixir

# Direct verification of MCP server usage vs fallback

Code.prepend_path("_build/dev/lib/vsm_mcp/ebin")

# Load all dependencies
deps_path = "_build/dev/lib"
File.ls!(deps_path)
|> Enum.each(fn dep ->
  ebin = Path.join([deps_path, dep, "ebin"])
  if File.dir?(ebin), do: Code.prepend_path(ebin)
end)

defmodule MCPVerification do
  @moduledoc """
  Verify if VSM-MCP actually uses MCP servers or falls back to direct execution
  """
  
  def run_verification do
    IO.puts "\n🔍 === MCP Server Usage Verification ===\n"
    
    # Start the application
    IO.puts "1. Starting VSM-MCP application..."
    case Application.ensure_all_started(:vsm_mcp) do
      {:ok, _apps} ->
        IO.puts "✅ Application started successfully"
        
        # Run tests
        test_mcp_discovery()
        test_server_manager()
        test_actual_execution()
        test_fallback_behavior()
        
      {:error, reason} ->
        IO.puts "❌ Failed to start application: #{inspect(reason)}"
    end
  end
  
  defp test_mcp_discovery do
    IO.puts "\n2. Testing MCP Discovery..."
    
    # Check if discovery GenServer is running
    case Process.whereis(VsmMcp.Core.MCPDiscovery) do
      nil ->
        IO.puts "❌ Discovery GenServer not running"
      pid ->
        IO.puts "✅ Discovery GenServer running: #{inspect(pid)}"
        
        # Try to search for servers
        case VsmMcp.Core.MCPDiscovery.search_mcp_servers(["filesystem", "file"]) do
          {:ok, results} ->
            IO.puts "✅ Search returned #{length(results)} results"
            Enum.take(results, 3) |> Enum.each(fn server ->
              IO.puts "   - #{server[:name]} (#{server[:source]})"
            end)
          error ->
            IO.puts "❌ Search failed: #{inspect(error)}"
        end
    end
  end
  
  defp test_server_manager do
    IO.puts "\n3. Testing Server Manager..."
    
    # Check if ServerManager is running
    case Process.whereis(VsmMcp.MCP.ServerManager) do
      nil ->
        IO.puts "❌ ServerManager not running"
      pid ->
        IO.puts "✅ ServerManager running: #{inspect(pid)}"
        
        # Check status
        case VsmMcp.MCP.ServerManager.get_status() do
          {:ok, status} ->
            IO.puts "✅ ServerManager status retrieved:"
            IO.puts "   - Active servers: #{length(status.servers)}"
            IO.puts "   - Metrics: #{inspect(status.metrics)}"
          error ->
            IO.puts "❌ Failed to get status: #{inspect(error)}"
        end
    end
  end
  
  defp test_actual_execution do
    IO.puts "\n4. Testing Actual MCP Execution..."
    
    # Monitor process spawning
    tracer_pid = spawn(fn ->
      receive do
        {:trace, _pid, :spawn, new_pid, _} ->
          IO.puts "🔍 Process spawned: #{inspect(new_pid)}"
        {:trace, _pid, :port_open, port, _} ->
          IO.puts "🔍 Port opened: #{inspect(port)}"
        _ ->
          :ok
      end
    end)
    
    :erlang.trace(:all, true, [:procs, :ports, {:tracer, tracer_pid}])
    
    # Try to start a real MCP server
    config = %{
      type: :external,
      command: "mcp-server-filesystem",
      args: ["/tmp"],
      env: %{},
      id: "test-fs-server"
    }
    
    IO.puts "Attempting to start filesystem MCP server..."
    case VsmMcp.MCP.ServerManager.start_server(config) do
      {:ok, server_id} ->
        IO.puts "✅ Server started: #{server_id}"
        
        # Give it time to initialize
        Process.sleep(1000)
        
        # Check if it's really running
        case VsmMcp.MCP.ServerManager.get_health(server_id) do
          {:ok, health} ->
            IO.puts "✅ Server health: #{inspect(health)}"
          error ->
            IO.puts "❌ Health check failed: #{inspect(error)}"
        end
        
        # Stop the server
        VsmMcp.MCP.ServerManager.stop_server(server_id)
        
      {:error, reason} ->
        IO.puts "❌ Failed to start server: #{inspect(reason)}"
    end
    
    :erlang.trace(:all, false, [:procs, :ports])
  end
  
  defp test_fallback_behavior do
    IO.puts "\n5. Testing Fallback Behavior..."
    
    # Look for capability acquisition
    operation = %{
      type: :capability_test,
      target: :file_operations,
      context: %{test: true}
    }
    
    # Check System1 implementation
    case Code.ensure_loaded(VsmMcp.Systems.System1) do
      {:module, _} ->
        IO.puts "✅ System1 module loaded"
        
        # Check if it uses MCP or fallback
        exports = VsmMcp.Systems.System1.__info__(:functions)
        
        if :execute_operation in Keyword.keys(exports) do
          IO.puts "✅ execute_operation function exists"
          
          # Try to execute
          case VsmMcp.Systems.System1.execute_operation(operation) do
            {:ok, result} ->
              IO.puts "✅ Operation executed:"
              IO.puts "   - Method: #{result[:method]}"
              IO.puts "   - Status: #{result[:status]}"
              
              # Check if it used MCP or fallback
              if result[:method] == :direct do
                IO.puts "⚠️  Using DIRECT execution (fallback)"
              else
                IO.puts "✅ Using MCP-based execution"
              end
              
            error ->
              IO.puts "❌ Operation failed: #{inspect(error)}"
          end
        end
        
      {:error, reason} ->
        IO.puts "❌ System1 not loaded: #{reason}"
    end
  end
end

# Check for running MCP processes before and after
IO.puts "\n📊 Pre-test MCP processes:"
System.cmd("ps", ["aux"], stderr_to_stdout: true)
|> elem(0)
|> String.split("\n")
|> Enum.filter(&String.contains?(&1, "mcp"))
|> Enum.each(&IO.puts("  #{&1}"))

# Run verification
MCPVerification.run_verification()

# Check again after
IO.puts "\n📊 Post-test MCP processes:"
System.cmd("ps", ["aux"], stderr_to_stdout: true)
|> elem(0)
|> String.split("\n")
|> Enum.filter(&String.contains?(&1, "mcp"))
|> Enum.each(&IO.puts("  #{&1}"))

IO.puts """

🎯 === Verification Summary ===

To determine if VSM-MCP uses real MCP servers:

1. Real MCP Usage Indicators:
   ✅ External processes spawned (mcp-server-*)
   ✅ Port.open calls to executable
   ✅ JSON-RPC communication over stdio/tcp
   ✅ Server health monitoring
   ✅ Process lifecycle management

2. Fallback Indicators:
   ❌ Direct function calls only
   ❌ No external processes
   ❌ Immediate responses without protocol
   ❌ Method returns :direct or :simulated

3. Verification Commands:
   - Watch processes: watch -n 1 'ps aux | grep mcp'
   - Monitor ports: lsof -i -P -n | grep LISTEN
   - Trace Erlang: :erlang.trace(:all, true, [:ports])

Based on the tests above, VSM-MCP appears to:
#{if File.exists?("lib/vsm_mcp/mcp/server_manager/server_process.ex") do
  "✅ Have infrastructure for real MCP server execution"
else
  "❌ Lack infrastructure for MCP server execution"
end}
"""