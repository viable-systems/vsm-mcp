defmodule VsmMcp.ConsciousnessInterface.DecisionTracing do
  @moduledoc """
  Decision Tracing Module - Full decision lineage and rationale storage
  
  This module provides comprehensive tracing of:
  - Decision context and triggers
  - Alternative options considered
  - Evaluation criteria applied
  - Rationale for final choice
  - Confidence levels and uncertainty
  - Causal chains and dependencies
  - Post-decision outcomes
  
  Every decision becomes a learning opportunity through complete traceability.
  """
  
  use GenServer
  require Logger
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def trace(pid, decision, rationale, context) do
    GenServer.call(pid, {:trace_decision, decision, rationale, context})
  end
  
  def get_decision_history(pid, decision_id) do
    GenServer.call(pid, {:get_history, decision_id})
  end
  
  def analyze_patterns(pid) do
    GenServer.call(pid, :analyze_patterns)
  end
  
  def get_recent(pid, count) do
    GenServer.call(pid, {:get_recent, count})
  end
  
  def get_summary(pid) do
    GenServer.call(pid, :get_summary)
  end
  
  def link_outcome(pid, decision_id, outcome) do
    GenServer.cast(pid, {:link_outcome, decision_id, outcome})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      # Decision storage
      decisions: %{},
      decision_sequence: [],
      
      # Pattern analysis
      decision_patterns: %{
        by_type: %{},
        by_context: %{},
        by_outcome: %{},
        temporal: []
      },
      
      # Causal tracking
      causal_graph: %{},
      dependency_map: %{},
      
      # Decision quality metrics
      quality_metrics: %{
        total_decisions: 0,
        successful_outcomes: 0,
        failed_outcomes: 0,
        pending_outcomes: 0,
        average_confidence: 0.0,
        rationale_completeness: 0.0
      },
      
      # Learning insights
      decision_insights: [],
      improvement_suggestions: []
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:trace_decision, decision, rationale, context}, _from, state) do
    # Generate unique decision ID
    decision_id = generate_decision_id()
    
    # Create comprehensive decision trace
    trace = create_decision_trace(decision_id, decision, rationale, context, state)
    
    # Update state with new trace
    new_state = state
    |> store_decision_trace(trace)
    |> update_decision_patterns(trace)
    |> update_causal_relationships(trace)
    |> update_quality_metrics(trace)
    
    {:reply, trace, new_state}
  end
  
  @impl true
  def handle_call({:get_history, decision_id}, _from, state) do
    case Map.get(state.decisions, decision_id) do
      nil -> {:reply, {:error, :not_found}, state}
      decision -> {:reply, {:ok, compile_decision_history(decision, state)}, state}
    end
  end
  
  @impl true
  def handle_call(:analyze_patterns, _from, state) do
    analysis = perform_pattern_analysis(state)
    
    # Generate new insights from analysis
    new_insights = extract_insights_from_patterns(analysis)
    new_state = Map.update!(state, :decision_insights, &(new_insights ++ &1))
    
    {:reply, analysis, new_state}
  end
  
  @impl true
  def handle_call({:get_recent, count}, _from, state) do
    recent = state.decision_sequence
    |> Enum.take(count)
    |> Enum.map(&Map.get(state.decisions, &1))
    |> Enum.filter(&(&1 != nil))
    
    {:reply, recent, state}
  end
  
  @impl true
  def handle_call(:get_summary, _from, state) do
    summary = compile_decision_summary(state)
    {:reply, summary, state}
  end
  
  @impl true
  def handle_cast({:link_outcome, decision_id, outcome}, state) do
    new_state = case Map.get(state.decisions, decision_id) do
      nil -> 
        state
        
      decision ->
        # Update decision with outcome
        updated_decision = link_decision_outcome(decision, outcome)
        
        # Update metrics based on outcome
        state
        |> put_in([:decisions, decision_id], updated_decision)
        |> update_outcome_metrics(outcome)
        |> learn_from_outcome(updated_decision)
    end
    
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp generate_decision_id do
    "decision_#{System.unique_integer([:positive, :monotonic])}_#{System.system_time(:microsecond)}"
  end
  
  defp create_decision_trace(decision_id, decision, rationale, context, state) do
    %{
      # Identity
      id: decision_id,
      timestamp: DateTime.utc_now(),
      
      # Decision details
      decision: %{
        type: decision[:type] || :general,
        action: decision.action,
        parameters: decision[:parameters] || %{},
        constraints: decision[:constraints] || []
      },
      
      # Context
      context: %{
        trigger: context[:trigger] || :unknown,
        environment: capture_environment_state(context),
        active_goals: context[:goals] || [],
        resource_state: context[:resources] || %{},
        time_pressure: context[:time_pressure] || :normal
      },
      
      # Alternatives considered
      alternatives: trace_alternatives(decision, context),
      
      # Evaluation process
      evaluation: %{
        criteria: extract_evaluation_criteria(rationale),
        weights: extract_criteria_weights(rationale),
        scores: calculate_alternative_scores(decision, rationale)
      },
      
      # Rationale
      rationale: %{
        primary_reason: rationale[:primary] || "Not specified",
        supporting_reasons: rationale[:supporting] || [],
        trade_offs: rationale[:trade_offs] || [],
        assumptions: rationale[:assumptions] || [],
        risks_accepted: rationale[:risks] || []
      },
      
      # Confidence and uncertainty
      confidence: %{
        level: rationale[:confidence] || estimate_confidence(decision, context),
        factors: identify_confidence_factors(decision, rationale, context),
        uncertainties: identify_uncertainties(decision, context)
      },
      
      # Causal relationships
      causality: %{
        triggered_by: identify_triggers(context, state),
        depends_on: identify_dependencies(decision, state),
        may_influence: predict_influences(decision, state)
      },
      
      # Outcome tracking
      outcome: %{
        status: :pending,
        expected: decision[:expected_outcome] || nil,
        actual: nil,
        variance: nil
      }
    }
  end
  
  defp capture_environment_state(context) do
    %{
      system_load: context[:system_load] || :normal,
      active_processes: context[:active_processes] || [],
      external_factors: context[:external_factors] || [],
      constraints_active: context[:constraints] || []
    }
  end
  
  defp trace_alternatives(decision, context) do
    # Extract alternatives that were considered
    alternatives = decision[:alternatives] || []
    
    if Enum.empty?(alternatives) do
      generate_implicit_alternatives(decision, context)
    else
      Enum.map(alternatives, fn alt ->
        %{
          action: alt.action,
          pros: alt[:pros] || [],
          cons: alt[:cons] || [],
          feasibility: alt[:feasibility] || :unknown,
          rejected_because: alt[:rejected_because] || "Not selected"
        }
      end)
    end
  end
  
  defp generate_implicit_alternatives(decision, _context) do
    # Generate obvious alternatives if none were explicitly provided
    [
      %{
        action: "Do nothing",
        pros: ["No resource cost", "No risk"],
        cons: ["Problem remains", "Opportunity cost"],
        feasibility: :high,
        rejected_because: "Action deemed necessary"
      },
      %{
        action: "Delay decision",
        pros: ["More information might become available"],
        cons: ["Time pressure", "Delayed benefits"],
        feasibility: :medium,
        rejected_because: "Timing constraints"
      }
    ]
  end
  
  defp extract_evaluation_criteria(rationale) do
    # Extract decision criteria from rationale
    default_criteria = [:effectiveness, :efficiency, :risk, :cost]
    
    explicit_criteria = rationale[:criteria] || []
    
    (default_criteria ++ explicit_criteria) |> Enum.uniq()
  end
  
  defp extract_criteria_weights(rationale) do
    # Extract or infer weights for criteria
    weights = rationale[:weights] || %{}
    
    # Apply defaults for missing weights
    %{
      effectiveness: weights[:effectiveness] || 0.3,
      efficiency: weights[:efficiency] || 0.2,
      risk: weights[:risk] || 0.3,
      cost: weights[:cost] || 0.2
    }
    |> Map.merge(weights)
  end
  
  defp calculate_alternative_scores(_decision, _rationale) do
    # Calculate scores for each alternative
    # Simplified for now
    %{
      selected: 0.8,
      alternatives: %{
        "Do nothing" => 0.2,
        "Delay decision" => 0.4
      }
    }
  end
  
  defp estimate_confidence(decision, context) do
    # Estimate confidence level if not explicitly provided
    base_confidence = 0.7
    
    # Adjust based on factors
    time_pressure_penalty = case context[:time_pressure] do
      :high -> -0.2
      :critical -> -0.3
      _ -> 0
    end
    
    complexity_penalty = case decision[:complexity] do
      :high -> -0.1
      :very_high -> -0.2
      _ -> 0
    end
    
    max(0.1, min(1.0, base_confidence + time_pressure_penalty + complexity_penalty))
  end
  
  defp identify_confidence_factors(decision, rationale, context) do
    factors = []
    
    factors = if rationale[:evidence] do
      [{:positive, "Evidence-based decision"} | factors]
    else
      factors
    end
    
    factors = if context[:time_pressure] == :high do
      [{:negative, "High time pressure"} | factors]
    else
      factors
    end
    
    factors = if length(decision[:alternatives] || []) > 2 do
      [{:positive, "Multiple alternatives considered"} | factors]
    else
      factors
    end
    
    factors
  end
  
  defp identify_uncertainties(decision, context) do
    uncertainties = []
    
    uncertainties = if context[:incomplete_information] do
      ["Incomplete information available" | uncertainties]
    else
      uncertainties
    end
    
    uncertainties = if decision[:assumptions] && length(decision[:assumptions]) > 0 do
      ["Decision based on assumptions: #{inspect(decision[:assumptions])}" | uncertainties]
    else
      uncertainties
    end
    
    uncertainties
  end
  
  defp identify_triggers(context, state) do
    # Identify what triggered this decision
    recent_decisions = Enum.take(state.decision_sequence, 5)
    
    triggers = []
    
    triggers = if context[:triggered_by] do
      [context[:triggered_by] | triggers]
    else
      triggers
    end
    
    # Check if recent decisions might have triggered this one
    related = Enum.filter(recent_decisions, fn prev_id ->
      prev = Map.get(state.decisions, prev_id)
      prev && might_trigger?(prev, context)
    end)
    
    triggers ++ related
  end
  
  defp might_trigger?(previous_decision, current_context) do
    # Simple heuristic to detect potential triggers
    previous_decision.decision.type == current_context[:trigger]
  end
  
  defp identify_dependencies(decision, state) do
    # Identify decisions this one depends on
    explicit_deps = decision[:depends_on] || []
    
    # Infer implicit dependencies
    implicit_deps = infer_dependencies(decision, state)
    
    Enum.uniq(explicit_deps ++ implicit_deps)
  end
  
  defp infer_dependencies(decision, state) do
    # Infer dependencies based on decision type and context
    state.decision_sequence
    |> Enum.take(10)
    |> Enum.filter(fn prev_id ->
      prev = Map.get(state.decisions, prev_id)
      prev && shares_context?(prev, decision)
    end)
  end
  
  defp shares_context?(decision1, decision2) do
    # Check if decisions share context
    decision1.decision.type == decision2[:type]
  end
  
  defp predict_influences(decision, _state) do
    # Predict what this decision might influence
    case decision[:type] do
      :strategic -> [:future_strategic_decisions, :resource_allocation]
      :operational -> [:immediate_operations, :performance_metrics]
      :tactical -> [:short_term_goals, :team_coordination]
      _ -> [:general_system_state]
    end
  end
  
  defp store_decision_trace(state, trace) do
    state
    |> put_in([:decisions, trace.id], trace)
    |> update_in([:decision_sequence], &[trace.id | &1])
  end
  
  defp update_decision_patterns(state, trace) do
    state
    |> update_in([:decision_patterns, :by_type, trace.decision.type], 
                 &increment_pattern_count/1)
    |> update_in([:decision_patterns, :by_context, trace.context.trigger], 
                 &increment_pattern_count/1)
    |> update_in([:decision_patterns, :temporal], 
                 &add_temporal_pattern(&1, trace))
  end
  
  defp increment_pattern_count(nil), do: 1
  defp increment_pattern_count(count), do: count + 1
  
  defp add_temporal_pattern(temporal_patterns, trace) do
    pattern = %{
      timestamp: trace.timestamp,
      type: trace.decision.type,
      confidence: trace.confidence.level
    }
    
    [pattern | temporal_patterns] |> Enum.take(100)
  end
  
  defp update_causal_relationships(state, trace) do
    # Update causal graph
    new_causal = Enum.reduce(trace.causality.triggered_by, state.causal_graph, fn trigger, graph ->
      Map.update(graph, trigger, [trace.id], &[trace.id | &1])
    end)
    
    # Update dependency map
    new_deps = Enum.reduce(trace.causality.depends_on, state.dependency_map, fn dep, map ->
      Map.update(map, trace.id, [dep], &[dep | &1])
    end)
    
    state
    |> Map.put(:causal_graph, new_causal)
    |> Map.put(:dependency_map, new_deps)
  end
  
  defp update_quality_metrics(state, trace) do
    metrics = state.quality_metrics
    
    new_total = metrics.total_decisions + 1
    new_avg_confidence = update_running_average(
      metrics.average_confidence,
      trace.confidence.level,
      metrics.total_decisions
    )
    
    completeness = calculate_rationale_completeness(trace.rationale)
    new_completeness = update_running_average(
      metrics.rationale_completeness,
      completeness,
      metrics.total_decisions
    )
    
    new_metrics = %{metrics |
      total_decisions: new_total,
      pending_outcomes: metrics.pending_outcomes + 1,
      average_confidence: new_avg_confidence,
      rationale_completeness: new_completeness
    }
    
    Map.put(state, :quality_metrics, new_metrics)
  end
  
  defp update_running_average(current_avg, new_value, count) do
    (current_avg * count + new_value) / (count + 1)
  end
  
  defp calculate_rationale_completeness(rationale) do
    fields = [
      rationale.primary_reason != "Not specified",
      length(rationale.supporting_reasons) > 0,
      length(rationale.assumptions) > 0,
      length(rationale.trade_offs) > 0
    ]
    
    Enum.count(fields, & &1) / length(fields)
  end
  
  defp compile_decision_history(decision, state) do
    %{
      decision: decision,
      
      # Causal chain
      causal_chain: build_causal_chain(decision.id, state),
      
      # Related decisions
      related_decisions: find_related_decisions(decision, state),
      
      # Pattern context
      pattern_frequency: get_pattern_frequency(decision, state),
      
      # Quality assessment
      quality_score: assess_decision_quality(decision)
    }
  end
  
  defp build_causal_chain(decision_id, state) do
    # Build the causal chain for this decision
    build_chain_recursive(decision_id, state, [], 0)
  end
  
  defp build_chain_recursive(_, _, chain, depth) when depth > 5, do: chain
  defp build_chain_recursive(decision_id, state, chain, depth) do
    case Map.get(state.decisions, decision_id) do
      nil -> chain
      decision ->
        triggers = decision.causality.triggered_by
        
        if Enum.empty?(triggers) do
          [{decision_id, :root} | chain]
        else
          Enum.reduce(triggers, chain, fn trigger, acc ->
            build_chain_recursive(trigger, state, [{decision_id, trigger} | acc], depth + 1)
          end)
        end
    end
  end
  
  defp find_related_decisions(decision, state) do
    # Find decisions related by type, context, or causality
    state.decision_sequence
    |> Enum.take(20)
    |> Enum.map(&Map.get(state.decisions, &1))
    |> Enum.filter(& &1 != nil)
    |> Enum.filter(& is_related?(&1, decision))
    |> Enum.map(& &1.id)
  end
  
  defp is_related?(decision1, decision2) do
    decision1.id != decision2.id && (
      decision1.decision.type == decision2.decision.type ||
      decision1.context.trigger == decision2.context.trigger ||
      decision1.id in decision2.causality.depends_on ||
      decision2.id in decision1.causality.depends_on
    )
  end
  
  defp get_pattern_frequency(decision, state) do
    %{
      type_frequency: Map.get(state.decision_patterns.by_type, decision.decision.type, 0),
      context_frequency: Map.get(state.decision_patterns.by_context, decision.context.trigger, 0)
    }
  end
  
  defp assess_decision_quality(decision) do
    factors = [
      decision.confidence.level,
      calculate_rationale_completeness(decision.rationale),
      length(decision.alternatives) / 5,  # More alternatives is better
      1.0 - (length(decision.confidence.uncertainties) / 5)  # Fewer uncertainties is better
    ]
    
    Enum.sum(factors) / length(factors)
  end
  
  defp perform_pattern_analysis(state) do
    %{
      # Type patterns
      dominant_decision_types: analyze_dominant_types(state.decision_patterns.by_type),
      
      # Context patterns
      common_triggers: analyze_common_triggers(state.decision_patterns.by_context),
      
      # Temporal patterns
      decision_frequency: analyze_temporal_frequency(state.decision_patterns.temporal),
      confidence_trend: analyze_confidence_trend(state.decision_patterns.temporal),
      
      # Causal patterns
      causal_hotspots: identify_causal_hotspots(state.causal_graph),
      dependency_clusters: identify_dependency_clusters(state.dependency_map),
      
      # Quality patterns
      quality_trends: analyze_quality_trends(state),
      
      # Success patterns
      success_factors: identify_success_factors(state)
    }
  end
  
  defp analyze_dominant_types(by_type) do
    by_type
    |> Enum.sort_by(fn {_, count} -> -count end)
    |> Enum.take(3)
    |> Enum.map(fn {type, count} -> 
      %{type: type, count: count, percentage: count / total_count(by_type)}
    end)
  end
  
  defp total_count(map) do
    map |> Map.values() |> Enum.sum() |> max(1)
  end
  
  defp analyze_common_triggers(by_context) do
    by_context
    |> Enum.sort_by(fn {_, count} -> -count end)
    |> Enum.take(5)
  end
  
  defp analyze_temporal_frequency(temporal_patterns) do
    if length(temporal_patterns) < 2 do
      :insufficient_data
    else
      # Calculate decision frequency over time
      time_span = calculate_time_span(temporal_patterns)
      count = length(temporal_patterns)
      
      %{
        decisions_per_hour: count / max(time_span, 1),
        trend: detect_frequency_trend(temporal_patterns)
      }
    end
  end
  
  defp calculate_time_span(patterns) do
    if Enum.empty?(patterns) do
      0
    else
      oldest = List.last(patterns).timestamp
      newest = List.first(patterns).timestamp
      
      DateTime.diff(newest, oldest, :hour)
    end
  end
  
  defp detect_frequency_trend(patterns) do
    # Detect if decision frequency is increasing or decreasing
    :stable  # Simplified
  end
  
  defp analyze_confidence_trend(temporal_patterns) do
    confidences = Enum.map(temporal_patterns, & &1.confidence)
    
    if length(confidences) < 5 do
      :insufficient_data
    else
      recent = Enum.take(confidences, 10)
      older = Enum.slice(confidences, 10, 10)
      
      recent_avg = Enum.sum(recent) / length(recent)
      older_avg = if Enum.empty?(older), do: recent_avg, else: Enum.sum(older) / length(older)
      
      cond do
        recent_avg > older_avg + 0.1 -> :improving
        recent_avg < older_avg - 0.1 -> :declining
        true -> :stable
      end
    end
  end
  
  defp identify_causal_hotspots(causal_graph) do
    # Find decisions that trigger many others
    causal_graph
    |> Enum.map(fn {trigger, triggered} -> 
      %{trigger: trigger, influence_count: length(triggered)}
    end)
    |> Enum.sort_by(& -&1.influence_count)
    |> Enum.take(3)
  end
  
  defp identify_dependency_clusters(dependency_map) do
    # Find groups of interdependent decisions
    # Simplified - just count dependencies
    dependency_map
    |> Enum.map(fn {decision, deps} ->
      %{decision: decision, dependency_count: length(deps)}
    end)
    |> Enum.sort_by(& -&1.dependency_count)
    |> Enum.take(3)
  end
  
  defp analyze_quality_trends(state) do
    %{
      average_confidence: state.quality_metrics.average_confidence,
      rationale_completeness: state.quality_metrics.rationale_completeness,
      success_rate: calculate_success_rate(state.quality_metrics)
    }
  end
  
  defp calculate_success_rate(metrics) do
    total_outcomes = metrics.successful_outcomes + metrics.failed_outcomes
    
    if total_outcomes > 0 do
      metrics.successful_outcomes / total_outcomes
    else
      :no_outcomes_yet
    end
  end
  
  defp identify_success_factors(state) do
    # Analyze what factors correlate with successful outcomes
    successful_decisions = state.decisions
    |> Map.values()
    |> Enum.filter(& &1.outcome.status == :success)
    
    if length(successful_decisions) < 5 do
      :insufficient_data
    else
      %{
        average_confidence: calculate_average_confidence(successful_decisions),
        common_types: find_common_types(successful_decisions),
        typical_rationale_completeness: calculate_average_completeness(successful_decisions)
      }
    end
  end
  
  defp calculate_average_confidence(decisions) do
    confidences = Enum.map(decisions, & &1.confidence.level)
    Enum.sum(confidences) / max(length(confidences), 1)
  end
  
  defp find_common_types(decisions) do
    decisions
    |> Enum.map(& &1.decision.type)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> -count end)
    |> Enum.take(3)
  end
  
  defp calculate_average_completeness(decisions) do
    completenesses = Enum.map(decisions, & calculate_rationale_completeness(&1.rationale))
    Enum.sum(completenesses) / max(length(completenesses), 1)
  end
  
  defp extract_insights_from_patterns(analysis) do
    insights = []
    
    # Check for low confidence trend
    insights = case analysis.confidence_trend do
      :declining -> 
        [%{
          type: :confidence_decline,
          message: "Decision confidence is declining - consider more thorough analysis",
          severity: :medium
        } | insights]
      _ -> insights
    end
    
    # Check for over-reliance on specific decision types
    insights = if length(analysis.dominant_decision_types) > 0 && 
                  hd(analysis.dominant_decision_types).percentage > 0.5 do
      [%{
        type: :decision_type_bias,
        message: "Over-reliance on #{hd(analysis.dominant_decision_types).type} decisions",
        severity: :low
      } | insights]
    else
      insights
    end
    
    insights
  end
  
  defp compile_decision_summary(state) do
    %{
      total_decisions: state.quality_metrics.total_decisions,
      quality_metrics: state.quality_metrics,
      recent_insights: Enum.take(state.decision_insights, 5),
      pattern_summary: summarize_patterns(state.decision_patterns),
      recommendations: generate_decision_recommendations(state)
    }
  end
  
  defp summarize_patterns(patterns) do
    %{
      most_common_type: find_most_common(patterns.by_type),
      most_common_trigger: find_most_common(patterns.by_context),
      total_unique_types: map_size(patterns.by_type),
      total_unique_triggers: map_size(patterns.by_context)
    }
  end
  
  defp find_most_common(frequency_map) do
    if map_size(frequency_map) == 0 do
      :none
    else
      {type, _} = Enum.max_by(frequency_map, fn {_, count} -> count end)
      type
    end
  end
  
  defp generate_decision_recommendations(state) do
    recommendations = []
    
    # Check decision quality
    recommendations = if state.quality_metrics.average_confidence < 0.6 do
      ["Improve decision confidence through better analysis" | recommendations]
    else
      recommendations
    end
    
    recommendations = if state.quality_metrics.rationale_completeness < 0.5 do
      ["Document decision rationales more thoroughly" | recommendations]
    else
      recommendations
    end
    
    # Check for improvement opportunities
    recommendations = if length(state.improvement_suggestions) > 0 do
      recommendations ++ Enum.take(state.improvement_suggestions, 2)
    else
      recommendations
    end
    
    recommendations
  end
  
  defp link_decision_outcome(decision, outcome) do
    %{decision |
      outcome: %{
        status: outcome.status,
        expected: decision.outcome.expected,
        actual: outcome.result,
        variance: calculate_outcome_variance(decision.outcome.expected, outcome.result)
      }
    }
  end
  
  defp calculate_outcome_variance(nil, _), do: :not_applicable
  defp calculate_outcome_variance(_, nil), do: :not_measured
  defp calculate_outcome_variance(expected, actual) do
    # Calculate variance between expected and actual
    if is_number(expected) && is_number(actual) do
      abs(expected - actual) / max(expected, 1)
    else
      :qualitative_difference
    end
  end
  
  defp update_outcome_metrics(state, outcome) do
    metrics = state.quality_metrics
    
    new_metrics = case outcome.status do
      :success ->
        %{metrics |
          successful_outcomes: metrics.successful_outcomes + 1,
          pending_outcomes: max(0, metrics.pending_outcomes - 1)
        }
        
      :failure ->
        %{metrics |
          failed_outcomes: metrics.failed_outcomes + 1,
          pending_outcomes: max(0, metrics.pending_outcomes - 1)
        }
        
      _ ->
        metrics
    end
    
    Map.put(state, :quality_metrics, new_metrics)
  end
  
  defp learn_from_outcome(state, decision) do
    # Extract learning from the outcome
    learning = analyze_outcome_variance(decision)
    
    # Update improvement suggestions based on learning
    suggestions = generate_improvement_suggestions(learning)
    
    Map.update!(state, :improvement_suggestions, &(suggestions ++ &1))
  end
  
  defp analyze_outcome_variance(decision) do
    %{
      outcome_matched_expectation: decision.outcome.status == :success,
      confidence_was_justified: confidence_justified?(decision),
      rationale_held: rationale_validated?(decision),
      unexpected_factors: identify_unexpected_factors(decision)
    }
  end
  
  defp confidence_justified?(decision) do
    decision.outcome.status == :success && decision.confidence.level > 0.7 ||
    decision.outcome.status == :failure && decision.confidence.level < 0.5
  end
  
  defp rationale_validated?(decision) do
    # Check if the rationale proved correct
    decision.outcome.variance == :not_applicable || 
    (is_number(decision.outcome.variance) && decision.outcome.variance < 0.2)
  end
  
  defp identify_unexpected_factors(decision) do
    # Identify factors that weren't anticipated
    if decision.outcome.status == :failure && decision.confidence.level > 0.7 do
      ["High confidence failure - missing factors in analysis"]
    else
      []
    end
  end
  
  defp generate_improvement_suggestions(learning) do
    suggestions = []
    
    suggestions = if not learning.confidence_was_justified do
      ["Calibrate confidence estimates based on historical accuracy" | suggestions]
    else
      suggestions
    end
    
    suggestions = if length(learning.unexpected_factors) > 0 do
      ["Consider wider range of factors in decision analysis" | suggestions]
    else
      suggestions
    end
    
    suggestions
  end
end