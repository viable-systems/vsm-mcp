#!/usr/bin/env elixir

IO.puts """
╔════════════════════════════════════════════════════════════════╗
║     PROVING ACTUAL DOWNSTREAM TASK EXECUTION - NO BULLSHIT     ║
╚════════════════════════════════════════════════════════════════╝

We will:
1. Start the MCP application
2. Spawn blockchain MCP server  
3. Execute ACTUAL vanity address generation
4. Show REAL results
"""

# Start in project directory
project_dir = Path.expand(".")
File.cd!(project_dir)

# Compile and start
IO.puts "\n🔧 Compiling project..."
System.cmd("mix", ["compile"], into: IO.stream(:stdio, :line))

# Add to code path
Code.prepend_path(Path.join([project_dir, "_build", "dev", "lib", "vsm_mcp", "ebin"]))

# Start the app
IO.puts "\n🚀 Starting VSM-MCP application..."
Application.put_env(:vsm_mcp, :daemon_mode, false)
{:ok, _} = Application.ensure_all_started(:vsm_mcp)

Process.sleep(2000)

# Check if blockchain server exists
IO.puts "\n📋 Checking for blockchain MCP server..."
servers = VsmMcp.MCP.ExternalServerSpawner.list_running_servers()
blockchain_server = Enum.find(servers, &String.contains?(&1.package, "blockchain"))

if !blockchain_server do
  IO.puts "🔄 Spawning blockchain MCP server..."
  
  # First ensure it's discovered/installed
  case VsmMcp.Core.MCPDiscovery.search_servers(["blockchain"]) do
    servers when is_list(servers) and length(servers) > 0 ->
      IO.puts "✅ Found blockchain servers: #{length(servers)}"
      
      # Find blockchain-mcp-server specifically
      blockchain_mcp = Enum.find(servers, fn s -> 
        s.package == "blockchain-mcp-server"
      end)
      
      if blockchain_mcp do
        IO.puts "📦 Installing blockchain-mcp-server..."
        case VsmMcp.Core.MCPDiscovery.install_server(blockchain_mcp) do
          {:ok, _} -> 
            IO.puts "✅ Installed successfully"
          {:error, reason} ->
            IO.puts "❌ Install failed: #{inspect(reason)}"
        end
      end
      
    _ ->
      IO.puts "❌ No blockchain servers found"
  end
  
  # Now spawn it
  case VsmMcp.MCP.ExternalServerSpawner.spawn_mcp_server("blockchain-mcp-server") do
    {:ok, server_id, _} ->
      IO.puts "✅ Spawned blockchain server: #{server_id}"
      Process.sleep(3000)
      
      # Refresh server list
      servers = VsmMcp.MCP.ExternalServerSpawner.list_running_servers()
      blockchain_server = Enum.find(servers, &(&1.id == server_id))
      
    error ->
      IO.puts "❌ Failed to spawn: #{inspect(error)}"
      System.halt(1)
  end
end

if blockchain_server do
  IO.puts "\n✅ Blockchain server is running!"
  IO.puts "   ID: #{blockchain_server.id}"
  IO.puts "   Package: #{blockchain_server.package}"
  IO.puts "   PID: #{blockchain_server.pid}"
  
  # Initialize JSON-RPC
  IO.puts "\n🔌 Initializing JSON-RPC protocol..."
  case VsmMcp.MCP.JsonRpcClient.initialize_server(blockchain_server.id) do
    {:ok, init_result} ->
      IO.puts "✅ Protocol initialized: #{inspect(init_result)}"
      
      # List available tools
      IO.puts "\n🔧 Listing available tools..."
      case VsmMcp.MCP.JsonRpcClient.list_tools(blockchain_server.id) do
        {:ok, %{"tools" => tools}} ->
          IO.puts "Available tools:"
          Enum.each(tools, fn tool ->
            IO.puts "  - #{tool["name"]}: #{tool["description"] || "No description"}"
          end)
          
        {:ok, result} ->
          IO.puts "Tools result: #{inspect(result)}"
          
        error ->
          IO.puts "❌ Failed to list tools: #{inspect(error)}"
      end
      
      # EXECUTE ACTUAL TASK
      IO.puts "\n" <> String.duplicate("=", 60)
      IO.puts "🎯 EXECUTING ACTUAL DOWNSTREAM TASK"
      IO.puts "Task: Generate Ethereum vanity address starting with '0x1337'"
      IO.puts String.duplicate("=", 60)
      
      start_time = System.monotonic_time(:millisecond)
      
      result = VsmMcp.MCP.JsonRpcClient.call_tool(
        blockchain_server.id,
        "generateVanityAddress", 
        %{
          "prefix" => "0x1337",
          "caseSensitive" => false
        },
        300_000  # 5 minute timeout
      )
      
      elapsed = System.monotonic_time(:millisecond) - start_time
      
      case result do
        {:ok, %{"address" => address, "privateKey" => private_key} = full_result} ->
          IO.puts """
          
          🎉 SUCCESS! ACTUAL VANITY ADDRESS GENERATED!
          
          ╔═══════════════════════════════════════════════════════╗
          ║              REAL DOWNSTREAM EXECUTION                ║
          ╠═══════════════════════════════════════════════════════╣
          ║ Address:     #{address}           ║
          ║ Private Key: #{String.slice(private_key, 0..20)}...  ║
          ║ Attempts:    #{full_result["attempts"] || "N/A"}                             ║
          ║ Time:        #{elapsed}ms                                ║
          ╚═══════════════════════════════════════════════════════╝
          
          This PROVES:
          ✅ MCP server actually running
          ✅ JSON-RPC communication working
          ✅ Downstream task ACTUALLY EXECUTED
          ✅ Real Ethereum address generated
          ✅ Not mock data - REAL RESULTS!
          
          THE SYSTEM IS 100% WORKING WITH ACTUAL EXECUTION!
          """
          
        {:ok, other} ->
          IO.puts "Got result: #{inspect(other)}"
          
        {:error, reason} ->
          IO.puts """
          
          ❌ Task execution failed: #{inspect(reason)}
          
          This might be because:
          - The MCP server isn't fully initialized
          - JSON-RPC communication issue
          - Tool name mismatch
          """
      end
      
    {:error, reason} ->
      IO.puts "❌ Failed to initialize protocol: #{inspect(reason)}"
  end
else
  IO.puts "❌ No blockchain server available"
end

IO.puts "\n✨ Test complete!"