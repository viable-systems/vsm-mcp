#!/usr/bin/env elixir

# Quick script to force capability refresh and execute task
Mix.install([{:jason, "~> 1.4"}, {:httpoison, "~> 2.0"}])

IO.puts """
╔════════════════════════════════════════════════════════════════╗
║          FORCING CAPABILITY REFRESH AND EXECUTION              ║
╚════════════════════════════════════════════════════════════════╝
"""

# Check if the API server is running
case HTTPoison.get("http://localhost:4000/health") do
  {:ok, %{status_code: 200}} ->
    IO.puts "✅ API server is running"
    
    # Force capability refresh by injecting a gap
    IO.puts "\n🔄 Forcing capability refresh..."
    HTTPoison.post(
      "http://localhost:4000/variety-gap",
      Jason.encode!(%{
        "type" => "capability_refresh",
        "severity" => "normal",
        "required_capabilities" => ["blockchain"]
      }),
      [{"Content-Type", "application/json"}]
    )
    
    Process.sleep(3000)
    
    # Check capabilities
    {:ok, caps_resp} = HTTPoison.get("http://localhost:4000/mcp/capabilities")
    case Jason.decode(caps_resp.body) do
      {:ok, %{"capabilities" => caps}} ->
        IO.puts "\n📋 Available capabilities:"
        Enum.each(caps, fn {cap, tools} ->
          IO.puts "  - #{cap}: #{length(tools)} tools"
        end)
      _ ->
        IO.puts "Failed to get capabilities"
    end
    
    # Now try to execute the task directly
    IO.puts "\n🎯 Attempting direct task execution..."
    
    # First, let's check if we can call the JsonRpcClient directly
    project_dir = Path.expand(".")
    Code.prepend_path(Path.join([project_dir, "_build", "dev", "lib", "vsm_mcp", "ebin"]))
    {:ok, _} = Application.ensure_all_started(:vsm_mcp)
    
    # Get blockchain server
    servers = VsmMcp.MCP.ExternalServerSpawner.list_running_servers()
    blockchain_server = Enum.find(servers, &String.contains?(&1.package, "blockchain"))
    
    if blockchain_server do
      IO.puts "✅ Found blockchain server: #{blockchain_server.id}"
      
      # Initialize and execute
      case VsmMcp.MCP.JsonRpcClient.initialize_server(blockchain_server.id) do
        {:ok, _} ->
          IO.puts "✅ JSON-RPC initialized"
          
          # Execute vanity address generation
          IO.puts "\n🎯 Generating vanity address..."
          result = VsmMcp.MCP.JsonRpcClient.call_tool(
            blockchain_server.id,
            "generateVanityAddress",
            %{
              "prefix" => "0xBEEF",
              "caseSensitive" => false
            },
            120_000
          )
          
          case result do
            {:ok, %{"address" => address} = full_result} ->
              IO.puts """
              
              🎉 SUCCESS! ACTUAL VANITY ADDRESS GENERATED!
              
              ╔════════════════════════════════════════════════════════╗
              ║                 REAL EXECUTION RESULT                  ║
              ╠════════════════════════════════════════════════════════╣
              ║ Address:  #{address}      ║
              ║ Private:  #{String.slice(full_result["privateKey"] || "", 0..20)}...   ║
              ║ Attempts: #{full_result["attempts"]}                              ║
              ╚════════════════════════════════════════════════════════╝
              
              THIS IS ACTUAL EXECUTION - NOT A MOCK!
              """
              
            {:error, reason} ->
              IO.puts "❌ Execution failed: #{inspect(reason)}"
          end
          
        {:error, reason} ->
          IO.puts "❌ Init failed: #{inspect(reason)}"
      end
    else
      IO.puts "❌ No blockchain server found"
    end
    
  _ ->
    IO.puts "❌ API server not running"
end