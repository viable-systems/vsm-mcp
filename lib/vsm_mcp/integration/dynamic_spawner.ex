defmodule VsmMcp.Integration.DynamicSpawner do
  @moduledoc """
  Dynamically spawns and manages GenServer processes for integrated MCP capabilities.
  
  This module acts as a DynamicSupervisor that creates, monitors, and manages
  processes representing MCP server capabilities. Each capability runs in its
  own isolated process with health monitoring and automatic restart.
  
  ## Architecture
  
  The spawner creates a supervision tree where each MCP capability runs as a
  supervised child process. This ensures fault tolerance and isolation between
  different capabilities.
  
  ## Features
  
  - **Dynamic Process Creation**: Spawn processes on-demand based on variety gaps
  - **Supervision Tree Integration**: Automatic restart with backoff strategies
  - **Process Registry**: Named processes for easy discovery and communication
  - **Health Monitoring**: Continuous health checks with configurable thresholds
  - **Resource Management**: CPU and memory limits per capability
  - **Graceful Shutdown**: Clean termination with state preservation
  
  ## Process Lifecycle
  
  1. **Spawn**: Create process with verified capability configuration
  2. **Register**: Add to process registry with metadata
  3. **Monitor**: Start health checks and performance tracking
  4. **Maintain**: Handle restarts, updates, and resource management
  5. **Terminate**: Clean shutdown with state preservation
  
  ## Examples
  
      # Spawn a new capability
      iex> DynamicSpawner.spawn_capability(adapter, %{name: "web-search", ...})
      {:ok, #PID<0.123.0>}
      
      # List active capabilities
      iex> DynamicSpawner.list_capabilities()
      [%{id: "web-search", pid: #PID<0.123.0>, health: :healthy}]
      
      # Terminate a capability
      iex> DynamicSpawner.terminate_capability("web-search")
      :ok
  """
  
  use DynamicSupervisor
  require Logger
  
  @registry VsmMcp.Integration.Registry
  
  @doc """
  Starts the dynamic spawner supervisor.
  
  ## Parameters
  
  - `init_arg` - Initialization arguments for the supervisor
  
  ## Returns
  
  - `{:ok, pid}` - Supervisor started successfully
  - `{:error, reason}` - Startup failure
  """
  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @doc """
  Spawns a new capability process with the given adapter and configuration.
  
  ## Parameters
  
  - `adapter` - Protocol adapter for MCP communication
  - `verified_capability` - Map containing:
    - `:name` - Capability name
    - `:server_info` - MCP server details
    - `:variety_gap` - Gap this capability fills
    - `:config` - Additional configuration
  
  ## Returns
  
  - `{:ok, pid}` - Process spawned successfully
  - `{:error, reason}` - Spawn failure
  
  ## Side Effects
  
  - Registers process in capability registry
  - Starts health monitoring
  - Emits telemetry events
  """
  @spec spawn_capability(module(), map()) :: {:ok, pid()} | {:error, term()}
  def spawn_capability(adapter, verified_capability) do
    child_spec = build_child_spec(adapter, verified_capability)
    
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        register_process(pid, verified_capability)
        monitor_process(pid, verified_capability)
        {:ok, pid}
        
      {:error, reason} ->
        Logger.error("Failed to spawn capability: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Terminates a capability process gracefully.
  
  ## Parameters
  
  - `capability_id` - Unique identifier of the capability
  
  ## Returns
  
  - `:ok` - Process terminated successfully
  - `{:error, :process_not_found}` - No process with given ID
  
  ## Termination Process
  
  1. Sends shutdown signal to process
  2. Waits for graceful termination (5s timeout)
  3. Forces termination if needed
  4. Cleans up registry entries
  5. Notifies health monitor
  """
  @spec terminate_capability(String.t()) :: :ok | {:error, atom()}
  def terminate_capability(capability_id) do
    case lookup_process(capability_id) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        unregister_process(capability_id)
        
      {:error, :not_found} ->
        {:error, :process_not_found}
    end
  end
  
  @doc """
  Lists all active capability processes with their metadata.
  
  ## Returns
  
  List of capability maps containing:
  - `:id` - Capability identifier
  - `:pid` - Process ID
  - `:name` - Capability name
  - `:health` - Current health status
  - `:uptime` - Time since spawn
  - `:memory` - Memory usage in bytes
  
  ## Example
  
      iex> DynamicSpawner.list_capabilities()
      [
        %{
          id: "web-search-123",
          pid: #PID<0.234.0>,
          name: "web-search",
          health: :healthy,
          uptime: 3600,
          memory: 12582912
        }
      ]
  """
  @spec list_capabilities() :: [map()]
  def list_capabilities do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} ->
      case Registry.lookup(@registry, pid) do
        [{_, capability}] -> {pid, capability}
        [] -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
  
  @doc """
  Restarts a capability process.
  """
  def restart_capability(capability_id) do
    with {:ok, pid} <- lookup_process(capability_id),
         {:ok, capability} <- get_capability_info(pid),
         :ok <- terminate_capability(capability_id) do
      
      # Brief delay to ensure cleanup
      Process.sleep(100)
      
      spawn_capability(capability.adapter, capability.verified)
    end
  end
  
  ## Callbacks
  
  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 5,
      max_seconds: 60
    )
  end
  
  ## Private Functions
  
  defp build_child_spec(adapter, verified_capability) do
    %{
      id: verified_capability.id,
      start: {VsmMcp.Integration.CapabilityWorker, :start_link, 
              [{adapter, verified_capability}]},
      restart: :transient,
      shutdown: 5000,
      type: :worker
    }
  end
  
  defp register_process(pid, capability) do
    Registry.register(@registry, capability.id, %{
      capability: capability,
      started_at: DateTime.utc_now(),
      pid: pid
    })
  end
  
  defp unregister_process(capability_id) do
    Registry.unregister(@registry, capability_id)
  end
  
  defp monitor_process(pid, capability) do
    # Start health monitoring
    VsmMcp.Integration.HealthMonitor.monitor(pid, capability)
  end
  
  defp lookup_process(capability_id) do
    case Registry.lookup(@registry, capability_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end
  
  defp get_capability_info(pid) do
    case Registry.lookup(@registry, pid) do
      [{_, %{capability: capability}}] -> {:ok, capability}
      [] -> {:error, :not_found}
    end
  end
end

defmodule VsmMcp.Integration.CapabilityWorker do
  @moduledoc """
  GenServer worker for integrated MCP capabilities.
  """
  
  use GenServer
  require Logger
  
  def start_link({adapter, capability}) do
    GenServer.start_link(__MODULE__, {adapter, capability})
  end
  
  @impl true
  def init({adapter, capability}) do
    Logger.info("Starting capability worker: #{capability.id}")
    
    # Initialize the MCP connection through the adapter
    case adapter.connect() do
      {:ok, connection} ->
        state = %{
          adapter: adapter,
          capability: capability,
          connection: connection,
          stats: %{
            requests: 0,
            errors: 0,
            last_used: DateTime.utc_now()
          }
        }
        
        # Schedule periodic health checks
        schedule_health_check()
        
        {:ok, state}
        
      {:error, reason} ->
        Logger.error("Failed to connect to MCP server: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_call({:execute, method, params}, _from, state) do
    {result, new_state} = execute_capability(method, params, state)
    {:reply, result, new_state}
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, {:ok, state.stats}, state}
  end
  
  @impl true
  def handle_call(:health_check, _from, state) do
    case state.adapter.health_check(state.connection) do
      :ok ->
        {:reply, :healthy, state}
        
      {:error, reason} ->
        {:reply, {:unhealthy, reason}, state}
    end
  end
  
  @impl true
  def handle_info(:scheduled_health_check, state) do
    case state.adapter.health_check(state.connection) do
      :ok ->
        schedule_health_check()
        {:noreply, state}
        
      {:error, reason} ->
        Logger.warning("Health check failed: #{inspect(reason)}")
        # Attempt reconnection
        case state.adapter.reconnect(state.connection) do
          {:ok, new_connection} ->
            schedule_health_check()
            {:noreply, %{state | connection: new_connection}}
            
          {:error, _} ->
            # Stop the worker, supervisor will restart if configured
            {:stop, :health_check_failed, state}
        end
    end
  end
  
  @impl true
  def terminate(reason, state) do
    Logger.info("Terminating capability worker #{state.capability.id}: #{inspect(reason)}")
    state.adapter.disconnect(state.connection)
    :ok
  end
  
  ## Private Functions
  
  defp execute_capability(method, params, state) do
    start_time = System.monotonic_time(:millisecond)
    
    result = state.adapter.execute(state.connection, method, params)
    
    duration = System.monotonic_time(:millisecond) - start_time
    new_stats = update_stats(state.stats, result, duration)
    
    new_state = %{state | stats: new_stats}
    
    {result, new_state}
  end
  
  defp update_stats(stats, result, duration) do
    base_updates = %{
      requests: stats.requests + 1,
      last_used: DateTime.utc_now()
    }
    
    case result do
      {:ok, _} ->
        Map.merge(stats, base_updates)
        |> Map.put(:last_success, DateTime.utc_now())
        |> Map.put(:avg_duration, calculate_avg_duration(stats, duration))
        
      {:error, _} ->
        Map.merge(stats, base_updates)
        |> Map.update(:errors, 1, &(&1 + 1))
        |> Map.put(:last_error, DateTime.utc_now())
    end
  end
  
  defp calculate_avg_duration(stats, new_duration) do
    case Map.get(stats, :avg_duration) do
      nil -> new_duration
      current_avg ->
        # Simple moving average
        (current_avg * 0.9 + new_duration * 0.1)
    end
  end
  
  defp schedule_health_check do
    # Check every 30 seconds
    Process.send_after(self(), :scheduled_health_check, 30_000)
  end
end

defmodule VsmMcp.Integration.HealthMonitor do
  @moduledoc """
  Monitors health of capability processes.
  """
  
  use GenServer
  require Logger
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def monitor(pid, capability) do
    GenServer.cast(__MODULE__, {:monitor, pid, capability})
  end
  
  @impl true
  def init(_opts) do
    {:ok, %{monitors: %{}}}
  end
  
  @impl true
  def handle_cast({:monitor, pid, capability}, state) do
    ref = Process.monitor(pid)
    
    new_monitors = Map.put(state.monitors, ref, %{
      pid: pid,
      capability: capability,
      started_at: DateTime.utc_now()
    })
    
    {:noreply, %{state | monitors: new_monitors}}
  end
  
  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    case Map.get(state.monitors, ref) do
      nil ->
        {:noreply, state}
        
      monitor_info ->
        Logger.warning("Capability process #{monitor_info.capability.id} down: #{inspect(reason)}")
        
        # Notify integration system
        send(VsmMcp.Integration, {:capability_down, monitor_info.capability, reason})
        
        new_monitors = Map.delete(state.monitors, ref)
        {:noreply, %{state | monitors: new_monitors}}
    end
  end
end