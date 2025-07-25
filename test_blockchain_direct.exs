#!/usr/bin/env elixir

# Test direct communication with blockchain server

require Logger

# Find the blockchain server
servers = VsmMcp.MCP.ExternalServerSpawner.list_running_servers()
blockchain_server = Enum.find(servers, fn s -> s.package == "blockchain-mcp-server" end)

if blockchain_server do
  Logger.info("Found blockchain server: #{inspect(blockchain_server)}")
  server_id = blockchain_server.id
  
  # Initialize the server
  case VsmMcp.MCP.JsonRpcClient.initialize_server(server_id) do
    {:ok, result} ->
      Logger.info("Initialized: #{inspect(result)}")
      
      # List tools
      case VsmMcp.MCP.JsonRpcClient.list_tools(server_id) do
        {:ok, tools} ->
          Logger.info("Available tools: #{inspect(tools)}")
          
          # Try to generate vanity address
          Logger.info("Generating vanity address with prefix '0xC0DE'...")
          case VsmMcp.MCP.JsonRpcClient.call_tool(server_id, "generateVanityAddress", %{
            "prefix" => "0xC0DE",
            "caseSensitive" => false
          }, 120_000) do
            {:ok, result} ->
              Logger.info("SUCCESS! Generated vanity address: #{inspect(result)}")
              IO.puts("\n🎉 BLOCKCHAIN TASK EXECUTED SUCCESSFULLY!")
              IO.puts("Generated address: #{result["address"]}")
              IO.puts("Private key: #{result["privateKey"]}")
            {:error, reason} ->
              Logger.error("Failed to generate vanity address: #{inspect(reason)}")
          end
        {:error, reason} ->
          Logger.error("Failed to list tools: #{inspect(reason)}")
      end
    {:error, reason} ->
      Logger.error("Failed to initialize: #{inspect(reason)}")
  end
else
  Logger.error("No blockchain server found!")
end