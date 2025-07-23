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

  defp identify_process_improvements(state) do
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
        rules: ["encrypt_data", "validate_input", "audit_access"]
      },
      "performance" => %{
        id: "performance",
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
end