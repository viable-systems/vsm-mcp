defmodule VsmMcp.Supervisors.CoreSupervisor do
  @moduledoc """
  Core Supervisor for the VSM-MCP system.
  
  Manages the supervision tree for all core components including:
  - VSM Systems (1-5)
  - MCP Server
  - Variety Calculator
  - Consciousness Interface
  - Event Bus integration
  - Pattern Engine integration
  """
  use Supervisor
  require Logger
  
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    children = [
      # Core infrastructure (start first)
      {Phoenix.PubSub, name: VsmMcp.PubSub},
      
      # Event Bus for inter-system communication
      event_bus_spec(opts),
      
      # Pattern Engine for System 3
      pattern_engine_spec(opts),
      
      # VSM Systems - Start in reverse order (System 5 first)
      {VsmMcp.Systems.System5, []},
      {VsmMcp.Systems.System4, []},
      {VsmMcp.Systems.System3, []},
      {VsmMcp.Systems.System2, []},
      {VsmMcp.Systems.System1, []},
      
      # Core components
      {VsmMcp.Core.VarietyCalculator, []},
      {VsmMcp.Core.MCPDiscovery, []},
      
      # Interfaces
      {VsmMcp.ConsciousnessInterface, []},
      {VsmMcp.Interfaces.MCPServer, transport: :stdio},
      
      # Optional integrations
      metrics_spec(opts),
      security_spec(opts),
      connections_spec(opts),
      vector_store_spec(opts)
    ]
    |> Enum.reject(&is_nil/1)
    
    Logger.info("Starting VSM-MCP Core Supervisor with #{length(children)} children")
    
    Supervisor.init(children, strategy: :one_for_one, max_restarts: 10, max_seconds: 60)
  end
  
  # Private helper functions for child specs
  
  defp event_bus_spec(opts) do
    if Code.ensure_loaded?(VsmEventBus.Application) do
      %{
        id: VsmEventBus,
        start: {VsmEventBus.Application, :start, [:normal, []]},
        type: :supervisor
      }
    else
      Logger.warning("VsmEventBus not available - skipping")
      nil
    end
  end
  
  defp pattern_engine_spec(opts) do
    if Code.ensure_loaded?(VsmPatternEngine.Application) do
      %{
        id: VsmPatternEngine,
        start: {VsmPatternEngine.Application, :start, [:normal, []]},
        type: :supervisor
      }
    else
      Logger.warning("VsmPatternEngine not available - skipping")
      nil
    end
  end
  
  defp metrics_spec(opts) do
    if opts[:enable_metrics] && Code.ensure_loaded?(VsmMetrics) do
      {VsmMetrics.Supervisor, []}
    else
      nil
    end
  end
  
  defp security_spec(opts) do
    if opts[:enable_security] && Code.ensure_loaded?(VsmSecurity) do
      {VsmSecurity.Supervisor, []}
    else
      nil
    end
  end
  
  defp connections_spec(opts) do
    if opts[:enable_connections] && Code.ensure_loaded?(VsmConnections) do
      {VsmConnections.Supervisor, []}
    else
      nil
    end
  end
  
  defp vector_store_spec(opts) do
    if opts[:enable_vector_store] && Code.ensure_loaded?(VsmVectorStore) do
      {VsmVectorStore.Supervisor, []}
    else
      nil
    end
  end
  
  @doc """
  Get the status of all supervised children.
  """
  def status do
    children = Supervisor.which_children(__MODULE__)
    
    Enum.map(children, fn {id, pid, type, modules} ->
      %{
        id: id,
        pid: pid,
        alive: is_pid(pid) and Process.alive?(pid),
        type: type,
        modules: modules
      }
    end)
  end
  
  @doc """
  Restart a specific child by ID.
  """
  def restart_child(child_id) do
    case Supervisor.terminate_child(__MODULE__, child_id) do
      :ok ->
        Supervisor.restart_child(__MODULE__, child_id)
      error ->
        error
    end
  end
  
  @doc """
  Dynamically add a new child to the supervision tree.
  """
  def add_child(child_spec) do
    Supervisor.start_child(__MODULE__, child_spec)
  end
  
  @doc """
  Remove a child from the supervision tree.
  """
  def remove_child(child_id) do
    Supervisor.terminate_child(__MODULE__, child_id)
    Supervisor.delete_child(__MODULE__, child_id)
  end
end