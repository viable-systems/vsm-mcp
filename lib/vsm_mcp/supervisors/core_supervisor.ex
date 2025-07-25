defmodule VsmMcp.Supervisors.CoreSupervisor do
  @moduledoc """
  Core supervisor that manages all VSM components.
  """
  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Starting Core Supervisor with options: #{inspect(opts)}")

    children = [
      # Telemetry and monitoring
      VsmMcp.Telemetry,
      
      # Core VSM Systems (must start in order)
      {VsmMcp.Systems.System5, name: VsmMcp.Systems.System5},
      {VsmMcp.Systems.System4, name: VsmMcp.Systems.System4},
      {VsmMcp.Systems.System3, name: VsmMcp.Systems.System3},
      {VsmMcp.Systems.System2, name: VsmMcp.Systems.System2},
      {VsmMcp.Systems.System1, name: VsmMcp.Systems.System1},
      
      # Variety management
      {VsmMcp.Core.VarietyCalculator, name: VsmMcp.Core.VarietyCalculator},
      
      # Consciousness interface
      {VsmMcp.ConsciousnessInterface, name: VsmMcp.ConsciousnessInterface},
      
      # MCP Discovery
      {VsmMcp.Core.MCPDiscovery, name: VsmMcp.Core.MCPDiscovery},
      
      # Optional components
      maybe_event_bus(opts),
      maybe_pattern_engine(opts),
      maybe_mcp_server(opts)
    ]
    |> Enum.filter(& &1)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp maybe_event_bus(opts) do
    if Keyword.get(opts, :enable_event_bus, true) do
      event_bus_spec(opts)
    end
  end

  defp maybe_pattern_engine(opts) do
    if Keyword.get(opts, :enable_pattern_engine, true) do
      pattern_engine_spec(opts)
    end
  end

  defp maybe_mcp_server(opts) do
    if Keyword.get(opts, :start_mcp_server, false) do
      {VsmMcp.Interfaces.MCPServer, []}
    end
  end

  defp event_bus_spec(_opts) do
    {Phoenix.PubSub, name: VsmMcp.PubSub}
  end

  defp pattern_engine_spec(_opts) do
    nil  # Pattern engine spec would go here if available
  end
end