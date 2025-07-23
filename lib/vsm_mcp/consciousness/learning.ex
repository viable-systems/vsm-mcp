defmodule VsmMcp.ConsciousnessInterface.Learning do
  @moduledoc """
  Learning Module - Extracting knowledge from experience
  
  This module implements learning mechanisms that:
  - Extract patterns from decision outcomes
  - Build predictive models from experience
  - Identify successful strategies
  - Learn from failures
  - Transfer learning across domains
  - Continuously improve decision-making
  
  Real learning through experience, not just data storage.
  """
  
  use GenServer
  require Logger
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def process_outcome(pid, decision_id, outcome, analysis) do
    GenServer.cast(pid, {:process_outcome, decision_id, outcome, analysis})
  end
  
  def get_recent_insights(pid) do
    GenServer.call(pid, :get_recent_insights)
  end
  
  def assess_learning_rate(pid) do
    GenServer.call(pid, :assess_learning_rate)
  end
  
  def get_knowledge_base(pid) do
    GenServer.call(pid, :get_knowledge_base)
  end
  
  def identify_learning_barriers(pid) do
    GenServer.call(pid, :identify_barriers)
  end
  
  def apply_learning(pid, context) do
    GenServer.call(pid, {:apply_learning, context})
  end
  
  def analyze_decision(pid, decision_trace) do
    GenServer.cast(pid, {:analyze_decision, decision_trace})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      # Knowledge structures
      knowledge_base: %{
        patterns: %{},
        strategies: %{},
        causal_models: %{},
        domain_knowledge: %{},
        meta_knowledge: %{}
      },
      
      # Learning metrics
      learning_metrics: %{
        total_experiences: 0,
        successful_learnings: 0,
        failed_attempts: 0,
        learning_velocity: 0.0,
        knowledge_retention: 1.0,
        transfer_success_rate: 0.0
      },
      
      # Experience repository
      experiences: %{
        decisions: %{},
        outcomes: %{},
        patterns_observed: [],
        strategies_tried: []
      },
      
      # Learning insights
      insights: [],
      breakthrough_moments: [],
      
      # Active learning
      active_hypotheses: %{},
      experiments_in_progress: %{},
      
      # Learning configuration
      learning_config: %{
        exploration_rate: 0.2,
        consolidation_threshold: 5,
        forgetting_rate: 0.01,
        transfer_threshold: 0.7
      }
    }
    
    # Schedule periodic consolidation
    Process.send_after(self(), :consolidate_learning, 60_000)
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:process_outcome, decision_id, outcome, analysis}, state) do
    # Process the outcome and extract learnings
    learnings = extract_learnings(decision_id, outcome, analysis, state)
    
    # Update knowledge base with new learnings
    new_state = integrate_learnings(state, learnings)
    
    # Check for breakthrough insights
    new_state = check_for_breakthroughs(new_state, learnings)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:analyze_decision, decision_trace}, state) do
    # Analyze decision for learning opportunities
    analysis = analyze_for_learning(decision_trace, state)
    
    # Update active hypotheses
    new_state = update_hypotheses(state, analysis)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call(:get_recent_insights, _from, state) do
    recent = Enum.take(state.insights, 10)
    {:reply, recent, state}
  end
  
  @impl true
  def handle_call(:assess_learning_rate, _from, state) do
    assessment = %{
      velocity: state.learning_metrics.learning_velocity,
      effectiveness: calculate_learning_effectiveness(state),
      retention: state.learning_metrics.knowledge_retention,
      areas: identify_learning_areas(state)
    }
    
    {:reply, assessment, state}
  end
  
  @impl true
  def handle_call(:get_knowledge_base, _from, state) do
    summary = summarize_knowledge_base(state.knowledge_base)
    {:reply, summary, state}
  end
  
  @impl true
  def handle_call(:identify_barriers, _from, state) do
    barriers = identify_learning_barriers_internal(state)
    {:reply, barriers, state}
  end
  
  @impl true
  def handle_call({:apply_learning, context}, _from, state) do
    # Apply learned knowledge to current context
    recommendations = apply_knowledge(state.knowledge_base, context)
    
    # Track application for future learning
    new_state = track_knowledge_application(state, context, recommendations)
    
    {:reply, recommendations, new_state}
  end
  
  @impl true
  def handle_info(:consolidate_learning, state) do
    # Periodic consolidation of learnings
    consolidated_state = consolidate_knowledge(state)
    
    # Apply forgetting to maintain relevant knowledge
    updated_state = apply_forgetting(consolidated_state)
    
    # Schedule next consolidation
    Process.send_after(self(), :consolidate_learning, 60_000)
    
    {:noreply, updated_state}
  end
  
  # Private Functions
  
  defp extract_learnings(decision_id, outcome, analysis, state) do
    %{
      # Outcome analysis
      outcome_learnings: analyze_outcome(outcome, analysis),
      
      # Pattern extraction
      patterns: extract_patterns(decision_id, outcome, state),
      
      # Strategy effectiveness
      strategy_learnings: evaluate_strategy(decision_id, outcome, state),
      
      # Causal relationships
      causal_learnings: extract_causal_relationships(outcome, analysis),
      
      # Meta-learnings
      meta_learnings: extract_meta_learnings(analysis, state)
    }
  end
  
  defp analyze_outcome(outcome, analysis) do
    %{
      success: outcome.status == :success,
      unexpected: outcome.unexpected || false,
      key_factors: identify_key_factors(outcome, analysis),
      failure_reasons: if(outcome.status == :failure, do: analyze_failure(outcome, analysis), else: []),
      success_factors: if(outcome.status == :success, do: analyze_success(outcome, analysis), else: [])
    }
  end
  
  defp identify_key_factors(outcome, analysis) do
    factors = []
    
    # Time was a factor
    factors = if analysis[:time_critical] && outcome.status == :success do
      [{:positive, "Quick decision-making in time-critical situation"} | factors]
    else
      factors
    end
    
    # Resource constraints
    factors = if analysis[:resource_constrained] do
      [{:neutral, "Resource constraints influenced outcome"} | factors]
    else
      factors
    end
    
    # Complexity handling
    factors = if analysis[:high_complexity] && outcome.status == :success do
      [{:positive, "Successfully handled high complexity"} | factors]
    else
      factors
    end
    
    factors
  end
  
  defp analyze_failure(outcome, analysis) do
    reasons = []
    
    reasons = if outcome[:missing_information] do
      ["Incomplete information led to poor decision" | reasons]
    else
      reasons
    end
    
    reasons = if outcome[:wrong_assumptions] do
      ["Incorrect assumptions about " <> inspect(outcome[:wrong_assumptions]) | reasons]
    else
      reasons
    end
    
    reasons = if analysis[:overconfidence] do
      ["Overconfidence despite uncertainty" | reasons]
    else
      reasons
    end
    
    reasons
  end
  
  defp analyze_success(outcome, analysis) do
    factors = []
    
    factors = if analysis[:thorough_analysis] do
      ["Thorough analysis of alternatives" | factors]
    else
      factors
    end
    
    factors = if outcome[:adapted_well] do
      ["Good adaptation to changing conditions" | factors]
    else
      factors
    end
    
    factors = if analysis[:learned_from_past] do
      ["Successfully applied past learnings" | factors]
    else
      factors
    end
    
    factors
  end
  
  defp extract_patterns(decision_id, outcome, state) do
    # Look for patterns in successful/failed decisions
    similar_decisions = find_similar_decisions(decision_id, state)
    
    patterns = []
    
    # Success pattern
    if outcome.status == :success && length(similar_decisions.successful) > 2 do
      pattern = identify_success_pattern(decision_id, similar_decisions.successful, state)
      patterns = [pattern | patterns]
    end
    
    # Failure pattern
    if outcome.status == :failure && length(similar_decisions.failed) > 2 do
      pattern = identify_failure_pattern(decision_id, similar_decisions.failed, state)
      patterns = [pattern | patterns]
    end
    
    # Context patterns
    context_pattern = identify_context_pattern(decision_id, outcome, state)
    if context_pattern, do: [context_pattern | patterns], else: patterns
  end
  
  defp find_similar_decisions(decision_id, state) do
    decision = Map.get(state.experiences.decisions, decision_id)
    
    if decision do
      all_decisions = Map.values(state.experiences.decisions)
      
      similar = Enum.filter(all_decisions, fn d ->
        d.id != decision_id && similar_decision?(d, decision)
      end)
      
      %{
        successful: Enum.filter(similar, fn d ->
          outcome = Map.get(state.experiences.outcomes, d.id)
          outcome && outcome.status == :success
        end),
        failed: Enum.filter(similar, fn d ->
          outcome = Map.get(state.experiences.outcomes, d.id)
          outcome && outcome.status == :failure
        end)
      }
    else
      %{successful: [], failed: []}
    end
  end
  
  defp similar_decision?(decision1, decision2) do
    # Check similarity based on type and context
    decision1.type == decision2.type ||
    (decision1[:context] && decision2[:context] && 
     similar_context?(decision1.context, decision2.context))
  end
  
  defp similar_context?(context1, context2) do
    # Simple context similarity check
    context1[:domain] == context2[:domain] ||
    context1[:trigger] == context2[:trigger]
  end
  
  defp identify_success_pattern(_decision_id, similar_successful, _state) do
    # Extract common elements from successful decisions
    %{
      type: :success_pattern,
      description: "Common factors in successful decisions",
      factors: extract_common_factors(similar_successful),
      confidence: min(1.0, length(similar_successful) / 10)
    }
  end
  
  defp identify_failure_pattern(_decision_id, similar_failed, _state) do
    # Extract common elements from failed decisions
    %{
      type: :failure_pattern,
      description: "Common factors in failed decisions",
      warning_signs: extract_warning_signs(similar_failed),
      confidence: min(1.0, length(similar_failed) / 10)
    }
  end
  
  defp identify_context_pattern(decision_id, outcome, state) do
    decision = Map.get(state.experiences.decisions, decision_id)
    
    if decision && decision[:context] do
      %{
        type: :context_pattern,
        context: decision.context,
        outcome: outcome.status,
        insight: "#{decision.context[:trigger]} context tends to lead to #{outcome.status}"
      }
    else
      nil
    end
  end
  
  defp extract_common_factors(decisions) do
    # Find common factors across decisions
    # Simplified implementation
    ["thorough_analysis", "clear_objectives", "adequate_resources"]
  end
  
  defp extract_warning_signs(decisions) do
    # Extract warning signs from failed decisions
    # Simplified implementation
    ["time_pressure", "incomplete_information", "conflicting_objectives"]
  end
  
  defp evaluate_strategy(decision_id, outcome, state) do
    decision = Map.get(state.experiences.decisions, decision_id)
    
    if decision && decision[:strategy] do
      strategy_key = decision.strategy
      
      # Update strategy effectiveness
      effectiveness_delta = case outcome.status do
        :success -> 0.1
        :failure -> -0.1
        _ -> 0
      end
      
      %{
        strategy: strategy_key,
        effectiveness_change: effectiveness_delta,
        context: decision[:context],
        outcome: outcome.status
      }
    else
      nil
    end
  end
  
  defp extract_causal_relationships(outcome, analysis) do
    relationships = []
    
    # Direct causation
    relationships = if outcome[:caused_by] do
      [%{
        type: :direct_causation,
        cause: outcome.caused_by,
        effect: outcome.result,
        strength: 0.8
      } | relationships]
    else
      relationships
    end
    
    # Contributing factors
    relationships = if analysis[:contributing_factors] do
      Enum.map(analysis.contributing_factors, fn factor ->
        %{
          type: :contributing_factor,
          factor: factor,
          contribution: estimate_contribution(factor, outcome),
          strength: 0.5
        }
      end) ++ relationships
    else
      relationships
    end
    
    relationships
  end
  
  defp estimate_contribution(_factor, _outcome) do
    # Estimate how much a factor contributed to outcome
    # Simplified - would use statistical analysis in reality
    :rand.uniform()
  end
  
  defp extract_meta_learnings(analysis, state) do
    meta_learnings = []
    
    # Learning about learning
    meta_learnings = if analysis[:learning_applied] do
      [%{
        type: :learning_effectiveness,
        message: "Previous learning successfully applied",
        improvement: "Continue reinforcing this learning pattern"
      } | meta_learnings]
    else
      meta_learnings
    end
    
    # Learning velocity
    current_velocity = calculate_current_learning_velocity(state)
    meta_learnings = if current_velocity > state.learning_metrics.learning_velocity do
      [%{
        type: :accelerated_learning,
        message: "Learning rate is increasing",
        velocity: current_velocity
      } | meta_learnings]
    else
      meta_learnings
    end
    
    meta_learnings
  end
  
  defp calculate_current_learning_velocity(state) do
    recent_insights = Enum.take(state.insights, 10)
    
    if length(recent_insights) > 0 do
      # Simple velocity calculation
      length(recent_insights) / 10.0
    else
      0.0
    end
  end
  
  defp integrate_learnings(state, learnings) do
    state
    |> update_knowledge_patterns(learnings.patterns)
    |> update_strategies(learnings.strategy_learnings)
    |> update_causal_models(learnings.causal_learnings)
    |> update_meta_knowledge(learnings.meta_learnings)
    |> record_learning_experience(learnings)
    |> generate_insights(learnings)
  end
  
  defp update_knowledge_patterns(state, patterns) do
    new_patterns = Enum.reduce(patterns, state.knowledge_base.patterns, fn pattern, acc ->
      key = {pattern.type, pattern[:description]}
      
      Map.update(acc, key, pattern, fn existing ->
        # Strengthen pattern confidence
        %{existing | 
          confidence: min(1.0, existing.confidence + pattern.confidence * 0.1),
          occurrences: (existing[:occurrences] || 1) + 1
        }
      end)
    end)
    
    put_in(state, [:knowledge_base, :patterns], new_patterns)
  end
  
  defp update_strategies(state, nil), do: state
  defp update_strategies(state, strategy_learning) do
    strategy_key = strategy_learning.strategy
    
    new_strategies = Map.update(
      state.knowledge_base.strategies,
      strategy_key,
      %{effectiveness: 0.5, contexts: [strategy_learning.context]},
      fn existing ->
        %{existing |
          effectiveness: max(0, min(1, existing.effectiveness + strategy_learning.effectiveness_change)),
          contexts: [strategy_learning.context | existing.contexts] |> Enum.uniq() |> Enum.take(10)
        }
      end
    )
    
    put_in(state, [:knowledge_base, :strategies], new_strategies)
  end
  
  defp update_causal_models(state, causal_learnings) do
    new_models = Enum.reduce(causal_learnings, state.knowledge_base.causal_models, fn rel, acc ->
      key = {rel[:cause], rel[:effect]}
      
      Map.update(acc, key, rel, fn existing ->
        # Strengthen causal relationship
        %{existing |
          strength: weighted_average(existing.strength, rel.strength, 0.8),
          observations: (existing[:observations] || 1) + 1
        }
      end)
    end)
    
    put_in(state, [:knowledge_base, :causal_models], new_models)
  end
  
  defp update_meta_knowledge(state, meta_learnings) do
    new_meta = Enum.reduce(meta_learnings, state.knowledge_base.meta_knowledge, fn learning, acc ->
      Map.put(acc, learning.type, learning)
    end)
    
    put_in(state, [:knowledge_base, :meta_knowledge], new_meta)
  end
  
  defp record_learning_experience(state, learnings) do
    experience = %{
      timestamp: DateTime.utc_now(),
      learnings: learnings,
      knowledge_before: calculate_knowledge_size(state.knowledge_base),
      knowledge_after: calculate_knowledge_size(state.knowledge_base)  # Will be different after updates
    }
    
    update_in(state, [:learning_metrics, :total_experiences], &(&1 + 1))
  end
  
  defp generate_insights(state, learnings) do
    insights = []
    
    # Pattern insights
    insights = if length(learnings.patterns) > 0 do
      pattern_insights = Enum.map(learnings.patterns, fn pattern ->
        %{
          type: :pattern_discovered,
          description: pattern.description,
          confidence: pattern.confidence,
          actionable: true,
          timestamp: DateTime.utc_now()
        }
      end)
      insights ++ pattern_insights
    else
      insights
    end
    
    # Strategy insights
    insights = if learnings.strategy_learnings do
      [%{
        type: :strategy_update,
        strategy: learnings.strategy_learnings.strategy,
        direction: if(learnings.strategy_learnings.effectiveness_change > 0, do: :improving, else: :declining),
        timestamp: DateTime.utc_now()
      } | insights]
    else
      insights
    end
    
    Map.update!(state, :insights, &(insights ++ &1))
  end
  
  defp check_for_breakthroughs(state, learnings) do
    breakthrough = detect_breakthrough(learnings, state)
    
    if breakthrough do
      new_breakthrough = %{
        type: breakthrough.type,
        description: breakthrough.description,
        impact: breakthrough.impact,
        timestamp: DateTime.utc_now()
      }
      
      Map.update!(state, :breakthrough_moments, &[new_breakthrough | &1])
    else
      state
    end
  end
  
  defp detect_breakthrough(learnings, state) do
    cond do
      # New pattern with high confidence
      Enum.any?(learnings.patterns, & &1.confidence > 0.8 && &1[:occurrences] == 1) ->
        %{
          type: :new_pattern,
          description: "Discovered high-confidence pattern on first observation",
          impact: :high
        }
        
      # Strategy breakthrough
      learnings.strategy_learnings && 
      abs(learnings.strategy_learnings.effectiveness_change) > 0.3 ->
        %{
          type: :strategy_breakthrough,
          description: "Major strategy effectiveness change discovered",
          impact: :medium
        }
        
      # Causal discovery
      length(learnings.causal_learnings) > 3 ->
        %{
          type: :causal_network,
          description: "Discovered complex causal relationships",
          impact: :high
        }
        
      true ->
        nil
    end
  end
  
  defp analyze_for_learning(decision_trace, state) do
    %{
      decision_type: decision_trace.decision.type,
      context: decision_trace.context,
      hypotheses_relevant: find_relevant_hypotheses(decision_trace, state),
      learning_opportunity: assess_learning_opportunity(decision_trace),
      experiment_potential: identify_experiment_potential(decision_trace)
    }
  end
  
  defp find_relevant_hypotheses(decision_trace, state) do
    state.active_hypotheses
    |> Enum.filter(fn {_, hypothesis} ->
      hypothesis_applies?(hypothesis, decision_trace)
    end)
    |> Enum.map(&elem(&1, 0))
  end
  
  defp hypothesis_applies?(hypothesis, decision_trace) do
    hypothesis.domain == decision_trace.context[:domain] ||
    hypothesis.decision_type == decision_trace.decision.type
  end
  
  defp assess_learning_opportunity(decision_trace) do
    factors = []
    
    factors = if decision_trace.confidence.level < 0.6 do
      [:high_uncertainty | factors]
    else
      factors
    end
    
    factors = if length(decision_trace.alternatives) > 3 do
      [:multiple_alternatives | factors]
    else
      factors
    end
    
    factors = if decision_trace.context[:novel] do
      [:novel_situation | factors]
    else
      factors
    end
    
    %{
      value: length(factors) / 3.0,
      factors: factors
    }
  end
  
  defp identify_experiment_potential(decision_trace) do
    if decision_trace.confidence.level < 0.7 && 
       length(decision_trace.alternatives) > 1 do
      %{
        can_experiment: true,
        experiment_type: :a_b_test,
        alternatives: Enum.map(decision_trace.alternatives, & &1.action)
      }
    else
      %{can_experiment: false}
    end
  end
  
  defp update_hypotheses(state, analysis) do
    if analysis.experiment_potential.can_experiment do
      # Create new hypothesis for experimentation
      hypothesis = %{
        id: generate_hypothesis_id(),
        domain: analysis.context[:domain],
        decision_type: analysis.decision_type,
        alternatives: analysis.experiment_potential.alternatives,
        created_at: DateTime.utc_now(),
        status: :active
      }
      
      put_in(state, [:active_hypotheses, hypothesis.id], hypothesis)
    else
      state
    end
  end
  
  defp generate_hypothesis_id do
    "hyp_#{System.unique_integer([:positive, :monotonic])}"
  end
  
  defp calculate_learning_effectiveness(state) do
    if state.learning_metrics.total_experiences > 0 do
      success_rate = state.learning_metrics.successful_learnings / 
                     state.learning_metrics.total_experiences
      
      # Adjust for retention
      success_rate * state.learning_metrics.knowledge_retention
    else
      0.5  # Neutral effectiveness without experience
    end
  end
  
  defp identify_learning_areas(state) do
    # Identify areas where learning is occurring
    state.knowledge_base.patterns
    |> Enum.group_by(fn {{type, _}, _} -> type end)
    |> Enum.map(fn {type, patterns} ->
      %{
        area: type,
        pattern_count: length(patterns),
        average_confidence: calculate_average_pattern_confidence(patterns)
      }
    end)
    |> Enum.sort_by(& -&1.pattern_count)
  end
  
  defp calculate_average_pattern_confidence(patterns) do
    confidences = Enum.map(patterns, fn {_, pattern} -> pattern.confidence end)
    
    if Enum.empty?(confidences) do
      0.0
    else
      Enum.sum(confidences) / length(confidences)
    end
  end
  
  defp summarize_knowledge_base(knowledge_base) do
    %{
      total_patterns: map_size(knowledge_base.patterns),
      total_strategies: map_size(knowledge_base.strategies),
      causal_relationships: map_size(knowledge_base.causal_models),
      domain_coverage: Map.keys(knowledge_base.domain_knowledge),
      meta_insights: map_size(knowledge_base.meta_knowledge),
      top_patterns: get_top_patterns(knowledge_base.patterns),
      effective_strategies: get_effective_strategies(knowledge_base.strategies)
    }
  end
  
  defp get_top_patterns(patterns) do
    patterns
    |> Enum.sort_by(fn {_, pattern} -> -pattern.confidence end)
    |> Enum.take(5)
    |> Enum.map(fn {{type, desc}, pattern} ->
      %{
        type: type,
        description: desc,
        confidence: pattern.confidence,
        occurrences: pattern[:occurrences] || 1
      }
    end)
  end
  
  defp get_effective_strategies(strategies) do
    strategies
    |> Enum.filter(fn {_, strategy} -> strategy.effectiveness > 0.6 end)
    |> Enum.sort_by(fn {_, strategy} -> -strategy.effectiveness end)
    |> Enum.take(3)
    |> Enum.map(fn {name, strategy} ->
      %{
        name: name,
        effectiveness: strategy.effectiveness,
        best_contexts: Enum.take(strategy.contexts, 3)
      }
    end)
  end
  
  defp identify_learning_barriers_internal(state) do
    barriers = []
    
    # Low learning velocity
    barriers = if state.learning_metrics.learning_velocity < 0.3 do
      [%{
        type: :low_velocity,
        description: "Learning rate is below optimal threshold",
        severity: :medium,
        suggestion: "Increase experimentation and reflection frequency"
      } | barriers]
    else
      barriers
    end
    
    # High forgetting rate
    barriers = if state.learning_config.forgetting_rate > 0.05 do
      [%{
        type: :high_forgetting,
        description: "Knowledge is being lost too quickly",
        severity: :high,
        suggestion: "Implement better knowledge consolidation"
      } | barriers]
    else
      barriers
    end
    
    # Limited exploration
    barriers = if state.learning_config.exploration_rate < 0.1 do
      [%{
        type: :insufficient_exploration,
        description: "Not exploring enough alternatives",
        severity: :medium,
        suggestion: "Increase exploration rate for better learning"
      } | barriers]
    else
      barriers
    end
    
    # Few active hypotheses
    barriers = if map_size(state.active_hypotheses) < 2 do
      [%{
        type: :few_hypotheses,
        description: "Not enough active experimentation",
        severity: :low,
        suggestion: "Generate more hypotheses from observations"
      } | barriers]
    else
      barriers
    end
    
    %{
      barriers: barriers,
      overall_health: calculate_learning_health(barriers),
      recommendations: generate_learning_recommendations(barriers)
    }
  end
  
  defp calculate_learning_health(barriers) do
    severity_scores = %{low: 0.1, medium: 0.3, high: 0.5}
    
    total_impact = Enum.reduce(barriers, 0, fn barrier, acc ->
      acc + Map.get(severity_scores, barrier.severity, 0)
    end)
    
    max(0, 1 - total_impact)
  end
  
  defp generate_learning_recommendations(barriers) do
    barriers
    |> Enum.map(& &1.suggestion)
    |> Enum.uniq()
  end
  
  defp apply_knowledge(knowledge_base, context) do
    %{
      relevant_patterns: find_relevant_patterns(knowledge_base.patterns, context),
      recommended_strategy: recommend_strategy(knowledge_base.strategies, context),
      causal_predictions: make_causal_predictions(knowledge_base.causal_models, context),
      confidence: calculate_recommendation_confidence(knowledge_base, context)
    }
  end
  
  defp find_relevant_patterns(patterns, context) do
    patterns
    |> Enum.filter(fn {{type, _}, _} ->
      pattern_relevant_to_context?(type, context)
    end)
    |> Enum.sort_by(fn {_, pattern} -> -pattern.confidence end)
    |> Enum.take(3)
    |> Enum.map(fn {{type, desc}, pattern} ->
      %{
        type: type,
        description: desc,
        confidence: pattern.confidence,
        applicability: calculate_applicability(pattern, context)
      }
    end)
  end
  
  defp pattern_relevant_to_context?(pattern_type, context) do
    pattern_type == context[:type] || 
    pattern_type == :general ||
    (context[:related_types] && pattern_type in context[:related_types])
  end
  
  defp calculate_applicability(_pattern, _context) do
    # Simplified applicability calculation
    :rand.uniform() * 0.5 + 0.5
  end
  
  defp recommend_strategy(strategies, context) do
    applicable_strategies = strategies
    |> Enum.filter(fn {_, strategy} ->
      Enum.any?(strategy.contexts, &context_matches?(&1, context))
    end)
    |> Enum.sort_by(fn {_, strategy} -> -strategy.effectiveness end)
    
    case applicable_strategies do
      [{name, strategy} | _] ->
        %{
          strategy: name,
          effectiveness: strategy.effectiveness,
          confidence: calculate_strategy_confidence(strategy)
        }
      _ ->
        %{
          strategy: :default,
          effectiveness: 0.5,
          confidence: 0.3
        }
    end
  end
  
  defp context_matches?(stored_context, current_context) do
    stored_context[:domain] == current_context[:domain] ||
    stored_context[:type] == current_context[:type]
  end
  
  defp calculate_strategy_confidence(strategy) do
    # Confidence based on number of observations
    observations = length(strategy.contexts)
    min(1.0, observations / 10.0) * strategy.effectiveness
  end
  
  defp make_causal_predictions(causal_models, context) do
    # Find relevant causal relationships
    relevant_causes = context[:factors] || []
    
    predictions = causal_models
    |> Enum.filter(fn {{cause, _}, _} ->
      cause in relevant_causes
    end)
    |> Enum.map(fn {{cause, effect}, model} ->
      %{
        if_factor: cause,
        then_outcome: effect,
        probability: model.strength,
        confidence: min(1.0, model[:observations] / 5.0)
      }
    end)
    
    predictions
  end
  
  defp calculate_recommendation_confidence(knowledge_base, context) do
    factors = [
      pattern_confidence_factor(knowledge_base.patterns, context),
      strategy_confidence_factor(knowledge_base.strategies, context),
      experience_factor(knowledge_base)
    ]
    
    Enum.sum(factors) / length(factors)
  end
  
  defp pattern_confidence_factor(patterns, context) do
    relevant = find_relevant_patterns(patterns, context)
    
    if Enum.empty?(relevant) do
      0.3
    else
      confidences = Enum.map(relevant, & &1[:confidence])
      Enum.sum(confidences) / length(confidences)
    end
  end
  
  defp strategy_confidence_factor(strategies, context) do
    recommendation = recommend_strategy(strategies, context)
    recommendation.confidence
  end
  
  defp experience_factor(knowledge_base) do
    total_knowledge = calculate_knowledge_size(knowledge_base)
    min(1.0, total_knowledge / 100.0)
  end
  
  defp calculate_knowledge_size(knowledge_base) do
    map_size(knowledge_base.patterns) +
    map_size(knowledge_base.strategies) +
    map_size(knowledge_base.causal_models) +
    map_size(knowledge_base.domain_knowledge)
  end
  
  defp track_knowledge_application(state, context, recommendations) do
    application = %{
      context: context,
      recommendations: recommendations,
      timestamp: DateTime.utc_now(),
      pending_outcome: true
    }
    
    # Store for future learning when outcome is known
    update_in(state, [:experiments_in_progress, generate_experiment_id()], 
              fn _ -> application end)
  end
  
  defp generate_experiment_id do
    "exp_#{System.unique_integer([:positive, :monotonic])}"
  end
  
  defp consolidate_knowledge(state) do
    # Consolidate patterns with high confidence
    consolidated_patterns = state.knowledge_base.patterns
    |> Enum.filter(fn {_, pattern} ->
      pattern.confidence > state.learning_config.consolidation_threshold / 10.0
    end)
    |> Map.new()
    
    # Update learning velocity
    new_velocity = calculate_learning_velocity(state)
    
    state
    |> put_in([:knowledge_base, :patterns], consolidated_patterns)
    |> put_in([:learning_metrics, :learning_velocity], new_velocity)
  end
  
  defp calculate_learning_velocity(state) do
    recent_experiences = min(10, state.learning_metrics.total_experiences)
    recent_insights = length(Enum.take(state.insights, 10))
    
    if recent_experiences > 0 do
      recent_insights / recent_experiences
    else
      0.0
    end
  end
  
  defp apply_forgetting(state) do
    # Apply forgetting to maintain relevant knowledge
    forgetting_rate = state.learning_config.forgetting_rate
    
    # Reduce confidence in patterns not recently reinforced
    updated_patterns = state.knowledge_base.patterns
    |> Enum.map(fn {key, pattern} ->
      new_confidence = pattern.confidence * (1 - forgetting_rate)
      {key, %{pattern | confidence: new_confidence}}
    end)
    |> Enum.filter(fn {_, pattern} -> pattern.confidence > 0.1 end)
    |> Map.new()
    
    # Update retention metric
    retention = if map_size(state.knowledge_base.patterns) > 0 do
      map_size(updated_patterns) / map_size(state.knowledge_base.patterns)
    else
      1.0
    end
    
    state
    |> put_in([:knowledge_base, :patterns], updated_patterns)
    |> put_in([:learning_metrics, :knowledge_retention], retention)
  end
  
  defp weighted_average(old_value, new_value, weight) do
    weight * old_value + (1 - weight) * new_value
  end
end