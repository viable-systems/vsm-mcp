#!/usr/bin/env elixir

# Direct test to see if VSM-MCP actually executes MCP servers

defmodule RealMCPExecutionTest do
  @moduledoc """
  This test will:
  1. Start the VSM-MCP system
  2. Request it to use the filesystem MCP server
  3. Monitor if an actual MCP server process is spawned
  4. Verify the communication protocol
  """
  
  def test_mcp_execution do
    IO.puts "\n🔬 === Real MCP Execution Test ===\n"
    
    # First, let's check the MCP demo example
    IO.puts "1. Examining MCP demo example..."
    check_mcp_demo()
    
    # Check if VSM-MCP has any running examples
    IO.puts "\n2. Looking for test scripts that use MCP..."
    check_test_scripts()
    
    # Try to trace actual MCP usage
    IO.puts "\n3. Checking for MCP protocol implementation..."
    check_mcp_protocol()
    
    # Look for process spawning code
    IO.puts "\n4. Checking process spawning mechanisms..."
    check_process_spawning()
    
    IO.puts "\n✅ Test complete!"
  end
  
  defp check_mcp_demo do
    demo_file = "examples/mcp_demo.exs"
    
    if File.exists?(demo_file) do
      content = File.read!(demo_file)
      IO.puts "✅ Found #{demo_file}"
      
      # Extract key patterns
      if String.contains?(content, "MCP.Client") do
        IO.puts "  - Uses MCP.Client module"
      end
      
      if String.contains?(content, "ServerManager") do
        IO.puts "  - Uses ServerManager"
      end
      
      if String.contains?(content, "start_server") do
        IO.puts "  - Starts MCP servers"
      end
      
      # Show a snippet
      lines = String.split(content, "\n")
      relevant_lines = Enum.filter(lines, fn line ->
        String.contains?(line, "MCP") or String.contains?(line, "server")
      end)
      
      IO.puts "\nRelevant code snippets:"
      Enum.take(relevant_lines, 5) |> Enum.each(&IO.puts("  #{&1}"))
    else
      IO.puts "❌ Demo file not found"
    end
  end
  
  defp check_test_scripts do
    # Find all test files that might use MCP
    test_pattern = "test_*.exs"
    test_files = Path.wildcard(test_pattern)
    
    mcp_test_files = Enum.filter(test_files, fn file ->
      content = File.read!(file)
      String.contains?(content, "MCP") or 
      String.contains?(content, "mcp") or
      String.contains?(content, "server")
    end)
    
    IO.puts "Found #{length(mcp_test_files)} test files with MCP references:"
    Enum.each(mcp_test_files, &IO.puts("  - #{&1}"))
  end
  
  defp check_mcp_protocol do
    protocol_file = "lib/vsm_mcp/mcp/protocol/json_rpc.ex"
    
    if File.exists?(protocol_file) do
      IO.puts "✅ Found JSON-RPC protocol implementation"
      
      content = File.read!(protocol_file)
      
      # Check for actual protocol methods
      methods = Regex.scan(~r/def\s+(\w+)/, content)
      |> Enum.map(fn [_, method] -> method end)
      |> Enum.filter(fn m -> String.contains?(m, "request") or String.contains?(m, "response") end)
      
      IO.puts "  Protocol methods: #{inspect(methods)}"
    else
      IO.puts "❌ Protocol file not found"
    end
  end
  
  defp check_process_spawning do
    server_process_file = "lib/vsm_mcp/mcp/server_manager/server_process.ex"
    
    if File.exists?(server_process_file) do
      content = File.read!(server_process_file)
      
      # Check for Port.open usage
      if String.contains?(content, "Port.open") do
        IO.puts "✅ Uses Port.open to spawn external processes"
        
        # Find the actual spawn command
        spawn_match = Regex.run(~r/Port\.open\(\{:spawn_executable[^}]+\}/, content)
        if spawn_match do
          IO.puts "  Spawn pattern: #{List.first(spawn_match)}"
        end
      end
      
      # Check for executable finding
      if String.contains?(content, "System.find_executable") do
        IO.puts "✅ Searches for executables in PATH"
      end
      
    else
      IO.puts "❌ Server process file not found"
    end
  end
end

# Now let's create a specific test that tries to use VSM-MCP
defmodule VSMMCPUsageTest do
  @moduledoc """
  Actually try to use VSM-MCP and see what happens
  """
  
  def run_vsm_test do
    IO.puts "\n🚀 === Attempting to use VSM-MCP ===\n"
    
    # Check if we can compile and load VSM-MCP modules
    test_file = "test_vsm_mcp_usage.exs"
    
    test_content = """
    # Load VSM-MCP application
    Code.require_file("mix.exs")
    
    # Try to use MCP functionality
    try do
      # Start the application
      {:ok, _} = Application.ensure_all_started(:vsm_mcp)
      
      IO.puts "✅ VSM-MCP application started"
      
      # Try to discover MCP servers
      case VsmMcp.Core.MCPDiscovery.search_mcp_servers(["filesystem"]) do
        {:ok, servers} ->
          IO.puts "✅ Discovery returned: \#{inspect(servers)}"
        error ->
          IO.puts "❌ Discovery failed: \#{inspect(error)}"
      end
      
      # Try to list installed servers
      case VsmMcp.Core.MCPDiscovery.list_installed_servers() do
        {:ok, installed} ->
          IO.puts "✅ Installed servers: \#{inspect(installed)}"
        error ->
          IO.puts "❌ Failed to list servers: \#{inspect(error)}"
      end
      
      # Try to start an MCP server
      config = %{
        type: :external,
        command: "mcp-server-filesystem",
        args: ["/tmp"],
        id: "test-filesystem"
      }
      
      case VsmMcp.MCP.ServerManager.start_server(config) do
        {:ok, server_id} ->
          IO.puts "✅ Started MCP server: \#{server_id}"
          
          # Check if process is actually running
          {:ok, status} = VsmMcp.MCP.ServerManager.get_status()
          IO.puts "Server status: \#{inspect(status)}"
          
        error ->
          IO.puts "❌ Failed to start server: \#{inspect(error)}"
      end
      
    rescue
      e ->
        IO.puts "❌ Error: \#{inspect(e)}"
        IO.puts Exception.format_stacktrace()
    end
    """
    
    File.write!(test_file, test_content)
    
    IO.puts "Created test file: #{test_file}"
    IO.puts "To run it: elixir #{test_file}"
    IO.puts "\nWhile it runs, check in another terminal:"
    IO.puts "  ps aux | grep mcp"
    IO.puts "  lsof -p <PID>"
  end
end

# Run the tests
RealMCPExecutionTest.test_mcp_execution()
VSMMCPUsageTest.run_vsm_test()

# Final verification
IO.puts """

📊 === Final Verification Steps ===

1. Check running processes:
   ps aux | grep -E "mcp|filesystem"

2. Check listening ports:
   netstat -tlnp | grep beam

3. Check Erlang processes:
   Run in iex: :erlang.processes() |> Enum.map(&:erlang.process_info(&1, :registered_name))

4. Enable debug logging:
   export ELIXIR_LOG_LEVEL=debug

5. Trace Port operations:
   In iex: :dbg.tracer()
           :dbg.p(:all, :c)
           :dbg.tpl(:erlang, :open_port, [])
"""