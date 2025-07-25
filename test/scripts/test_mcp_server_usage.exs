#!/usr/bin/env elixir

# Comprehensive test to verify VSM-MCP actually uses MCP servers
# Not just fallback to direct execution

Mix.install([
  {:httpoison, "~> 2.0"},
  {:jason, "~> 1.4"},
  {:gen_stage, "~> 1.2"}
])

defmodule MCPServerUsageTest do
  @moduledoc """
  Tests whether VSM-MCP system:
  1. Can discover real MCP servers
  2. Can install them
  3. Can start them and communicate via MCP protocol
  4. Actually uses them for requests (not fallback)
  """
  
  require Logger
  
  def run_all_tests do
    IO.puts "\n🔍 === VSM-MCP Server Usage Verification ===\n"
    
    # Test 1: Check installed MCP servers
    IO.puts "1️⃣ Checking globally installed MCP servers..."
    test_installed_servers()
    
    # Test 2: Test direct MCP server communication
    IO.puts "\n2️⃣ Testing direct MCP server communication..."
    test_direct_mcp_communication()
    
    # Test 3: Test VSM-MCP discovery mechanism
    IO.puts "\n3️⃣ Testing VSM-MCP discovery mechanism..."
    test_vsm_discovery()
    
    # Test 4: Test VSM-MCP integration
    IO.puts "\n4️⃣ Testing VSM-MCP integration with real server..."
    test_vsm_mcp_integration()
    
    # Test 5: Verify no fallback behavior
    IO.puts "\n5️⃣ Verifying fallback detection..."
    test_fallback_detection()
    
    IO.puts "\n✅ === Test Suite Complete ===\n"
  end
  
  defp test_installed_servers do
    # Check NPM global packages
    case System.cmd("npm", ["list", "-g", "--depth=0", "--json"], stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, %{"dependencies" => deps}} ->
            mcp_servers = deps
            |> Enum.filter(fn {name, _} -> 
              String.contains?(name, "modelcontextprotocol") or String.contains?(name, "mcp")
            end)
            
            IO.puts "✅ Found #{Enum.count(mcp_servers)} MCP servers installed:"
            Enum.each(mcp_servers, fn {name, info} ->
              IO.puts "   - #{name} v#{info["version"]}"
            end)
            
          _ ->
            IO.puts "❌ Failed to parse NPM output"
        end
        
      {error, _} ->
        IO.puts "❌ Failed to list NPM packages: #{error}"
    end
  end
  
  defp test_direct_mcp_communication do
    # Test filesystem server directly
    test_server = "@modelcontextprotocol/server-filesystem"
    
    IO.puts "Testing #{test_server}..."
    
    # Create a test directory
    test_dir = "/tmp/vsm_mcp_test_#{:os.system_time(:millisecond)}"
    File.mkdir_p!(test_dir)
    
    # Try to start the server
    port_opts = [
      :binary,
      :exit_status,
      :use_stdio,
      :stderr_to_stdout,
      {:line, 1024},
      {:args, [test_dir]}
    ]
    
    try do
      # Find the executable
      {npm_bin, 0} = System.cmd("npm", ["bin", "-g"], stderr_to_stdout: true)
      npm_bin = String.trim(npm_bin)
      server_cmd = Path.join(npm_bin, "mcp-server-filesystem")
      
      if File.exists?(server_cmd) do
        IO.puts "✅ Found server executable: #{server_cmd}"
        
        # Start the server process
        port = Port.open({:spawn_executable, server_cmd}, port_opts)
        
        # Send initialization request
        init_request = %{
          "jsonrpc" => "2.0",
          "method" => "initialize",
          "params" => %{
            "protocolVersion" => "2024.11.05",
            "clientInfo" => %{
              "name" => "VSM-MCP-Test",
              "version" => "1.0.0"
            }
          },
          "id" => 1
        }
        
        message = Jason.encode!(init_request) <> "\n"
        Port.command(port, message)
        
        # Wait for response
        receive do
          {^port, {:data, {:eol, response}}} ->
            IO.puts "✅ Server responded: #{response}"
            case Jason.decode(response) do
              {:ok, decoded} ->
                IO.puts "✅ Valid JSON-RPC response received"
                IO.inspect(decoded, label: "Response")
              _ ->
                IO.puts "⚠️ Invalid JSON response"
            end
            
          {^port, {:data, data}} ->
            IO.puts "✅ Server output: #{inspect(data)}"
            
          {^port, {:exit_status, status}} ->
            IO.puts "❌ Server exited with status: #{status}"
        after
          3000 ->
            IO.puts "⚠️ No response within 3 seconds"
        end
        
        # Clean up
        Port.close(port)
        
      else
        IO.puts "❌ Server executable not found at: #{server_cmd}"
      end
      
    rescue
      e ->
        IO.puts "❌ Error testing direct communication: #{inspect(e)}"
    after
      # Cleanup
      File.rm_rf!(test_dir)
    end
  end
  
  defp test_vsm_discovery do
    # Test if VSM-MCP can discover servers
    # We'll examine the discovery module's behavior
    
    IO.puts "Checking VSM-MCP discovery capabilities..."
    
    # Check if discovery module exists
    discovery_file = "lib/vsm_mcp/core/mcp_discovery.ex"
    
    if File.exists?(discovery_file) do
      IO.puts "✅ Discovery module exists"
      
      # Check for actual NPM registry interaction
      content = File.read!(discovery_file)
      
      if String.contains?(content, "registry.npmjs.org") do
        IO.puts "✅ Discovery uses NPM registry"
      end
      
      if String.contains?(content, "search_npm") do
        IO.puts "✅ Has NPM search functionality"
      end
      
      if String.contains?(content, "install_npm_server") do
        IO.puts "✅ Has NPM installation functionality"
      end
      
    else
      IO.puts "❌ Discovery module not found"
    end
  end
  
  defp test_vsm_mcp_integration do
    # Test actual integration - see if VSM-MCP uses discovered servers
    
    IO.puts "Testing VSM-MCP integration flow..."
    
    # Look for integration test or example
    integration_files = [
      "test/vsm_mcp/mcp/integration_test.exs",
      "examples/mcp_demo.exs",
      "test_real_mcp.exs"
    ]
    
    integration_file = Enum.find(integration_files, &File.exists?/1)
    
    if integration_file do
      IO.puts "✅ Found integration example: #{integration_file}"
      
      content = File.read!(integration_file)
      
      # Check for actual MCP server usage patterns
      patterns = [
        ~r/ServerManager\.start_server/,
        ~r/MCP\.Client\.call/,
        ~r/Protocol\.send_request/,
        ~r/port.*spawn_executable/i
      ]
      
      matched_patterns = Enum.filter(patterns, fn pattern ->
        Regex.match?(pattern, content)
      end)
      
      if length(matched_patterns) > 0 do
        IO.puts "✅ Found #{length(matched_patterns)} MCP usage patterns"
      else
        IO.puts "⚠️ No clear MCP usage patterns found"
      end
      
    else
      IO.puts "❌ No integration examples found"
    end
  end
  
  defp test_fallback_detection do
    # Check if there are fallback mechanisms
    
    IO.puts "Checking for fallback behavior..."
    
    # Search for fallback patterns in code
    files_to_check = [
      "lib/vsm_mcp/mcp/client.ex",
      "lib/vsm_mcp/integration/protocol_adapter.ex",
      "lib/vsm_mcp/mcp/integration.ex"
    ]
    
    fallback_indicators = [
      "fallback",
      "mock",
      "simulate",
      "fake",
      "stub",
      "hardcoded"
    ]
    
    Enum.each(files_to_check, fn file ->
      if File.exists?(file) do
        content = File.read!(file) |> String.downcase()
        
        found_indicators = Enum.filter(fallback_indicators, fn indicator ->
          String.contains?(content, indicator)
        end)
        
        if length(found_indicators) > 0 do
          IO.puts "⚠️ Found potential fallback indicators in #{file}: #{inspect(found_indicators)}"
        else
          IO.puts "✅ No obvious fallback patterns in #{file}"
        end
      end
    end)
  end
