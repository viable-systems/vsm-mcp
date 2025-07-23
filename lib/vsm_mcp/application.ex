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
      
      # Telemetry and monitoring
      VsmMcp.Telemetry,
      
      # VSM Systems (started in order)
      VsmMcp.Systems.System5,  # Policy must start first
      VsmMcp.Systems.System4,  # Intelligence
      VsmMcp.Systems.System3,  # Control
      VsmMcp.Systems.System2,  # Coordination
      VsmMcp.Systems.System1,  # Operations
      
      # Supporting components
      VsmMcp.Variety.Analyst,
      VsmMcp.Consciousness.Interface,
      VsmMcp.Integration.Supervisor,
      
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

  defp maybe_mcp_server do
    if Application.get_env(:vsm_mcp, :start_mcp_server, false) do
      {VsmMcp.MCP.Server, name: VsmMcp.MCP.Server}
    end
  end
end