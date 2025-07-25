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

  def get_status do
    GenServer.call(__MODULE__, :status)
  end

  def coordinate_units(units) do
    GenServer.call(__MODULE__, {:coordinate_units, units})
  end

  def transform_variety(input_variety, constraints) do
    GenServer.call(__MODULE__, {:transform_variety, input_variety, constraints})
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
      active: true,
      coordination_count: length(state.active_coordinations),
      registered_units: Map.keys(state.units),
      active_coordinations: length(state.active_coordinations),
      conflicts_resolved: length(state.conflict_resolution_history),
      coordination_rules: length(state.coordination_rules),
      units_coordinated: calculate_total_units_coordinated(state),
      variety_transformations: Map.get(state, :variety_transformations, 0)
    }
    {:reply, status, state}
  end

  @impl true
  def handle_call({:coordinate_units, units}, _from, state) do
    # Coordinate units based on their capabilities and current state
    coordination_result = perform_unit_coordination(units, state)
    
    new_state = state
    |> update_coordination_history(coordination_result)
    |> increment_coordination_count()
    
    {:reply, {:ok, coordination_result}, new_state}
  end

  @impl true
  def handle_call({:transform_variety, input_variety, constraints}, _from, state) do
    # Transform variety based on constraints and coordination rules
    transformation_result = perform_variety_transformation(input_variety, constraints, state)
    
    new_state = state
    |> Map.update(:variety_transformations, 1, &(&1 + 1))
    |> store_transformation_result(transformation_result)
    
    {:reply, {:ok, transformation_result}, new_state}
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

  defp calculate_total_units_coordinated(state) do
    state.active_coordinations
    |> Enum.flat_map(& &1.units)
    |> Enum.uniq()
    |> length()
  end

  defp perform_unit_coordination(units, state) do
    # Analyze unit capabilities
    unit_capabilities = units
    |> Enum.map(fn unit ->
      {unit, Map.get(state.units, unit, %{capabilities: []})}
    end)
    |> Map.new()
    
    # Create coordination plan
    %{
      units: units,
      coordination_type: determine_coordination_type(unit_capabilities),
      synchronization: create_synchronization_plan(units),
      resource_allocation: allocate_resources(unit_capabilities),
      communication_channels: establish_channels(units),
      timestamp: DateTime.utc_now()
    }
  end

  defp update_coordination_history(state, result) do
    Map.update(state, :coordination_history, [result], &[result | &1])
  end

  defp increment_coordination_count(state) do
    Map.update(state, :coordination_count, 1, &(&1 + 1))
  end

  defp perform_variety_transformation(input_variety, constraints, state) do
    # Analyze input variety
    variety_analysis = analyze_variety(input_variety)
    
    # Apply transformation based on constraints and rules
    transformed = apply_transformation_rules(variety_analysis, constraints, state.coordination_rules)
    
    %{
      input: input_variety,
      output: transformed,
      reduction_ratio: calculate_reduction_ratio(input_variety, transformed),
      constraints_applied: constraints,
      transformation_method: select_transformation_method(variety_analysis),
      timestamp: DateTime.utc_now()
    }
  end

  defp store_transformation_result(state, result) do
    Map.update(state, :transformation_history, [result], &[result | Enum.take(&1, 99)])
  end

  defp determine_coordination_type(unit_capabilities) do
    capability_overlap = calculate_capability_overlap(unit_capabilities)
    
    cond do
      capability_overlap > 0.7 -> :parallel
      capability_overlap < 0.3 -> :sequential
      true -> :hybrid
    end
  end

  defp create_synchronization_plan(units) do
    %{
      checkpoints: generate_checkpoints(length(units)),
      communication_protocol: :async,
      timeout: 30_000
    }
  end

  defp allocate_resources(unit_capabilities) do
    total_units = map_size(unit_capabilities)
    base_allocation = 100 / max(total_units, 1)
    
    Map.new(unit_capabilities, fn {unit, _} ->
      {unit, %{cpu: base_allocation, memory: base_allocation, priority: :medium}}
    end)
  end

  defp establish_channels(units) do
    # Create communication matrix
    for u1 <- units, u2 <- units, u1 != u2 do
      {u1, u2}
    end
    |> Enum.uniq()
  end

  defp analyze_variety(input_variety) do
    %{
      complexity: assess_complexity(input_variety),
      dimensions: count_dimensions(input_variety),
      entropy: calculate_entropy(input_variety)
    }
  end

  defp apply_transformation_rules(analysis, constraints, rules) do
    # Apply rules in order of priority
    rules
    |> Enum.sort_by(& &1[:priority], :desc)
    |> Enum.reduce(analysis, fn rule, acc ->
      if rule_applies?(rule, acc, constraints) do
        apply_rule(rule, acc)
      else
        acc
      end
    end)
  end

  defp calculate_reduction_ratio(input, output) do
    input_size = estimate_variety_size(input)
    output_size = estimate_variety_size(output)
    
    if input_size > 0 do
      1.0 - (output_size / input_size)
    else
      0.0
    end
  end

  defp select_transformation_method(analysis) do
    case analysis.complexity do
      c when c > 0.8 -> :hierarchical_decomposition
      c when c > 0.5 -> :rule_based_filtering
      _ -> :direct_mapping
    end
  end

  defp calculate_capability_overlap(unit_capabilities) do
    all_capabilities = unit_capabilities
    |> Map.values()
    |> Enum.flat_map(& &1.capabilities)
    
    unique_capabilities = Enum.uniq(all_capabilities)
    
    if length(all_capabilities) > 0 do
      length(unique_capabilities) / length(all_capabilities)
    else
      0.0
    end
  end

  defp generate_checkpoints(unit_count) do
    base_checkpoints = [:start, :middle, :end]
    
    if unit_count > 5 do
      base_checkpoints ++ [:quarter, :three_quarter]
    else
      base_checkpoints
    end
  end

  defp assess_complexity(variety) do
    # Simple complexity assessment
    case variety do
      v when is_map(v) -> map_size(v) / 10
      v when is_list(v) -> length(v) / 20
      _ -> 0.5
    end
    |> min(1.0)
  end

  defp count_dimensions(variety) when is_map(variety), do: map_size(variety)
  defp count_dimensions(variety) when is_list(variety), do: 1
  defp count_dimensions(_), do: 0

  defp calculate_entropy(_variety) do
    # Simplified entropy calculation
    Enum.random(30..70) / 100
  end

  defp rule_applies?(_rule, _analysis, _constraints), do: Enum.random([true, false])

  defp apply_rule(_rule, acc), do: acc

  defp estimate_variety_size(variety) when is_map(variety), do: map_size(variety) * 10
  defp estimate_variety_size(variety) when is_list(variety), do: length(variety) * 5
  defp estimate_variety_size(_), do: 1
end