#!/usr/bin/env elixir

# Start dependencies
Application.ensure_all_started(:httpoison)
Application.ensure_all_started(:plug)
Application.ensure_all_started(:plug_cowboy)

defmodule SimpleAPI do
  use Plug.Router
  
  plug :match
  plug Plug.Parsers, 
    parsers: [:json],
    json_decoder: Jason
  plug :dispatch
  
  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "alive", message: "VSM-MCP API Ready"}))
  end
  
  post "/trigger-autonomy" do
    capabilities = conn.body_params["capabilities"] || ["filesystem"]
    
    response = %{
      message: "Triggering autonomous MCP acquisition",
      capabilities_needed: capabilities
    }
    
    # Actually search NPM
    Task.start(fn ->
      IO.puts "\n🤖 AUTONOMOUS SYSTEM ACTIVATED"
      IO.puts "📡 Searching NPM for: #{inspect(capabilities)}"
      
      Enum.each(capabilities, fn cap ->
        url = "https://registry.npmjs.org/-/v1/search?text=mcp-server-#{cap}&size=3"
        
        case HTTPoison.get(url, [], recv_timeout: 10_000) do
          {:ok, %{status_code: 200, body: body}} ->
            case Jason.decode(body) do
              {:ok, data} ->
                IO.puts "\n✅ Found #{data["total"]} packages for '#{cap}'"
                
                if data["total"] > 0 do
                  pkg = List.first(data["objects"])["package"]
                  IO.puts "   Best match: #{pkg["name"]} v#{pkg["version"]}"
                  
                  # REAL INSTALLATION
                  install_dir = "/tmp/vsm_autonomy_#{:rand.uniform(1000)}"
                  File.mkdir_p!(install_dir)
                  
                  IO.puts "   📥 Installing..."
                  case System.cmd("npm", ["install", pkg["name"], "--prefix", install_dir], stderr_to_stdout: true) do
                    {_, 0} ->
                      IO.puts "   ✅ INSTALLED AT: #{install_dir}"
                    {error, _} ->
                      IO.puts "   ❌ Install failed: #{String.slice(error, 0..100)}"
                  end
                end
              _ -> IO.puts "❌ JSON decode failed"
            end
          error ->
            IO.puts "❌ NPM search failed: #{inspect(error)}"
        end
      end)
    end)
    
    send_resp(conn, 200, Jason.encode!(response))
  end
  
  match _ do
    send_resp(conn, 404, "Not found")
  end
end

# Start the server
IO.puts """
╔═══════════════════════════════════════════════════════════╗
║       REAL AUTONOMOUS MCP API - PORT 4000                  ║
╚═══════════════════════════════════════════════════════════╝

ENDPOINTS:

GET  /health
POST /trigger-autonomy

EXAMPLE:

curl -X POST http://localhost:4000/trigger-autonomy \\
  -H "Content-Type: application/json" \\
  -d '{"capabilities": ["filesystem", "database"]}'

Watch the console for REAL autonomous NPM operations!
"""

{:ok, _} = Plug.Cowboy.http(SimpleAPI, [], port: 4000)

# Keep running
Process.sleep(:infinity)