defmodule VsmMcp.Systems.System5 do
  @moduledoc """
  System 5: Policy (Identity & Purpose)
  
  Defines and maintains the organization's identity, purpose, and policies.
  Balances present operations with future viability.
  """
  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def set_policy(policy_type, policy_data) do
    GenServer.call(__MODULE__, {:set_policy, policy_type, policy_data})
  end

  def get_policy(policy_type) do
    GenServer.call(__MODULE__, {:get_policy, policy_type})
  end

  def validate_decision(decision, context) do
    GenServer.call(__MODULE__, {:validate_decision, decision, context})
  end

  def balance_objectives(present_needs, future_goals) do
    GenServer.call(__MODULE__, {:balance, present_needs, future_goals})
  end

  def get_organizational_identity do
    GenServer.call(__MODULE__, :identity)
  end

  def update_mission(mission_statement) do
    GenServer.cast(__MODULE__, {:update_mission, mission_statement})
  end

  def review_system_health do
    GenServer.call(__MODULE__, :system_health)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %{
      identity: %{
        mission: opts[:mission] || "Provide adaptive value through viable systems",
        vision: opts[:vision] || "Excellence through systemic thinking",
        values: opts[:values] || default_values(),
        purpose: opts[:purpose] || "Maintain viability while delivering value"
      },
      policies: default_policies(),
      decision_history: [],
      balance_metrics: %{
        present_focus: 0.5,
        future_focus: 0.5,
        last_review: DateTime.utc_now()
      },
      system_constraints: default_constraints()
    }
    
    # Schedule periodic health reviews
    Process.send_after(self(), :periodic_review, 60_000)
    
    Logger.info("System 5 (Policy) initialized - Mission: #{state.identity.mission}")
    {:ok, state}
  end

  @impl true
  def handle_call({:set_policy, policy_type, policy_data}, _from, state) do
    case validate_policy(policy_type, policy_data, state) do
      {:ok, validated_policy} ->
        new_policies = Map.put(state.policies, policy_type, validated_policy)
        new_state = Map.put(state, :policies, new_policies)
        
        Logger.info("Policy updated: #{policy_type}")
        {:reply, {:ok, validated_policy}, new_state}
      
      {:error, reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_policy, policy_type}, _from, state) do
    policy = Map.get(state.policies, policy_type)
    {:reply, policy, state}
  end

  @impl true
  def handle_call({:validate_decision, decision, context}, _from, state) do
    validation_result = perform_decision_validation(decision, context, state)
    
    # Record decision
    history_entry = %{
      decision: decision,
      context: context,
      validation: validation_result,
      timestamp: DateTime.utc_now()
    }
    
    new_history = [history_entry | state.decision_history] |> Enum.take(1000)
    new_state = Map.put(state, :decision_history, new_history)
    
    {:reply, validation_result, new_state}
  end

  @impl true
  def handle_call({:balance, present_needs, future_goals}, _from, state) do
    balance_recommendation = calculate_balance(present_needs, future_goals, state)
    
    # Update balance metrics
    new_balance_metrics = %{
      present_focus: balance_recommendation.present_weight,
      future_focus: balance_recommendation.future_weight,
      last_review: DateTime.utc_now()
    }
    
    new_state = Map.put(state, :balance_metrics, new_balance_metrics)
    
    {:reply, {:ok, balance_recommendation}, new_state}
  end

  @impl true
  def handle_call(:identity, _from, state) do
    {:reply, state.identity, state}
  end

  @impl true
  def handle_call(:system_health, _from, state) do
    health_report = compile_health_report(state)
    {:reply, health_report, state}
  end

  @impl true
  def handle_cast({:update_mission, mission_statement}, state) do
    new_identity = Map.put(state.identity, :mission, mission_statement)
    new_state = Map.put(state, :identity, new_identity)
    
    Logger.info("Mission updated: #{mission_statement}")
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:periodic_review, state) do
    # Perform system health check
    health = assess_system_health(state)
    
    # Alert if issues detected
    if health.overall_score < 0.7 do
      Logger.warning("System health below threshold: #{health.overall_score}")
    end
    
    # Schedule next review
    Process.send_after(self(), :periodic_review, 60_000)
    
    {:noreply, state}
  end

  # Private Functions

  defp validate_policy(policy_type, policy_data, state) do
    cond do
      not is_map(policy_data) ->
        {:error, "Policy data must be a map"}
      
      conflicts_with_identity?(policy_data, state.identity) ->
        {:error, "Policy conflicts with organizational identity"}
      
      violates_constraints?(policy_data, state.system_constraints) ->
        {:error, "Policy violates system constraints"}
      
      true ->
        {:ok, Map.put(policy_data, :type, policy_type)}
    end
  end

  defp conflicts_with_identity?(policy_data, identity) do
    # Check if policy aligns with values
    policy_values = Map.get(policy_data, :values, [])
    
    Enum.any?(policy_values, fn value ->
      value in [:harm, :deception, :waste] and value not in identity.values
    end)
  end

  defp violates_constraints?(policy_data, constraints) do
    # Check resource constraints
    required_resources = Map.get(policy_data, :required_resources, %{})
    
    Enum.any?(required_resources, fn {resource, amount} ->
      max_allowed = Map.get(constraints.resources, resource, 0)
      amount > max_allowed
    end)
  end

  defp perform_decision_validation(decision, context, state) do
    checks = %{
      identity_alignment: check_identity_alignment(decision, state.identity),
      policy_compliance: check_policy_compliance(decision, state.policies),
      resource_feasibility: check_resource_feasibility(decision, state.system_constraints),
      future_impact: assess_future_impact(decision, context)
    }
    
    overall_valid = Enum.all?(Map.values(checks), & &1.valid)
    
    %{
      valid: overall_valid,
      checks: checks,
      recommendation: generate_recommendation(checks),
      confidence: calculate_validation_confidence(checks)
    }
  end

  defp check_identity_alignment(decision, identity) do
    # Simplified alignment check
    alignment_score = case decision.type do
      :strategic -> 0.9
      :operational -> 0.7
      :tactical -> 0.8
      _ -> 0.5
    end
    
    %{
      valid: alignment_score > 0.6,
      score: alignment_score,
      reason: "Decision aligns with #{identity.purpose}"
    }
  end

  defp check_policy_compliance(decision, policies) do
    applicable_policies = find_applicable_policies(decision, policies)
    violations = detect_violations(decision, applicable_policies)
    
    %{
      valid: Enum.empty?(violations),
      violations: violations,
      checked_policies: length(applicable_policies)
    }
  end

  defp check_resource_feasibility(decision, constraints) do
    required = Map.get(decision, :resources, %{})
    available = constraints.resources
    
    feasible = Enum.all?(required, fn {resource, amount} ->
      Map.get(available, resource, 0) >= amount
    end)
    
    %{
      valid: feasible,
      resource_gap: calculate_resource_gap(required, available)
    }
  end

  defp assess_future_impact(decision, _context) do
    # Simplified future impact assessment
    impact_score = Enum.random(60..95) / 100
    
    %{
      valid: impact_score > 0.5,
      score: impact_score,
      timeline: "6-12 months",
      risks: ["market_change", "technology_shift"]
    }
  end

  defp find_applicable_policies(decision, policies) do
    policies
    |> Map.values()
    |> Enum.filter(fn policy ->
      policy_applies_to_decision?(policy, decision)
    end)
  end

  defp policy_applies_to_decision?(policy, decision) do
    # Simplified check
    policy.scope == :all or policy.scope == decision.type
  end

  defp detect_violations(_decision, _policies) do
    # Simplified - randomly generate violations for demo
    if Enum.random(1..10) > 8, do: ["minor_violation"], else: []
  end

  defp calculate_resource_gap(required, available) do
    Map.new(required, fn {resource, amount} ->
      available_amount = Map.get(available, resource, 0)
      {resource, max(0, amount - available_amount)}
    end)
  end

  defp generate_recommendation(checks) do
    cond do
      not checks.identity_alignment.valid ->
        "Reconsider decision to better align with organizational identity"
      
      not checks.policy_compliance.valid ->
        "Address policy violations before proceeding"
      
      not checks.resource_feasibility.valid ->
        "Secure additional resources or scale down scope"
      
      checks.future_impact.score < 0.7 ->
        "Consider long-term implications more carefully"
      
      true ->
        "Decision appears sound - proceed with monitoring"
    end
  end

  defp calculate_validation_confidence(checks) do
    scores = [
      checks.identity_alignment[:score] || 0,
      (if checks.policy_compliance.valid, do: 1.0, else: 0.0),
      (if checks.resource_feasibility.valid, do: 1.0, else: 0.0),
      checks.future_impact.score
    ]
    
    Enum.sum(scores) / length(scores)
  end

  defp calculate_balance(present_needs, future_goals, state) do
    # Analyze urgency and importance
    present_urgency = analyze_urgency(present_needs)
    future_importance = analyze_importance(future_goals)
    
    # Current balance
    current_balance = state.balance_metrics
    
    # Calculate recommended weights
    total_weight = present_urgency + future_importance
    present_weight = present_urgency / total_weight
    future_weight = future_importance / total_weight
    
    %{
      present_weight: present_weight,
      future_weight: future_weight,
      adjustment_from_current: %{
        present: present_weight - current_balance.present_focus,
        future: future_weight - current_balance.future_focus
      },
      rationale: generate_balance_rationale(present_urgency, future_importance),
      specific_actions: generate_balance_actions(present_needs, future_goals)
    }
  end

  defp analyze_urgency(needs) do
    base_urgency = length(needs) * 0.1
    critical_bonus = Enum.count(needs, & &1[:priority] == :critical) * 0.3
    min(1.0, base_urgency + critical_bonus + 0.3)
  end

  defp analyze_importance(goals) do
    base_importance = length(goals) * 0.15
    strategic_bonus = Enum.count(goals, & &1[:strategic] == true) * 0.2
    min(1.0, base_importance + strategic_bonus + 0.4)
  end

  defp generate_balance_rationale(present_urgency, future_importance) do
    cond do
      present_urgency > future_importance * 1.5 ->
        "Immediate operational needs require increased present focus"
      
      future_importance > present_urgency * 1.5 ->
        "Strategic opportunities warrant increased future investment"
      
      true ->
        "Balanced approach recommended between present and future"
    end
  end

  defp generate_balance_actions(present_needs, future_goals) do
    present_actions = present_needs
      |> Enum.take(3)
      |> Enum.map(& "Address: #{&1[:description] || "present need"}")
    
    future_actions = future_goals
      |> Enum.take(3)
      |> Enum.map(& "Invest in: #{&1[:description] || "future goal"}")
    
    present_actions ++ future_actions
  end

  defp compile_health_report(state) do
    %{
      overall_score: calculate_overall_health(state),
      components: %{
        identity_clarity: assess_identity_clarity(state.identity),
        policy_coverage: assess_policy_coverage(state.policies),
        decision_quality: assess_decision_quality(state.decision_history),
        balance_health: assess_balance_health(state.balance_metrics)
      },
      recommendations: generate_health_recommendations(state),
      last_review: DateTime.utc_now()
    }
  end

  defp assess_system_health(state) do
    compile_health_report(state)
  end

  defp calculate_overall_health(state) do
    scores = [
      assess_identity_clarity(state.identity),
      assess_policy_coverage(state.policies),
      assess_decision_quality(state.decision_history),
      assess_balance_health(state.balance_metrics)
    ]
    
    Enum.sum(scores) / length(scores)
  end

  defp assess_identity_clarity(identity) do
    # Check completeness of identity elements
    elements = [:mission, :vision, :values, :purpose]
    present = Enum.count(elements, &Map.has_key?(identity, &1))
    present / length(elements)
  end

  defp assess_policy_coverage(policies) do
    # Check coverage of key policy areas
    key_areas = [:strategic, :operational, :resource, :quality, :risk]
    covered = Enum.count(key_areas, &Map.has_key?(policies, &1))
    covered / length(key_areas)
  end

  defp assess_decision_quality(history) do
    if Enum.empty?(history) do
      0.5  # No history, neutral score
    else
      recent = Enum.take(history, 20)
      valid_count = Enum.count(recent, & &1.validation.valid)
      valid_count / length(recent)
    end
  end

  defp assess_balance_health(metrics) do
    # Check if balance is too skewed
    max_skew = max(metrics.present_focus, metrics.future_focus)
    if max_skew > 0.8, do: 0.6, else: 0.9
  end

  defp generate_health_recommendations(state) do
    recommendations = []
    
    recommendations = if map_size(state.policies) < 3 do
      ["Define more comprehensive policies" | recommendations]
    else
      recommendations
    end
    
    recommendations = if length(state.decision_history) < 10 do
      ["Increase decision tracking for better insights" | recommendations]
    else
      recommendations
    end
    
    recommendations = if abs(state.balance_metrics.present_focus - 0.5) > 0.3 do
      ["Review present/future balance" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end

  defp default_values do
    [:integrity, :adaptability, :sustainability, :innovation, :collaboration]
  end

  defp default_policies do
    %{
      strategic: %{
        type: :strategic,
        scope: :all,
        rules: ["align_with_mission", "ensure_sustainability", "promote_innovation"],
        priority: :high
      },
      operational: %{
        type: :operational,
        scope: :operational,
        rules: ["optimize_efficiency", "maintain_quality", "ensure_reliability"],
        priority: :medium
      },
      resource: %{
        type: :resource,
        scope: :all,
        rules: ["responsible_allocation", "avoid_waste", "plan_capacity"],
        priority: :high
      }
    }
  end

  defp default_constraints do
    %{
      resources: %{
        budget: 1_000_000,
        personnel: 100,
        time_horizon: 365,  # days
        risk_tolerance: 0.3
      },
      boundaries: %{
        geographic: :global,
        regulatory: :compliant,
        ethical: :required
      }
    }
  end
end