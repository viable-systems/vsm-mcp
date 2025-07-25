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
      IO.puts "✅ Discovery returned: #{inspect(servers)}"
    error ->
      IO.puts "❌ Discovery failed: #{inspect(error)}"
  end
  
  # Try to list installed servers
  case VsmMcp.Core.MCPDiscovery.list_installed_servers() do
    {:ok, installed} ->
      IO.puts "✅ Installed servers: #{inspect(installed)}"
    error ->
      IO.puts "❌ Failed to list servers: #{inspect(error)}"
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
      IO.puts "✅ Started MCP server: #{server_id}"
      
      # Check if process is actually running
      {:ok, status} = VsmMcp.MCP.ServerManager.get_status()
      IO.puts "Server status: #{inspect(status)}"
      
    error ->
      IO.puts "❌ Failed to start server: #{inspect(error)}"
  end
  
rescue
  e ->
    IO.puts "❌ Error: #{inspect(e)}"
    IO.puts Exception.format_stacktrace()
end
