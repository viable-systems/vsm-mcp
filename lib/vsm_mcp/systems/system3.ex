defmodule VsmMcp.Systems.System3 do
  @moduledoc """
  System 3: Control (Operational Management)
  
  Manages the internal stability and optimization of System 1 operations,
  ensuring efficiency and resource allocation.
  """
  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def audit_operations(unit_id) do
    GenServer.call(__MODULE__, {:audit, unit_id})
  end

  def optimize_resources(constraints) do
    GenServer.call(__MODULE__, {:optimize, constraints})
  end

  def set_performance_targets(targets) do
    GenServer.cast(__MODULE__, {:set_targets, targets})
  end

  def get_control_metrics do
    GenServer.call(__MODULE__, :metrics)
  end

  def get_status do
    GenServer.call(__MODULE__, :status)
  end

  def audit_all do
    GenServer.call(__MODULE__, :audit_all)
  end

  def coordinate_operations(operations) do
    GenServer.call(__MODULE__, {:coordinate_operations, operations})
  end

  def enforce_policy(policy) do
    GenServer.call(__MODULE__, {:enforce_policy, policy})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      performance_targets: default_targets(),
      operational_policies: default_policies(),
      audit_results: %{},
      resource_allocations: %{},
      optimization_history: [],
      telemetry_ref: nil
    }
    
    # Start telemetry polling
    {:ok, ref} = :telemetry_poller.start_link(
      measurements: [
        {__MODULE__, :gather_metrics, []}
      ],
      period: 5000,
      name: :"#{__MODULE__}.Poller"
    )
    
    Logger.info("System 3 (Control) initialized with telemetry")
    {:ok, Map.put(state, :telemetry_ref, ref)}
  end

  @impl true
  def handle_call({:audit, unit_id}, _from, state) do
    audit_result = perform_audit(unit_id, state)
    
    new_audit_results = Map.put(state.audit_results, unit_id, %{
      result: audit_result,
      timestamp: DateTime.utc_now()
    })
    
    new_state = Map.put(state, :audit_results, new_audit_results)
    
    {:reply, {:ok, audit_result}, new_state}
  end

  @impl true
  def handle_call({:optimize, constraints}, _from, state) do
    optimization = calculate_optimization(constraints, state)
    
    new_history = [
      %{
        constraints: constraints,
        optimization: optimization,
        timestamp: DateTime.utc_now()
      } | state.optimization_history
    ]
    
    new_state = state
      |> Map.put(:optimization_history, Enum.take(new_history, 100))
      |> apply_optimization(optimization)
    
    {:reply, {:ok, optimization}, new_state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    metrics = %{
      targets_met: calculate_target_achievement(state),
      resource_efficiency: calculate_resource_efficiency(state),
      policy_compliance: calculate_policy_compliance(state),
      recent_audits: Map.keys(state.audit_results) |> length(),
      optimizations_performed: length(state.optimization_history)
    }
    
    {:reply, metrics, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      active: true,
      audits_performed: map_size(state.audit_results),
      policies_enforced: map_size(state.operational_policies),
      optimizations_count: length(state.optimization_history),
      targets_set: map_size(state.performance_targets),
      last_audit: get_last_audit_time(state.audit_results),
      resource_efficiency: calculate_resource_efficiency(state),
      operational_health: calculate_operational_health(state),
      control_effectiveness: calculate_control_effectiveness(state)
    }
    
    {:reply, status, state}
  end

  @impl true
  def handle_call(:audit_all, _from, state) do
    # Get all registered units from System2
    all_units = get_all_registered_units()
    
    # Perform audit on all units
    audit_results = Enum.map(all_units, fn unit_id ->
      {unit_id, perform_audit(unit_id, state)}
    end)
    |> Map.new()
    
    # Update state with all audit results
    new_audit_results = Map.merge(state.audit_results, 
      Map.new(audit_results, fn {unit_id, result} ->
        {unit_id, %{result: result, timestamp: DateTime.utc_now()}}
      end))
    
    new_state = Map.put(state, :audit_results, new_audit_results)
    
    {:reply, {:ok, audit_results}, new_state}
  end

  @impl true
  def handle_call({:coordinate_operations, operations}, _from, state) do
    # Analyze and coordinate operations based on policies and targets
    coordination_plan = create_operational_coordination(operations, state)
    
    # Apply optimizations
    optimized_operations = apply_operational_optimizations(operations, coordination_plan, state)
    
    # Store coordination history
    new_state = update_coordination_history(state, coordination_plan)
    
    {:reply, {:ok, optimized_operations}, new_state}
  end

  @impl true
  def handle_call({:enforce_policy, policy}, _from, state) do
    result = validate_and_enforce_policy(policy, state)
    
    new_state = case result do
      {:ok, _} -> 
        Map.update!(state, :operational_policies, &Map.put(&1, policy.id, policy))
      _ -> 
        state
    end
    
    {:reply, result, new_state}
  end

  @impl true
  def handle_cast({:set_targets, targets}, state) do
    validated_targets = validate_targets(targets)
    new_state = Map.put(state, :performance_targets, validated_targets)
    
    Logger.info("Updated performance targets: #{inspect(Map.keys(validated_targets))}")
    {:noreply, new_state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.telemetry_ref, do: Process.exit(state.telemetry_ref, :normal)
    :ok
  end

  # Private Functions

  defp perform_audit(unit_id, state) do
    # Simulate audit process
    %{
      unit_id: unit_id,
      performance: Enum.random(70..100) / 100,
      resource_usage: %{
        cpu: Enum.random(10..90),
        memory: Enum.random(20..80),
        io: Enum.random(5..50)
      },
      policy_violations: check_policy_violations(unit_id, state.operational_policies),
      recommendations: generate_recommendations(unit_id)
    }
  end

  defp calculate_optimization(constraints, state) do
    %{
      resource_reallocation: optimize_resource_allocation(constraints, state.resource_allocations),
      process_improvements: identify_process_improvements(state),
      estimated_improvement: Enum.random(5..25) / 100
    }
  end

  defp apply_optimization(state, optimization) do
    Map.put(state, :resource_allocations, optimization.resource_reallocation)
  end

  defp calculate_target_achievement(state) do
    # Simplified calculation
    achieved = Enum.count(state.performance_targets, fn {_metric, target} ->
      current_value = Enum.random(80..120) / 100 * target
      current_value >= target * 0.95
    end)
    
    achieved / max(map_size(state.performance_targets), 1)
  end

  defp calculate_resource_efficiency(state) do
    if map_size(state.resource_allocations) == 0 do
      0.0
    else
      # Simplified efficiency calculation
      Enum.random(70..95) / 100
    end
  end

  defp calculate_policy_compliance(state) do
    total_policies = map_size(state.operational_policies)
    if total_policies == 0 do
      1.0
    else
      # Simplified compliance calculation
      Enum.random(85..100) / 100
    end
  end

  defp check_policy_violations(_unit_id, policies) do
    # Randomly generate some violations for demonstration
    policies
    |> Map.values()
    |> Enum.filter(fn _ -> Enum.random(1..10) > 8 end)
    |> Enum.map(& &1.id)
  end

  defp generate_recommendations(unit_id) do
    [
      "Optimize batch processing for #{unit_id}",
      "Consider scaling resources during peak hours",
      "Review error handling procedures"
    ]
    |> Enum.take(Enum.random(1..3))
  end

  defp optimize_resource_allocation(constraints, current_allocations) do
    # Simple optimization logic
    Map.new(constraints, fn {resource, constraint} ->
      current = Map.get(current_allocations, resource, 0)
      optimized = min(current * 1.1, constraint)
      {resource, optimized}
    end)
  end

  defp identify_process_improvements(_state) do
    [
      "Implement caching for frequent operations",
      "Parallelize independent tasks",
      "Reduce synchronization overhead"
    ]
    |> Enum.take(Enum.random(1..2))
  end

  defp validate_targets(targets) do
    Map.new(targets, fn {metric, value} ->
      {metric, max(0, value)}
    end)
  end

  defp validate_and_enforce_policy(policy, _state) do
    if valid_policy?(policy) do
      {:ok, "Policy #{policy.id} enforced"}
    else
      {:error, "Invalid policy structure"}
    end
  end

  defp valid_policy?(policy) do
    Map.has_key?(policy, :id) and Map.has_key?(policy, :rules)
  end

  defp default_targets do
    %{
      throughput: 1000,
      latency_ms: 100,
      error_rate: 0.01,
      resource_utilization: 0.8
    }
  end

  defp default_policies do
    %{
      "security" => %{
        id: "security",
        scope: :all,
        rules: ["encrypt_data", "validate_input", "audit_access"]
      },
      "performance" => %{
        id: "performance",
        scope: :operational,
        rules: ["cache_results", "batch_operations", "limit_concurrency"]
      }
    }
  end

  # Telemetry function
  def gather_metrics do
    :telemetry.execute(
      [:vsm_mcp, :system3, :metrics],
      %{
        audit_count: :rand.uniform(10),
        optimization_score: :rand.uniform(100)
      },
      %{system: 3}
    )
  end

  defp get_last_audit_time(audit_results) do
    if map_size(audit_results) > 0 do
      audit_results
      |> Map.values()
      |> Enum.map(& &1.timestamp)
      |> Enum.max(DateTime)
    else
      nil
    end
  end

  defp calculate_operational_health(state) do
    # Composite health score based on multiple factors
    policy_score = min(map_size(state.operational_policies) / 5, 1.0) * 0.3
    audit_score = calculate_audit_health(state.audit_results) * 0.3
    optimization_score = calculate_optimization_effectiveness(state.optimization_history) * 0.2
    target_score = calculate_target_achievement(state) * 0.2
    
    policy_score + audit_score + optimization_score + target_score
  end

  defp calculate_audit_health(audit_results) do
    if map_size(audit_results) == 0 do
      0.5
    else
      recent_audits = audit_results
      |> Map.values()
      |> Enum.filter(fn audit ->
        DateTime.diff(DateTime.utc_now(), audit.timestamp, :hour) < 24
      end)
      
      if length(recent_audits) > 0 do
        avg_performance = recent_audits
        |> Enum.map(& &1.result.performance)
        |> Enum.sum()
        |> Kernel./(length(recent_audits))
        
        avg_performance
      else
        0.7
      end
    end
  end

  defp calculate_optimization_effectiveness(optimization_history) do
    recent_optimizations = Enum.take(optimization_history, 10)
    
    if length(recent_optimizations) > 0 do
      avg_improvement = recent_optimizations
      |> Enum.map(& &1.optimization.estimated_improvement)
      |> Enum.sum()
      |> Kernel./(length(recent_optimizations))
      
      avg_improvement
    else
      0.5
    end
  end

  defp get_all_registered_units do
    # Query System2 for registered units
    try do
      status = GenServer.call(VsmMcp.Systems.System2, :status, 5000)
      status.registered_units
    rescue
      _ -> []
    end
  end

  defp create_operational_coordination(operations, state) do
    %{
      operations: operations,
      applied_policies: find_applicable_policies(operations, state.operational_policies),
      resource_allocation: allocate_operational_resources(operations, state),
      optimization_strategy: determine_optimization_strategy(operations),
      priority_order: prioritize_operations(operations, state.performance_targets),
      coordination_timestamp: DateTime.utc_now()
    }
  end

  defp apply_operational_optimizations(operations, coordination_plan, _state) do
    operations
    |> apply_resource_optimizations(coordination_plan.resource_allocation)
    |> apply_policy_constraints(coordination_plan.applied_policies)
    |> reorder_by_priority(coordination_plan.priority_order)
    |> batch_similar_operations()
  end

  defp update_coordination_history(state, coordination_plan) do
    Map.update(state, :coordination_history, [coordination_plan], fn history ->
      [coordination_plan | Enum.take(history, 99)]
    end)
  end

  defp find_applicable_policies(operations, policies) do
    policies
    |> Map.values()
    |> Enum.filter(fn policy ->
      Enum.any?(operations, fn op ->
        operation_matches_policy?(op, policy)
      end)
    end)
  end

  defp allocate_operational_resources(operations, state) do
    total_operations = length(operations)
    available_resources = Map.get(state, :available_resources, %{cpu: 100, memory: 100})
    
    %{
      per_operation: %{
        cpu: available_resources.cpu / max(total_operations, 1),
        memory: available_resources.memory / max(total_operations, 1)
      },
      total_allocated: available_resources,
      allocation_strategy: :proportional
    }
  end

  defp determine_optimization_strategy(operations) do
    operation_types = operations
    |> Enum.map(& &1[:type])
    |> Enum.uniq()
    |> length()
    
    cond do
      operation_types == 1 -> :specialized
      operation_types <= 3 -> :grouped
      true -> :general
    end
  end

  defp prioritize_operations(operations, targets) do
    operations
    |> Enum.map(fn op ->
      priority_score = calculate_operation_priority(op, targets)
      {priority_score, op}
    end)
    |> Enum.sort_by(&elem(&1, 0), :desc)
    |> Enum.map(&elem(&1, 1))
  end

  defp operation_matches_policy?(operation, policy) do
    policy.scope == :all or 
    (Map.get(operation, :type) == policy.scope) or
    (Map.get(operation, :category) in Map.get(policy, :categories, []))
  end

  defp apply_resource_optimizations(operations, allocation) do
    Enum.map(operations, fn op ->
      Map.put(op, :allocated_resources, allocation.per_operation)
    end)
  end

  defp apply_policy_constraints(operations, policies) do
    Enum.map(operations, fn op ->
      constraints = gather_constraints_for_operation(op, policies)
      Map.put(op, :constraints, constraints)
    end)
  end

  defp reorder_by_priority(operations, priority_order) do
    # If priority_order is already the operations in order, return it
    if length(priority_order) == length(operations) do
      priority_order
    else
      operations
    end
  end

  defp batch_similar_operations(operations) do
    operations
    |> Enum.group_by(& &1[:type])
    |> Map.values()
    |> List.flatten()
  end

  defp calculate_operation_priority(operation, targets) do
    base_priority = Map.get(operation, :priority, 0.5)
    target_alignment = calculate_target_alignment(operation, targets)
    
    base_priority * 0.7 + target_alignment * 0.3
  end

  defp gather_constraints_for_operation(operation, policies) do
    policies
    |> Enum.flat_map(fn policy ->
      if operation_matches_policy?(operation, policy) do
        Map.get(policy, :rules, [])
      else
        []
      end
    end)
    |> Enum.uniq()
  end

  defp calculate_target_alignment(operation, targets) do
    relevant_metrics = Map.get(operation, :impacts, [])
    
    if Enum.empty?(relevant_metrics) do
      0.5
    else
      aligned_metrics = Enum.count(relevant_metrics, fn metric ->
        Map.has_key?(targets, metric)
      end)
      
      aligned_metrics / length(relevant_metrics)
    end
  end
  
  defp calculate_control_effectiveness(state) do
    # Calculate effectiveness as percentage
    factors = [
      if(map_size(state.operational_policies) > 0, do: 1, else: 0),
      if(map_size(state.performance_targets) > 0, do: 1, else: 0),
      if(length(state.optimization_history) > 0, do: 1, else: 0),
      calculate_operational_health(state)
    ]
    
    effectiveness = Enum.sum(factors) / length(factors) * 100
    round(effectiveness)
  end
end