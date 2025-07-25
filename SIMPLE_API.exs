#!/usr/bin/env elixir

# Simple standalone API server for triggering autonomous MCP acquisition
# This runs independently without needing the full VSM-MCP application

# Start dependencies
Application.ensure_all_started(:httpoison)
Application.ensure_all_started(:plug)
Application.ensure_all_started(:plug_cowboy)
Application.ensure_all_started(:jason)

defmodule SimpleAutonomousAPI do
  use Plug.Router
  
  plug Plug.Logger
  plug :match
  plug Plug.Parsers, 
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  plug :dispatch
  
  # Health check
  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{
      status: "alive", 
      message: "Simple Autonomous API Ready",
      note: "POST to /trigger to start autonomous MCP acquisition"
    }))
  end
  
  # Trigger autonomous MCP acquisition
  post "/trigger" do
    capabilities = conn.body_params["capabilities"] || ["filesystem"]
    
    IO.puts "\n🤖 AUTONOMOUS MCP ACQUISITION TRIGGERED"
    IO.puts "📋 Requested capabilities: #{inspect(capabilities)}"
    
    # Start async task to perform the acquisition
    Task.start(fn ->
      perform_autonomous_acquisition(capabilities)
    end)
    
    send_resp(conn, 200, Jason.encode!(%{
      triggered: true,
      capabilities: capabilities,
      message: "Autonomous acquisition started. Check console for progress."
    }))
  end
  
  # Default 404
  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
  end
  
  defp perform_autonomous_acquisition(capabilities) do
    IO.puts "\n⚡ STARTING AUTONOMOUS ACQUISITION PROCESS..."
    
    Enum.each(capabilities, fn capability ->
      IO.puts "\n🔍 Processing capability: #{capability}"
      
      # Step 1: Search NPM for MCP servers
      search_term = "mcp-server-#{capability}"
      url = "https://registry.npmjs.org/-/v1/search?text=#{search_term}&size=5"
      
      IO.puts "   📡 Searching NPM for: #{search_term}"
      
      case HTTPoison.get(url, [], recv_timeout: 15_000) do
        {:ok, %{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"total" => total, "objects" => objects}} when total > 0 ->
              IO.puts "   ✅ Found #{total} packages!"
              
              # Get the best match
              best_match = List.first(objects)["package"]
              package_name = best_match["name"]
              version = best_match["version"]
              
              IO.puts "   📦 Best match: #{package_name} v#{version}"
              IO.puts "   📄 Description: #{best_match["description"]}"
              
              # Step 2: Install the package
              install_dir = "/tmp/vsm_autonomous_#{:rand.uniform(10000)}"
              File.mkdir_p!(install_dir)
              
              IO.puts "   📥 Installing to: #{install_dir}"
              
              case System.cmd("npm", ["install", package_name, "--prefix", install_dir], 
                             stderr_to_stdout: true, cd: install_dir) do
                {output, 0} ->
                  IO.puts "   ✅ SUCCESSFULLY INSTALLED!"
                  
                  # List installed files
                  {files, _} = System.cmd("find", [install_dir, "-name", "*.js", "-type", "f"], 
                                         stderr_to_stdout: true)
                  js_files = String.split(files, "\n") |> Enum.filter(&(&1 != ""))
                  
                  IO.puts "   📁 Installed #{length(js_files)} JavaScript files"
                  
                  # Check if it's an MCP server
                  package_json_path = Path.join([install_dir, "node_modules", package_name, "package.json"])
                  if File.exists?(package_json_path) do
                    {:ok, pkg_content} = File.read(package_json_path)
                    {:ok, pkg_data} = Jason.decode(pkg_content)
                    
                    if pkg_data["bin"] || String.contains?(pkg_content, "mcp") do
                      IO.puts "   🎯 This appears to be an MCP server!"
                      IO.puts "   🚀 Ready for integration into VSM-MCP system"
                    end
                  end
                  
                {output, code} ->
                  IO.puts "   ❌ Installation failed (code: #{code})"
                  IO.puts "   Error: #{String.slice(output, 0..200)}..."
              end
              
            {:ok, %{"total" => 0}} ->
              IO.puts "   ⚠️ No packages found for '#{capability}'"
              
              # Try alternative search
              alt_search = "#{capability} server"
              IO.puts "   🔄 Trying alternative search: #{alt_search}"
              search_alternative(alt_search)
              
            {:error, reason} ->
              IO.puts "   ❌ JSON decode error: #{inspect(reason)}"
          end
          
        {:ok, %{status_code: code}} ->
          IO.puts "   ❌ NPM returned status: #{code}"
          
        {:error, reason} ->
          IO.puts "   ❌ HTTP request failed: #{inspect(reason)}"
      end
    end)
    
    IO.puts "\n✅ AUTONOMOUS ACQUISITION PROCESS COMPLETE"
    IO.puts "💡 Tip: Check /tmp/vsm_autonomous_* directories for installed packages\n"
  end
  
  defp search_alternative(search_term) do
    url = "https://registry.npmjs.org/-/v1/search?text=#{URI.encode(search_term)}&size=3"
    
    case HTTPoison.get(url, [], recv_timeout: 10_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"total" => total}} when total > 0 ->
            IO.puts "   ✅ Found #{total} alternative packages"
          _ ->
            IO.puts "   ⚠️ No alternatives found"
        end
      _ ->
        IO.puts "   ❌ Alternative search failed"
    end
  end
end

# Start the server
port = 4001

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║        SIMPLE AUTONOMOUS MCP API - PORT #{port}             ║
╚═══════════════════════════════════════════════════════════╝

🚀 REAL AUTONOMOUS NPM PACKAGE INSTALLATION

This API will:
1. Search NPM for MCP servers
2. Install them automatically  
3. Report installation results

ENDPOINTS:

GET  /health   - Check API status
POST /trigger  - Trigger autonomous acquisition

EXAMPLE:

curl -X POST http://localhost:#{port}/trigger \\
  -H "Content-Type: application/json" \\
  -d '{"capabilities": ["filesystem", "database", "git"]}'

Watch the console for real-time progress!
"""

# Start server
{:ok, _} = Plug.Cowboy.http(SimpleAutonomousAPI, [], port: port)

# Keep running
Process.sleep(:infinity)