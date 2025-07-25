defmodule VsmMcp.Application do
  @moduledoc """
  Main OTP Application for VSM-MCP.
  
  Starts the supervision tree with all VSM systems and supporting components.
  """
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting VSM-MCP Application...")

    children = [
      # Core infrastructure
      {Registry, keys: :unique, name: VsmMcp.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: VsmMcp.DynamicSupervisor},
      
      # Resilience components (start early for all services)
      VsmMcp.Resilience.Supervisor,
      
      # Telemetry and monitoring
      VsmMcp.Telemetry,
      
      # MCP Server Manager (starts early for process management)
      VsmMcp.MCP.ServerManager.Supervisor,
      VsmMcp.MCP.ExternalServerSpawner,
      VsmMcp.MCP.JsonRpcClient,
      VsmMcp.MCP.CapabilityRouter,
      
      # VSM Systems (started in order)
      VsmMcp.Systems.System5,  # Policy must start first
      VsmMcp.Systems.System4,  # Intelligence
      VsmMcp.Systems.System3,  # Control
      VsmMcp.Systems.System2,  # Coordination
      VsmMcp.Systems.System1,  # Operations
      
      # Supporting components
      VsmMcp.ConsciousnessInterface,
      VsmMcp.Integration.CapabilityMatcher,
      VsmMcp.Core.MCPDiscovery,
      
      # LLM Integration for external variety
      {VsmMcp.LLM.Integration, provider: get_llm_provider()},
      
      # Daemon mode for autonomous operation
      maybe_daemon_mode(),
      
      # Web API server
      {Plug.Cowboy, scheme: :http, plug: VsmMcp.Web.Router, options: [port: 4000]},
      
      # Core components
      VsmMcp.Core.VarietyCalculator,
      
      # Integration components
      VsmMcp.Integration.ServerManager,
      VsmMcp.Integration.VarietyDetector,
      
      # Optional MCP server
      maybe_mcp_server()
    ]
    |> Enum.filter(& &1)

    opts = [strategy: :one_for_one, name: VsmMcp.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("VSM-MCP Application started successfully")
        {:ok, pid}
      error ->
        Logger.error("Failed to start VSM-MCP: #{inspect(error)}")
        error
    end
  end

  @impl true
  def stop(_state) do
    Logger.info("Stopping VSM-MCP Application...")
    :ok
  end

  defp maybe_daemon_mode do
    if Application.get_env(:vsm_mcp, :daemon_mode, true) do
      {VsmMcp.DaemonMode, 
       autonomous: Application.get_env(:vsm_mcp, :autonomous_mode, true),
       interval: Application.get_env(:vsm_mcp, :monitoring_interval, 30_000)}
    end
  end
  
  defp maybe_mcp_server do
    if Application.get_env(:vsm_mcp, :start_mcp_server, false) do
      {VsmMcp.MCP.Server, name: VsmMcp.MCP.Server}
    end
  end
  
  defp get_llm_provider do
    # Check for API keys in environment
    cond do
      System.get_env("ANTHROPIC_API_KEY") ->
        :anthropic
      System.get_env("OPENAI_API_KEY") ->
        :openai
      true ->
        # Default to local/mock for testing
        :local
    end
  end
end