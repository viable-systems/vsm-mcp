defmodule VsmMcp.Systems.System2 do
  @moduledoc """
  System 2: Coordination
  
  Manages the coordination between operational units in System 1,
  resolving conflicts and ensuring smooth operation.
  """
  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def coordinate(units, task) do
    GenServer.call(__MODULE__, {:coordinate, units, task})
  end

  def resolve_conflict(conflict) do
    GenServer.call(__MODULE__, {:resolve_conflict, conflict})
  end

  def get_coordination_status do
    GenServer.call(__MODULE__, :status)
  end

  def register_unit(unit_id, capabilities) do
    GenServer.cast(__MODULE__, {:register_unit, unit_id, capabilities})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      units: %{},
      active_coordinations: [],
      conflict_resolution_history: [],
      coordination_rules: default_rules()
    }
    
    Logger.info("System 2 (Coordination) initialized")
    {:ok, state}
  end

  @impl true
  def handle_call({:coordinate, units, task}, _from, state) do
    coordination_plan = create_coordination_plan(units, task, state.units)
    
    new_coordination = %{
      id: generate_id(),
      units: units,
      task: task,
      plan: coordination_plan,
      status: :active,
      started_at: DateTime.utc_now()
    }
    
    new_state = Map.update!(state, :active_coordinations, &[new_coordination | &1])
    
    {:reply, {:ok, coordination_plan}, new_state}
  end

  @impl true
  def handle_call({:resolve_conflict, conflict}, _from, state) do
    resolution = apply_conflict_resolution(conflict, state.coordination_rules)
    
    history_entry = %{
      conflict: conflict,
      resolution: resolution,
      resolved_at: DateTime.utc_now()
    }
    
    new_state = Map.update!(state, :conflict_resolution_history, &[history_entry | &1])
    
    {:reply, {:ok, resolution}, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      registered_units: Map.keys(state.units),
      active_coordinations: length(state.active_coordinations),
      conflicts_resolved: length(state.conflict_resolution_history),
      coordination_rules: length(state.coordination_rules)
    }
    {:reply, status, state}
  end

  @impl true
  def handle_cast({:register_unit, unit_id, capabilities}, state) do
    new_units = Map.put(state.units, unit_id, %{
      capabilities: capabilities,
      registered_at: DateTime.utc_now()
    })
    
    Logger.info("Registered unit #{unit_id} with capabilities: #{inspect(capabilities)}")
    {:noreply, Map.put(state, :units, new_units)}
  end

  # Private Functions

  defp create_coordination_plan(units, task, registered_units) do
    # Simple coordination logic - can be made more sophisticated
    available_units = Enum.filter(units, &Map.has_key?(registered_units, &1))
    
    %{
      assigned_units: available_units,
      task_distribution: distribute_task(task, available_units),
      synchronization_points: create_sync_points(task),
      estimated_duration: estimate_duration(task, length(available_units))
    }
  end

  defp distribute_task(task, units) do
    # Simple round-robin distribution
    subtasks = task[:subtasks] || [task]
    
    units
    |> Enum.with_index()
    |> Enum.map(fn {unit, index} ->
      assigned_subtasks = subtasks
        |> Enum.with_index()
        |> Enum.filter(fn {_, i} -> rem(i, length(units)) == index end)
        |> Enum.map(fn {subtask, _} -> subtask end)
      
      {unit, assigned_subtasks}
    end)
    |> Map.new()
  end

  defp create_sync_points(task) do
    # Create synchronization points based on task dependencies
    [
      %{phase: :initialization, timeout: 5000},
      %{phase: :execution, timeout: task[:timeout] || 30000},
      %{phase: :completion, timeout: 5000}
    ]
  end

  defp estimate_duration(task, unit_count) do
    base_duration = task[:estimated_duration] || 10000
    # Adjust based on parallelization potential
    base_duration / :math.sqrt(unit_count)
  end

  defp apply_conflict_resolution(conflict, rules) do
    # Find applicable rule
    rule = Enum.find(rules, fn r -> r.type == conflict.type end) || hd(rules)
    
    %{
      action: rule.resolution_action,
      priority_unit: determine_priority(conflict.units),
      delay_others: rule.delay_ms,
      reason: rule.reason
    }
  end

  defp determine_priority(units) do
    # Simple priority: first unit wins (can be made more sophisticated)
    hd(units)
  end

  defp default_rules do
    [
      %{
        type: :resource_conflict,
        resolution_action: :queue,
        delay_ms: 100,
        reason: "Resource contention - queuing access"
      },
      %{
        type: :timing_conflict,
        resolution_action: :reschedule,
        delay_ms: 0,
        reason: "Timing conflict - rescheduling"
      },
      %{
        type: :default,
        resolution_action: :arbitrate,
        delay_ms: 50,
        reason: "Default arbitration"
      }
    ]
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end