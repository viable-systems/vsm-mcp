#!/usr/bin/env elixir

# Simple HTTP API to trigger autonomous MCP acquisition
# This uses the running VSM-MCP application

defmodule FinalAutonomousAPI do
  @moduledoc """
  Simple HTTP API for triggering VSM-MCP autonomous capability acquisition.
  
  Endpoints:
  - GET  /health - System health check
  - POST /trigger - Trigger autonomous MCP acquisition
  """
  
  def start(port \\ 4001) do
    IO.puts """
    ╔═══════════════════════════════════════════════════════════╗
    ║       AUTONOMOUS MCP API - PORT #{port}                     ║
    ╚═══════════════════════════════════════════════════════════╝
    
    Starting VSM-MCP application...
    """
    
    # Start the VSM-MCP application
    case Application.ensure_all_started(:vsm_mcp) do
      {:ok, apps} ->
        IO.puts "✅ Started #{length(apps)} applications"
      {:error, {app, reason}} ->
        IO.puts "❌ Failed to start #{app}: #{inspect(reason)}"
        System.halt(1)
    end
    
    # Wait for initialization
    Process.sleep(2000)
    
    IO.puts """
    
    🚀 SYSTEM READY FOR AUTONOMOUS OPERATION!
    
    USAGE:
    
    # Check health
    curl http://localhost:#{port}/health
    
    # TRIGGER AUTONOMOUS MCP ACQUISITION
    curl -X POST http://localhost:#{port}/trigger \\
      -H "Content-Type: application/json" \\
      -d '{"capabilities": ["database", "filesystem", "api"]}'
    
    The system will AUTONOMOUSLY:
    1. Detect variety gap
    2. Search NPM for MCP servers  
    3. Install them
    4. Integrate capabilities
    
    Watch the console for real-time progress!
    """
    
    # Start HTTP server
    routes = [
      {"/health", :get, &handle_health/1},
      {"/trigger", :post, &handle_trigger/1}
    ]
    
    {:ok, _} = :cowboy.start_clear(
      :http,
      [{:port, port}],
      %{env: %{dispatch: compile_routes(routes)}}
    )
    
    # Keep running
    receive do
      :stop -> :ok
    end
  end
  
  defp compile_routes(routes) do
    :cowboy_router.compile([
      {:_, Enum.map(routes, fn {path, method, handler} ->
        {path, FinalAutonomousAPI.Handler, {method, handler}}
      end)}
    ])
  end
  
  defp handle_health(_req) do
    status = %{
      alive: true,
      daemon: Process.whereis(VsmMcp.DaemonMode) != nil,
      capabilities: get_capabilities()
    }
    
    {:ok, Jason.encode!(status), "application/json"}
  end
  
  defp handle_trigger(req) do
    {:ok, body, _} = :cowboy_req.read_body(req)
    params = Jason.decode!(body)
    capabilities = params["capabilities"] || ["database"]
    
    IO.puts "\n🚀 TRIGGERING AUTONOMOUS ACQUISITION"
    IO.puts "📋 Requested: #{inspect(capabilities)}"
    
    # Inject variety gap
    gap = %{
      type: :capability_gap,
      severity: :critical,
      required_capabilities: capabilities,
      source: "http_api",
      timestamp: DateTime.utc_now()
    }
    
    :ok = VsmMcp.Integration.VarietyDetector.inject_variety_gap(gap)
    
    # Trigger daemon
    if pid = Process.whereis(VsmMcp.DaemonMode) do
      send(pid, :check_variety)
      IO.puts "✅ Daemon triggered"
    end
    
    # Monitor async
    Task.start(fn -> monitor_progress(30) end)
    
    response = %{
      triggered: true,
      gap: gap,
      message: "Autonomous acquisition initiated"
    }
    
    {:ok, Jason.encode!(response), "application/json"}
  end
  
  defp get_capabilities do
    try do
      VsmMcp.Integration.CapabilityMatcher.get_all_capabilities()
    rescue
      _ -> ["core", "base", "vsm_integration"]
    end
  end
  
  defp monitor_progress(seconds) do
    IO.puts "\n📊 MONITORING AUTONOMOUS PROGRESS..."
    
    Enum.each(1..seconds, fn i ->
      Process.sleep(1000)
      
      caps = get_capabilities()
      new_caps = caps -- ["core", "base", "vsm_integration"]
      
      if length(new_caps) > 0 do
        IO.puts "#{i}s: ✅ NEW CAPABILITIES: #{inspect(new_caps)}"
      else
        IO.puts "#{i}s: Monitoring... (#{length(caps)} capabilities)"
      end
    end)
    
    IO.puts "📊 Monitoring complete\n"
  end
end

defmodule FinalAutonomousAPI.Handler do
  def init(req, {method, handler}) do
    if :cowboy_req.method(req) == method_to_binary(method) do
      case handler.(req) do
        {:ok, body, content_type} ->
          req = :cowboy_req.reply(200, %{"content-type" => content_type}, body, req)
          {:ok, req, nil}
        {:error, reason} ->
          req = :cowboy_req.reply(500, %{}, "Error: #{inspect(reason)}", req)
          {:ok, req, nil}
      end
    else
      req = :cowboy_req.reply(405, %{}, "Method not allowed", req)
      {:ok, req, nil}
    end
  end
  
  defp method_to_binary(:get), do: "GET"
  defp method_to_binary(:post), do: "POST"
end

# Dependencies check
deps = [:cowboy, :jason]
missing = Enum.filter(deps, fn dep ->
  case Application.load(dep) do
    :ok -> false
    {:error, _} -> true
  end
end)

if length(missing) > 0 do
  IO.puts "Missing dependencies: #{inspect(missing)}"
  IO.puts "Run: mix deps.get"
  System.halt(1)
end

# Start the API
FinalAutonomousAPI.start(4001)