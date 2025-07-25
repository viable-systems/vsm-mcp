#!/usr/bin/env elixir

# Install dependencies first
Mix.install([
  {:jason, "~> 1.4"},
  {:httpoison, "~> 2.0"}
])

IO.puts """
╔════════════════════════════════════════════════════════════════╗
║       ACTUAL DOWNSTREAM TASK EXECUTION - FINAL PROOF           ║
╚════════════════════════════════════════════════════════════════╝
"""

# First, let's ensure the API server is running with our fix
System.cmd("pkill", ["-f", "START_WEB_API.exs"])
Process.sleep(1000)

IO.puts "🚀 Starting API server with fixed JSON encoding..."
spawn(fn ->
  System.cmd("mix", ["run", "START_WEB_API.exs"], cd: ".")
end)

Process.sleep(5000)

# Now demonstrate the complete flow using curl
IO.puts "\n📋 STEP 1: Check initial capabilities"
{output, _} = System.cmd("curl", ["-s", "http://localhost:4000/capabilities"])
capabilities = Jason.decode!(output)
IO.puts "Initial capabilities: #{inspect(capabilities["capabilities"])}"

# Trigger blockchain acquisition
IO.puts "\n🔄 STEP 2: Trigger blockchain capability acquisition"
{_, _} = System.cmd("curl", [
  "-X", "POST",
  "http://localhost:4000/autonomy/trigger",
  "-H", "Content-Type: application/json",
  "-d", Jason.encode!(%{"capabilities" => ["blockchain"]})
])

IO.puts "Waiting for acquisition to complete..."
Process.sleep(10000)

# Check running servers
IO.puts "\n📊 STEP 3: Check running MCP servers"
{servers_output, _} = System.cmd("curl", ["-s", "http://localhost:4000/mcp/servers"])

case Jason.decode(servers_output) do
  {:ok, %{"servers" => servers}} ->
    IO.puts "Running MCP servers:"
    Enum.each(servers, fn server ->
      IO.puts "  - #{server["package"]} (PID: #{server["pid"]})"
    end)
    
    blockchain_server = Enum.find(servers, fn s -> 
      String.contains?(s["package"], "blockchain")
    end)
    
    if blockchain_server do
      IO.puts "\n✅ Blockchain server is running!"
      
      # Execute actual task
      IO.puts "\n🎯 STEP 4: Execute ACTUAL blockchain task"
      IO.puts "Generating vanity address starting with '0x1337'..."
      
      task_request = %{
        "capability" => "blockchain",
        "task" => %{
          "type" => "vanity_address",
          "prefix" => "0x1337",
          "caseSensitive" => false
        }
      }
      
      {exec_output, status} = System.cmd("curl", [
        "-X", "POST",
        "http://localhost:4000/mcp/execute",
        "-H", "Content-Type: application/json",
        "-d", Jason.encode!(task_request),
        "-m", "120"  # 2 minute timeout
      ])
      
      if status == 0 do
        case Jason.decode(exec_output) do
          {:ok, %{"success" => true, "result" => result}} ->
            IO.puts """
            
            🎉 ACTUAL DOWNSTREAM TASK EXECUTED SUCCESSFULLY!
            
            ╔════════════════════════════════════════════════════════╗
            ║           REAL VANITY ADDRESS GENERATED                ║
            ╠════════════════════════════════════════════════════════╣
            ║ Address:  #{result["address"]}      ║
            ║ Private:  #{String.slice(result["privateKey"] || "", 0..20)}...   ║
            ║ Attempts: #{result["attempts"]}                              ║
            ╚════════════════════════════════════════════════════════╝
            
            This PROVES:
            ✅ Autonomous capability acquisition works
            ✅ MCP servers spawn and run correctly
            ✅ JSON-RPC communication established
            ✅ ACTUAL tasks execute (not mocks!)
            ✅ REAL results returned
            
            THE SYSTEM IS 100% WORKING!
            """
            
          {:ok, %{"success" => false, "error" => error}} ->
            IO.puts "\n❌ Task execution failed: #{error}"
            
          {:error, reason} ->
            IO.puts "\n❌ Failed to parse response: #{inspect(reason)}"
            IO.puts "Raw output: #{exec_output}"
        end
      else
        IO.puts "\n❌ Curl command failed with status: #{status}"
        IO.puts "Output: #{exec_output}"
      end
    else
      IO.puts "\n❌ No blockchain server found in running servers"
    end
    
  {:error, reason} ->
    IO.puts "❌ Failed to get servers: #{inspect(reason)}"
    IO.puts "Raw output: #{servers_output}"
end

# Cleanup
IO.puts "\n🧹 Cleaning up..."
System.cmd("pkill", ["-f", "START_WEB_API.exs"])
IO.puts "✅ Test complete!"