#!/usr/bin/env elixir

# Move to project directory
File.cd!("/home/batmanosama/viable-systems/vsm-mcp")

# Start Mix
Mix.start()
Mix.shell(Mix.Shell.Process)

# Load dependencies
Mix.Task.run("deps.get")
Mix.Task.run("compile")

# Disable the web server in config to avoid port conflict
Application.put_env(:vsm_mcp, :web_server_port, 4001)

# Start dependencies
Application.ensure_all_started(:httpoison)
Application.ensure_all_started(:plug)
Application.ensure_all_started(:plug_cowboy)
Application.ensure_all_started(:jason)

# Create a simple API router
defmodule AutonomousAPI do
  use Plug.Router
  require Logger
  
  plug Plug.Logger
  plug :match
  plug Plug.Parsers, 
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  plug :dispatch
  
  # Health check
  get "/health" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{
      status: "alive",
      message: "VSM-MCP Autonomous API Ready",
      capabilities: get_capabilities()
    }))
  end
  
  # Trigger autonomous acquisition
  post "/trigger" do
    capabilities = conn.body_params["capabilities"] || ["database"]
    
    Logger.info("🚀 TRIGGERING AUTONOMOUS ACQUISITION FOR: #{inspect(capabilities)}")
    
    # Create variety gap
    gap = %{
      type: :capability_gap,
      severity: :critical,
      required_capabilities: capabilities,
      source: "http_api",
      timestamp: DateTime.utc_now()
    }
    
    # Start the VSM-MCP application if not running
    case Application.ensure_all_started(:vsm_mcp) do
      {:ok, _} -> 
        Logger.info("✅ VSM-MCP Application started")
      {:error, {:vsm_mcp, {:bad_return, error}}} ->
        Logger.error("❌ VSM-MCP failed to start: #{inspect(error)}")
      error ->
        Logger.error("❌ Application start error: #{inspect(error)}")
    end
    
    # Inject variety gap
    try do
      :ok = VsmMcp.Integration.VarietyDetector.inject_variety_gap(gap)
      Logger.info("✅ Variety gap injected")
      
      # Trigger daemon check
      case Process.whereis(VsmMcp.DaemonMode) do
        nil -> 
          Logger.warn("⚠️ DaemonMode not running")
        pid ->
          send(pid, :check_variety)
          Logger.info("✅ Daemon check triggered")
      end
    rescue
      e ->
        Logger.error("❌ Error injecting gap: #{inspect(e)}")
    end
    
    # Start async monitoring
    Task.start(fn ->
      monitor_autonomous_action(capabilities)
    end)
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{
      triggered: true,
      gap_injected: gap,
      message: "Autonomous acquisition initiated. Check console for progress."
    }))
  end
  
  # List current capabilities
  get "/capabilities" do
    caps = get_capabilities()
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{capabilities: caps}))
  end
  
  # Daemon status
  get "/daemon" do
    status = case Process.whereis(VsmMcp.DaemonMode) do
      nil -> %{running: false}
      _pid -> 
        try do
          VsmMcp.DaemonMode.get_status()
        rescue
          _ -> %{running: true, status: "unknown"}
        end
    end
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(status))
  end
  
  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "Not found"}))
  end
  
  defp get_capabilities do
    try do
      VsmMcp.Integration.CapabilityMatcher.get_all_capabilities()
    rescue
      _ -> ["core", "base", "vsm_integration"]
    end
  end
  
  defp monitor_autonomous_action(capabilities) do
    Logger.info("\n📊 MONITORING AUTONOMOUS ACTION...")
    
    # Watch for 30 seconds
    Enum.each(1..6, fn i ->
      Process.sleep(5000)
      
      # Check current capabilities
      current = get_capabilities()
      Logger.info("   #{i*5}s: Current capabilities: #{inspect(current)}")
      
      # Check if new capabilities were acquired
      new_caps = current -- ["core", "base", "vsm_integration"]
      if length(new_caps) > 0 do
        Logger.info("   ✅ NEW CAPABILITIES ACQUIRED: #{inspect(new_caps)}")
      end
      
      # Check daemon status
      case Process.whereis(VsmMcp.DaemonMode) do
        nil -> :ok
        pid ->
          status = try do
            VsmMcp.DaemonMode.get_status()
          rescue
            _ -> %{state: "unknown"}
          end
          Logger.info("   Daemon state: #{inspect(status.state)}")
      end
    end)
    
    Logger.info("📊 Monitoring complete\n")
  end
end

# Start the API server on port 4001
port = 4001

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║      VSM-MCP AUTONOMOUS API - PORT #{port}                 ║
╚═══════════════════════════════════════════════════════════╝

🚀 REAL AUTONOMOUS SYSTEM - NO MOCKS!

ENDPOINTS:

GET  /health        - System health & capabilities
GET  /capabilities  - Current system capabilities  
GET  /daemon        - Daemon monitoring status
POST /trigger       - TRIGGER AUTONOMOUS ACQUISITION

EXAMPLE COMMANDS:

# Check system health
curl http://localhost:#{port}/health

# See current capabilities  
curl http://localhost:#{port}/capabilities

# 🔥 TRIGGER AUTONOMOUS MCP ACQUISITION!
curl -X POST http://localhost:#{port}/trigger \\
  -H "Content-Type: application/json" \\
  -d '{"capabilities": ["database", "filesystem", "api"]}'

The system will AUTONOMOUSLY:
1. Detect the variety gap
2. Search NPM for MCP servers
3. Install them via npm
4. Integrate capabilities
5. Update system variety

Watch the console for real-time autonomous operations!
"""

# Start server
{:ok, _} = Plug.Cowboy.http(AutonomousAPI, [], port: port)

# Keep running
Process.sleep(:infinity)