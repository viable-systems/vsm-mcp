defmodule VsmMcp.ConsciousnessInterface.MetaCognition do
  @moduledoc """
  Meta-Cognition Module - Thinking about thinking
  
  This module implements the core meta-cognitive capabilities:
  - Monitoring cognitive processes
  - Evaluating reasoning quality
  - Detecting cognitive biases
  - Optimizing thinking strategies
  """
  
  use GenServer
  require Logger
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def analyze_thinking_process(pid, process_trace) do
    GenServer.call(pid, {:analyze_thinking, process_trace})
  end
  
  def evaluate_reasoning_quality(pid, reasoning_chain) do
    GenServer.call(pid, {:evaluate_reasoning, reasoning_chain})
  end
  
  def detect_cognitive_patterns(pid) do
    GenServer.call(pid, :detect_patterns)
  end
  
  def optimize_strategy(pid, context) do
    GenServer.call(pid, {:optimize_strategy, context})
  end
  
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      thinking_patterns: %{},
      reasoning_metrics: %{
        depth: [],
        breadth: [],
        coherence: [],
        effectiveness: []
      },
      cognitive_strategies: initialize_strategies(),
      bias_detection: %{
        confirmation_bias: 0.0,
        anchoring_bias: 0.0,
        availability_bias: 0.0,
        overconfidence_bias: 0.0
      },
      metacognitive_insights: [],
      process_history: []
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:analyze_thinking, process_trace}, _from, state) do
    analysis = perform_thinking_analysis(process_trace, state)
    
    # Update patterns based on analysis
    new_patterns = update_thinking_patterns(state.thinking_patterns, analysis)
    
    # Store in history
    history_entry = %{
      trace: process_trace,
      analysis: analysis,
      timestamp: DateTime.utc_now()
    }
    
    new_state = state
    |> Map.put(:thinking_patterns, new_patterns)
    |> Map.update!(:process_history, &[history_entry | &1])
    
    {:reply, analysis, new_state}
  end
  
  @impl true
  def handle_call({:evaluate_reasoning, reasoning_chain}, _from, state) do
    evaluation = evaluate_chain(reasoning_chain, state)
    
    # Update metrics
    new_metrics = update_reasoning_metrics(state.reasoning_metrics, evaluation)
    
    # Check for biases
    bias_indicators = detect_biases_in_reasoning(reasoning_chain)
    new_bias_detection = update_bias_scores(state.bias_detection, bias_indicators)
    
    new_state = state
    |> Map.put(:reasoning_metrics, new_metrics)
    |> Map.put(:bias_detection, new_bias_detection)
    
    {:reply, evaluation, new_state}
  end
  
  @impl true
  def handle_call(:detect_patterns, _from, state) do
    patterns = analyze_cognitive_patterns(state)
    
    # Generate insights from patterns
    insights = generate_pattern_insights(patterns)
    
    new_state = Map.update!(state, :metacognitive_insights, &(insights ++ &1))
    
    {:reply, patterns, new_state}
  end
  
  @impl true
  def handle_call({:optimize_strategy, context}, _from, state) do
    # Analyze current strategy effectiveness
    current_effectiveness = analyze_strategy_effectiveness(state, context)
    
    # Suggest optimizations
    optimizations = generate_strategy_optimizations(
      state.cognitive_strategies,
      current_effectiveness,
      context
    )
    
    # Update strategies if improvements found
    new_strategies = if optimizations.improvement_potential > 0.2 do
      apply_strategy_optimizations(state.cognitive_strategies, optimizations)
    else
      state.cognitive_strategies
    end
    
    new_state = Map.put(state, :cognitive_strategies, new_strategies)
    
    {:reply, optimizations, new_state}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    summary = %{
      active_patterns: Map.keys(state.thinking_patterns),
      reasoning_quality: calculate_overall_reasoning_quality(state.reasoning_metrics),
      bias_levels: state.bias_detection,
      recent_insights: Enum.take(state.metacognitive_insights, 5),
      strategy_effectiveness: evaluate_strategies(state.cognitive_strategies)
    }
    
    {:reply, summary, state}
  end
  
  # Private Functions
  
  defp initialize_strategies do
    %{
      analytical: %{
        name: "Analytical Decomposition",
        effectiveness: 0.7,
        use_count: 0,
        best_for: [:complex_problems, :systematic_analysis]
      },
      creative: %{
        name: "Creative Exploration",
        effectiveness: 0.6,
        use_count: 0,
        best_for: [:novel_problems, :innovation]
      },
      systematic: %{
        name: "Systematic Search",
        effectiveness: 0.8,
        use_count: 0,
        best_for: [:optimization, :exhaustive_analysis]
      },
      heuristic: %{
        name: "Heuristic Reasoning",
        effectiveness: 0.7,
        use_count: 0,
        best_for: [:quick_decisions, :pattern_matching]
      },
      meta: %{
        name: "Meta-Strategic",
        effectiveness: 0.5,
        use_count: 0,
        best_for: [:strategy_selection, :adaptation]
      }
    }
  end
  
  defp perform_thinking_analysis(process_trace, state) do
    %{
      depth: analyze_thinking_depth(process_trace),
      breadth: analyze_thinking_breadth(process_trace),
      loops_detected: detect_thinking_loops(process_trace),
      strategy_used: identify_strategy(process_trace, state.cognitive_strategies),
      efficiency: calculate_thinking_efficiency(process_trace),
      insights_generated: count_insights(process_trace),
      dead_ends: count_dead_ends(process_trace),
      breakthrough_moments: identify_breakthroughs(process_trace)
    }
  end
  
  defp analyze_thinking_depth(trace) do
    # Measure how deep the reasoning went
    max_depth = trace
    |> Enum.map(& &1[:depth] || 1)
    |> Enum.max(fn -> 1 end)
    
    %{
      max_depth: max_depth,
      average_depth: calculate_average_depth(trace),
      depth_variance: calculate_depth_variance(trace)
    }
  end
  
  defp analyze_thinking_breadth(trace) do
    # Measure how many alternatives were considered
    %{
      alternatives_considered: count_alternatives(trace),
      branches_explored: count_branches(trace),
      coverage_ratio: calculate_coverage_ratio(trace)
    }
  end
  
  defp detect_thinking_loops(trace) do
    # Detect circular reasoning or repetitive patterns
    seen = MapSet.new()
    loops = []
    
    Enum.reduce(trace, {seen, loops}, fn step, {seen_acc, loops_acc} ->
      key = generate_step_key(step)
      
      if MapSet.member?(seen_acc, key) do
        {seen_acc, [key | loops_acc]}
      else
        {MapSet.put(seen_acc, key), loops_acc}
      end
    end)
    |> elem(1)
    |> Enum.uniq()
  end
  
  defp evaluate_chain(reasoning_chain, state) do
    %{
      logical_validity: check_logical_validity(reasoning_chain),
      coherence_score: calculate_coherence(reasoning_chain),
      evidence_quality: assess_evidence_quality(reasoning_chain),
      conclusion_strength: evaluate_conclusion_strength(reasoning_chain),
      weak_links: identify_weak_links(reasoning_chain),
      missing_steps: detect_missing_steps(reasoning_chain)
    }
  end
  
  defp detect_biases_in_reasoning(reasoning_chain) do
    %{
      confirmation_bias: detect_confirmation_bias(reasoning_chain),
      anchoring_bias: detect_anchoring_bias(reasoning_chain),
      availability_bias: detect_availability_bias(reasoning_chain),
      overconfidence: detect_overconfidence(reasoning_chain)
    }
  end
  
  defp detect_confirmation_bias(chain) do
    # Check if reasoning selectively focuses on confirming evidence
    confirming = count_confirming_evidence(chain)
    disconfirming = count_disconfirming_evidence(chain)
    
    if confirming + disconfirming > 0 do
      confirming / (confirming + disconfirming)
    else
      0.5
    end
  end
  
  defp analyze_cognitive_patterns(state) do
    %{
      dominant_thinking_style: identify_dominant_style(state.thinking_patterns),
      pattern_stability: calculate_pattern_stability(state.process_history),
      adaptive_capacity: measure_adaptive_capacity(state),
      metacognitive_awareness: calculate_metacognitive_awareness(state)
    }
  end
  
  defp generate_pattern_insights(patterns) do
    insights = []
    
    insights = if patterns.pattern_stability < 0.3 do
      [%{
        type: :high_variability,
        message: "Thinking patterns show high variability - may indicate adaptive exploration",
        significance: 0.7
      } | insights]
    else
      insights
    end
    
    insights = if patterns.metacognitive_awareness > 0.8 do
      [%{
        type: :high_awareness,
        message: "High metacognitive awareness detected - optimal for complex reasoning",
        significance: 0.8
      } | insights]
    else
      insights
    end
    
    insights
  end
  
  defp analyze_strategy_effectiveness(state, context) do
    recent_uses = Enum.take(state.process_history, 20)
    
    %{
      current_context: context,
      strategy_performance: calculate_recent_performance(recent_uses),
      context_alignment: assess_context_alignment(state.cognitive_strategies, context),
      adaptation_needed: determine_adaptation_need(recent_uses, context)
    }
  end
  
  defp generate_strategy_optimizations(strategies, effectiveness, context) do
    %{
      recommended_strategy: select_optimal_strategy(strategies, context),
      current_gaps: identify_strategy_gaps(effectiveness),
      improvement_potential: calculate_improvement_potential(effectiveness),
      specific_adjustments: recommend_adjustments(strategies, effectiveness, context)
    }
  end
  
  # Helper functions
  
  defp calculate_average_depth(trace) do
    depths = Enum.map(trace, & &1[:depth] || 1)
    if Enum.empty?(depths), do: 0, else: Enum.sum(depths) / length(depths)
  end
  
  defp calculate_depth_variance(trace) do
    depths = Enum.map(trace, & &1[:depth] || 1)
    if length(depths) < 2, do: 0, else: Statistics.variance(depths)
  end
  
  defp count_alternatives(trace) do
    trace
    |> Enum.map(& &1[:alternatives] || 0)
    |> Enum.sum()
  end
  
  defp count_branches(trace) do
    trace
    |> Enum.filter(& &1[:branched])
    |> length()
  end
  
  defp calculate_coverage_ratio(trace) do
    explored = count_branches(trace)
    possible = Enum.map(trace, & &1[:possible_branches] || 1) |> Enum.sum()
    
    if possible > 0, do: explored / possible, else: 0
  end
  
  defp generate_step_key(step) do
    # Create a unique key for detecting loops
    "#{step[:type]}_#{step[:target]}_#{step[:approach]}"
  end
  
  defp identify_strategy(trace, strategies) do
    # Analyze trace to identify which strategy was predominantly used
    strategy_indicators = Enum.map(strategies, fn {name, strategy} ->
      score = calculate_strategy_match(trace, strategy)
      {name, score}
    end)
    
    {strategy_name, _} = Enum.max_by(strategy_indicators, &elem(&1, 1))
    strategy_name
  end
  
  defp calculate_strategy_match(trace, strategy) do
    # Calculate how well the trace matches a strategy pattern
    Enum.count(trace, fn step ->
      step[:approach] in strategy.best_for
    end) / max(length(trace), 1)
  end
  
  defp calculate_thinking_efficiency(trace) do
    steps = length(trace)
    results = Enum.count(trace, & &1[:produced_result])
    backtrack_count = Enum.count(trace, & &1[:backtracked])
    
    efficiency = if steps > 0 do
      (results / steps) * (1 - (backtrack_count / steps))
    else
      0
    end
    
    efficiency
  end
  
  defp count_insights(trace) do
    Enum.count(trace, & &1[:insight_generated])
  end
  
  defp count_dead_ends(trace) do
    Enum.count(trace, & &1[:dead_end])
  end
  
  defp identify_breakthroughs(trace) do
    trace
    |> Enum.filter(& &1[:breakthrough])
    |> Enum.map(& &1[:description])
  end
  
  defp update_thinking_patterns(patterns, analysis) do
    strategy = analysis.strategy_used
    
    Map.update(patterns, strategy, 1, &(&1 + 1))
  end
  
  defp update_reasoning_metrics(metrics, evaluation) do
    %{
      depth: [evaluation.logical_validity | metrics.depth] |> Enum.take(100),
      breadth: [evaluation.evidence_quality | metrics.breadth] |> Enum.take(100),
      coherence: [evaluation.coherence_score | metrics.coherence] |> Enum.take(100),
      effectiveness: [evaluation.conclusion_strength | metrics.effectiveness] |> Enum.take(100)
    }
  end
  
  defp update_bias_scores(current_biases, new_indicators) do
    %{
      confirmation_bias: weighted_average(
        current_biases.confirmation_bias,
        new_indicators.confirmation_bias,
        0.9
      ),
      anchoring_bias: weighted_average(
        current_biases.anchoring_bias,
        new_indicators.anchoring_bias,
        0.9
      ),
      availability_bias: weighted_average(
        current_biases.availability_bias,
        new_indicators.availability_bias,
        0.9
      ),
      overconfidence_bias: weighted_average(
        current_biases.overconfidence_bias,
        new_indicators.overconfidence,
        0.9
      )
    }
  end
  
  defp weighted_average(old_value, new_value, weight) do
    weight * old_value + (1 - weight) * new_value
  end
  
  defp check_logical_validity(chain) do
    # Simplified logical validity check
    Enum.reduce(chain, 1.0, fn step, validity ->
      if step[:logical_error], do: validity * 0.7, else: validity
    end)
  end
  
  defp calculate_coherence(chain) do
    # Check internal consistency
    if length(chain) < 2, do: 1.0, else: 0.8
  end
  
  defp assess_evidence_quality(chain) do
    evidence_steps = Enum.filter(chain, & &1[:evidence])
    if Enum.empty?(evidence_steps), do: 0.5, else: 0.8
  end
  
  defp evaluate_conclusion_strength(chain) do
    last_step = List.last(chain)
    if last_step && last_step[:conclusion], do: 0.9, else: 0.6
  end
  
  defp identify_weak_links(chain) do
    chain
    |> Enum.with_index()
    |> Enum.filter(fn {step, _} -> step[:confidence] < 0.5 end)
    |> Enum.map(fn {_, index} -> index end)
  end
  
  defp detect_missing_steps(chain) do
    # Detect logical gaps
    []
  end
  
  defp count_confirming_evidence(chain) do
    Enum.count(chain, & &1[:confirms_hypothesis])
  end
  
  defp count_disconfirming_evidence(chain) do
    Enum.count(chain, & &1[:contradicts_hypothesis])
  end
  
  defp detect_anchoring_bias(chain) do
    # Check if early information dominates
    if length(chain) > 5 do
      first_influence = Enum.take(chain, 2) |> Enum.count(& &1[:influential])
      total_influence = Enum.count(chain, & &1[:influential])
      
      if total_influence > 0, do: first_influence / total_influence, else: 0
    else
      0
    end
  end
  
  defp detect_availability_bias(chain) do
    # Check if recent/memorable examples dominate
    recent_weight = chain
    |> Enum.filter(& &1[:uses_recent_example])
    |> length()
    
    if length(chain) > 0, do: recent_weight / length(chain), else: 0
  end
  
  defp detect_overconfidence(chain) do
    # Check for overconfidence indicators
    high_confidence = Enum.count(chain, & (&1[:confidence] || 0) > 0.9)
    
    if length(chain) > 0, do: high_confidence / length(chain), else: 0
  end
  
  defp identify_dominant_style(patterns) do
    if map_size(patterns) == 0 do
      :none
    else
      {style, _} = Enum.max_by(patterns, &elem(&1, 1))
      style
    end
  end
  
  defp calculate_pattern_stability(history) do
    # Check how stable patterns are over time
    if length(history) < 5, do: 0.5, else: 0.7
  end
  
  defp measure_adaptive_capacity(state) do
    # Measure ability to switch strategies
    unique_strategies = state.process_history
    |> Enum.take(20)
    |> Enum.map(& &1.analysis[:strategy_used])
    |> Enum.uniq()
    |> length()
    
    min(unique_strategies / 3, 1.0)
  end
  
  defp calculate_metacognitive_awareness(state) do
    # Measure awareness of own thinking
    insights_count = length(state.metacognitive_insights)
    history_count = length(state.process_history)
    
    if history_count > 0 do
      min(insights_count / (history_count * 0.2), 1.0)
    else
      0
    end
  end
  
  defp calculate_recent_performance(recent_uses) do
    # Calculate performance metrics from recent usage
    %{
      success_rate: 0.7,
      efficiency: 0.6,
      insight_generation: 0.5
    }
  end
  
  defp assess_context_alignment(strategies, context) do
    # Check how well current strategies align with context
    0.7
  end
  
  defp determine_adaptation_need(recent_uses, context) do
    # Determine if adaptation is needed
    length(recent_uses) > 10 && context[:complexity] > 0.7
  end
  
  defp select_optimal_strategy(strategies, context) do
    # Select best strategy for context
    if context[:time_pressure] do
      :heuristic
    else
      :systematic
    end
  end
  
  defp identify_strategy_gaps(effectiveness) do
    # Identify gaps in current strategy
    []
  end
  
  defp calculate_improvement_potential(effectiveness) do
    # Calculate potential for improvement
    1.0 - effectiveness.strategy_performance.success_rate
  end
  
  defp recommend_adjustments(strategies, effectiveness, context) do
    # Recommend specific adjustments
    []
  end
  
  defp apply_strategy_optimizations(strategies, optimizations) do
    # Apply recommended optimizations
    strategies
  end
  
  defp calculate_overall_reasoning_quality(metrics) do
    # Calculate overall quality from metrics
    avg_coherence = if Enum.empty?(metrics.coherence) do
      0.5
    else
      Enum.sum(metrics.coherence) / length(metrics.coherence)
    end
    
    avg_coherence
  end
  
  defp evaluate_strategies(strategies) do
    # Evaluate effectiveness of each strategy
    Map.new(strategies, fn {name, strategy} ->
      {name, strategy.effectiveness}
    end)
  end
end