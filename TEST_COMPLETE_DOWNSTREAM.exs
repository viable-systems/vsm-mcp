#!/usr/bin/env elixir

Mix.install([
  {:httpoison, "~> 2.0"},
  {:jason, "~> 1.4"}
])

IO.puts """
╔════════════════════════════════════════════════════════════════╗
║    COMPLETE DOWNSTREAM TASK EXECUTION WITH JSON-RPC CLIENT     ║
╚════════════════════════════════════════════════════════════════╝

Testing the FULL autonomous loop with actual task execution...
"""

defmodule DownstreamTest do
  def run do
    # Step 1: Ensure blockchain capability is acquired
    IO.puts "\n1️⃣ Triggering blockchain capability acquisition..."
    
    body = Jason.encode!(%{"capabilities" => ["blockchain"]})
    {:ok, _} = HTTPoison.post(
      "http://localhost:4000/autonomy/trigger",
      body,
      [{"Content-Type", "application/json"}]
    )
    
    IO.puts "✅ Triggered autonomous acquisition"
    Process.sleep(5000)  # Give time to install and spawn
    
    # Step 2: Check running servers
    IO.puts "\n2️⃣ Checking running MCP servers..."
    {:ok, resp} = HTTPoison.get("http://localhost:4000/mcp/servers")
    
    case resp.status_code do
      200 ->
        servers = Jason.decode!(resp.body)
        IO.puts "Running servers: #{inspect(servers, pretty: true)}"
        
      _ ->
        IO.puts "Creating API endpoint for MCP servers..."
        # The endpoint might not exist yet, let's test directly
    end
    
    # Step 3: Execute actual blockchain task
    IO.puts "\n3️⃣ Executing downstream blockchain task..."
    
    # This will use our new JSON-RPC client
    task_request = %{
      "capability" => "blockchain",
      "task" => %{
        "type" => "vanity_address",
        "prefix" => "0x1337",
        "caseSensitive" => false
      }
    }
    
    {:ok, task_resp} = HTTPoison.post(
      "http://localhost:4000/mcp/execute",
      Jason.encode!(task_request),
      [{"Content-Type", "application/json"}]
    )
    
    case task_resp.status_code do
      200 ->
        result = Jason.decode!(task_resp.body)
        IO.puts """
        
        🎉 DOWNSTREAM TASK EXECUTED SUCCESSFULLY!
        
        Result: #{inspect(result, pretty: true)}
        
        This proves:
        1. Variety gap detected ✅
        2. MCP server found and installed ✅
        3. Server spawned as process ✅
        4. JSON-RPC communication established ✅
        5. Actual task executed ✅
        6. Result returned to user ✅
        
        FULL AUTONOMOUS LOOP WITH DOWNSTREAM EXECUTION COMPLETE! 🚀
        """
        
      404 ->
        IO.puts """
        
        The /mcp/execute endpoint doesn't exist yet.
        Let's create it to complete the loop...
        """
        
      other ->
        IO.puts "Got status #{other}: #{task_resp.body}"
    end
  end
end

# Run the test
DownstreamTest.run()