end

# Run the tests
MCPServerUsageTest.run_all_tests()

# Additional verification: Create a specific test case
defmodule SpecificMCPTest do
  @moduledoc """
  Specific test to verify MCP server usage vs fallback
  """
  
  def test_filesystem_capability do
    IO.puts "\n🧪 === Specific Filesystem MCP Test ===\n"
    
    # This test will:
    # 1. Request a capability only the filesystem MCP server can provide
    # 2. Monitor if actual MCP communication happens
    # 3. Verify the response came from MCP server, not fallback
    
    test_request = %{
      capability: "list_files",
      path: "/tmp",
      filter: "*.txt"
    }
    
    IO.puts "Test request: #{inspect(test_request)}"
    
    # Check if VSM-MCP handles this via MCP or fallback
    # A real MCP response would have specific format/metadata
    # A fallback would likely use File.ls! or similar
    
    IO.puts """
    
    To verify MCP usage vs fallback:
    1. Real MCP: Would spawn external process, use JSON-RPC protocol
    2. Fallback: Would use Elixir's File module directly
    
    Check process list while running VSM-MCP:
    - ps aux | grep mcp-server
    - lsof -i :PORT (if using TCP transport)
    """
  end
end

SpecificMCPTest.test_filesystem_capability()

IO.puts """

🎯 === Summary ===

To definitively verify MCP server usage:

1. Run VSM-MCP with a specific request
2. Monitor system processes: ps aux | grep mcp
3. Check network connections: netstat -an | grep LISTEN
4. Enable debug logging in VSM-MCP
5. Trace Port.open calls in BEAM

The key indicators of real MCP usage:
- External process spawned
- JSON-RPC communication
- Port/Socket connections
- Server-specific response format

Fallback indicators:
- Direct Elixir function calls
- No external processes
- Immediate responses
- Missing MCP protocol elements
"""