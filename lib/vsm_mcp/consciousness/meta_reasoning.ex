defmodule VsmMcp.ConsciousnessInterface.MetaReasoning do
  @moduledoc """
  Meta-Reasoning Module - Reasoning about variety gaps and system limitations
  
  This module implements meta-level reasoning capabilities:
  - Analyze variety handling capacity vs requirements
  - Identify systemic limitations and constraints
  - Reason about what the system cannot do
  - Suggest variety amplification strategies
  - Meta-analysis of reasoning processes
  - Understand and adapt to complexity
  
  True meta-reasoning that enables the system to understand its own boundaries.
  """
  
  use GenServer
  require Logger
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def analyze_variety_gaps(pid) do
    GenServer.call(pid, :analyze_variety_gaps)
  end
  
  def synthesize(pid, components) do
    GenServer.call(pid, {:synthesize, components})
  end
  
  def assess_computational_limits(pid) do
    GenServer.call(pid, :assess_computational_limits)
  end
  
  def identify_variety_constraints(pid) do
    GenServer.call(pid, :identify_variety_constraints)
  end
  
  def get_insights(pid) do
    GenServer.call(pid, :get_insights)
  end
  
  def reason_about_limitation(pid, limitation) do
    GenServer.call(pid, {:reason_about, limitation})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      # Variety analysis
      variety_state: %{
        internal_variety: calculate_internal_variety(),
        external_variety: estimate_external_variety(),
        variety_ratio: 0.5,
        amplifiers: [],
        attenuators: []
      },
      
      # Limitation tracking
      known_limitations: %{
        computational: [],
        knowledge: [],
        structural: [],
        temporal: [],
        interaction: []
      },
      
      # Meta-reasoning state
      reasoning_patterns: %{},
      complexity_assessments: %{},
      adaptation_strategies: %{},
      
      # Insights
      meta_insights: [],
      systemic_patterns: [],
      
      # Performance boundaries
      performance_envelope: %{
        max_complexity: 0,
        time_constraints: {},
        resource_constraints: {},
        accuracy_limits: {}
      }
    }
    
    # Schedule periodic meta-analysis
    Process.send_after(self(), :periodic_meta_analysis, 30_000)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:analyze_variety_gaps, _from, state) do
    analysis = perform_variety_gap_analysis(state)
    
    # Update variety state based on analysis
    new_variety_state = update_variety_state(state.variety_state, analysis)
    new_state = Map.put(state, :variety_state, new_variety_state)
    
    {:reply, analysis, new_state}
  end
  
  @impl true
  def handle_call({:synthesize, components}, _from, state) do
    # Synthesize insights from multiple consciousness components
    synthesis = perform_meta_synthesis(components, state)
    
    # Store significant findings
    new_state = if synthesis.significance > 0.7 do
      store_meta_insight(state, synthesis)
    else
      state
    end
    
    {:reply, synthesis, new_state}
  end
  
  @impl true
  def handle_call(:assess_computational_limits, _from, state) do
    assessment = assess_computational_boundaries(state)
    
    # Update known limitations
    new_limitations = update_computational_limitations(
      state.known_limitations,
      assessment
    )
    
    new_state = Map.put(state, :known_limitations, new_limitations)
    
    {:reply, assessment, new_state}
  end
  
  @impl true
  def handle_call(:identify_variety_constraints, _from, state) do
    constraints = identify_systemic_variety_constraints(state)
    {:reply, constraints, state}
  end
  
  @impl true
  def handle_call(:get_insights, _from, state) do
    insights = compile_meta_insights(state)
    {:reply, insights, state}
  end
  
  @impl true
  def handle_call({:reason_about, limitation}, _from, state) do
    reasoning = reason_about_specific_limitation(limitation, state)
    
    # Learn from this reasoning
    new_state = integrate_limitation_reasoning(state, limitation, reasoning)
    
    {:reply, reasoning, new_state}
  end
  
  @impl true
  def handle_info(:periodic_meta_analysis, state) do
    # Perform periodic meta-level analysis
    analysis = perform_periodic_meta_analysis(state)
    
    # Update state based on findings
    new_state = integrate_periodic_findings(state, analysis)
    
    # Schedule next analysis
    Process.send_after(self(), :periodic_meta_analysis, 30_000)
    
    {:noreply, new_state}
  end
  
  # Private Functions - Variety Analysis
  
  defp calculate_internal_variety do
    # Calculate the system's internal variety (states it can be in)
    %{
      state_space_size: estimate_state_space(),
      action_space_size: estimate_action_space(),
      adaptation_range: estimate_adaptation_range(),
      total_variety: :high  # Simplified assessment
    }
  end
  
  defp estimate_state_space do
    # Estimate possible internal states
    # Consider: memory states, process states, knowledge states
    1000  # Simplified estimate
  end
  
  defp estimate_action_space do
    # Estimate possible actions/responses
    100  # Simplified estimate
  end
  
  defp estimate_adaptation_range do
    # Range of adaptations possible
    :moderate
  end
  
  defp estimate_external_variety do
    # Estimate variety in the environment
    %{
      input_variety: :very_high,
      context_variety: :high,
      temporal_variety: :moderate,
      total_variety: :very_high
    }
  end
  
  defp perform_variety_gap_analysis(state) do
    internal = state.variety_state.internal_variety
    external = state.variety_state.external_variety
    
    %{
      # Variety measurements
      internal_variety: internal,
      external_variety: external,
      
      # Gap analysis
      variety_gap: calculate_variety_gap(internal, external),
      
      # Specific gaps
      gaps: identify_specific_gaps(internal, external, state),
      
      # Current handling
      amplifiers_active: analyze_active_amplifiers(state),
      attenuators_active: analyze_active_attenuators(state),
      
      # Recommendations
      recommendations: generate_variety_recommendations(internal, external, state),
      
      # Capacity assessment
      variety_capacity: assess_variety_handling_capacity(state)
    }
  end
  
  defp calculate_variety_gap(internal, external) do
    # Simplified gap calculation
    # In reality, would use Ashby's Law calculations
    %{
      magnitude: :significant,
      direction: :external_exceeds_internal,
      ratio: 0.1,  # Internal can handle 10% of external variety
      critical: true
    }
  end
  
  defp identify_specific_gaps(internal, external, state) do
    gaps = []
    
    # Input processing gap
    gaps = if external.input_variety == :very_high && 
              internal.state_space_size < 10000 do
      [%{
        type: :input_processing,
        severity: :high,
        description: "Cannot process full variety of inputs"
      } | gaps]
    else
      gaps
    end
    
    # Temporal variety gap
    gaps = if external.temporal_variety == :high do
      [%{
        type: :temporal_adaptation,
        severity: :medium,
        description: "Limited ability to handle rapid changes"
      } | gaps]
    else
      gaps
    end
    
    # Context variety gap
    gaps = if external.context_variety == :high &&
              map_size(state.adaptation_strategies) < 5 do
      [%{
        type: :contextual_adaptation,
        severity: :medium,
        description: "Insufficient context-specific strategies"
      } | gaps]
    else
      gaps
    end
    
    gaps
  end
  
  defp analyze_active_amplifiers(state) do
    # Analyze variety amplification mechanisms
    amplifiers = state.variety_state.amplifiers
    
    %{
      count: length(amplifiers),
      types: Enum.map(amplifiers, & &1.type),
      effectiveness: calculate_amplifier_effectiveness(amplifiers),
      recommendations: suggest_new_amplifiers(state)
    }
  end
  
  defp calculate_amplifier_effectiveness(amplifiers) do
    if Enum.empty?(amplifiers) do
      0.0
    else
      # Average effectiveness
      total = Enum.sum(Enum.map(amplifiers, & &1[:effectiveness] || 0.5))
      total / length(amplifiers)
    end
  end
  
  defp suggest_new_amplifiers(state) do
    suggestions = []
    
    # Pattern-based amplification
    suggestions = if map_size(state.reasoning_patterns) < 10 do
      ["Develop more reasoning patterns for variety amplification" | suggestions]
    else
      suggestions
    end
    
    # Tool-based amplification
    suggestions = ["Integrate external tools to amplify variety handling" | suggestions]
    
    # Learning-based amplification
    suggestions = ["Use learning to predict and pre-handle variety" | suggestions]
    
    suggestions
  end
  
  defp analyze_active_attenuators(state) do
    # Analyze variety attenuation mechanisms
    %{
      filtering: analyze_filtering_mechanisms(state),
      categorization: analyze_categorization(state),
      abstraction: analyze_abstraction_levels(state),
      prioritization: analyze_prioritization(state)
    }
  end
  
  defp analyze_filtering_mechanisms(_state) do
    %{
      active_filters: [:noise_filter, :relevance_filter],
      effectiveness: 0.7,
      coverage: 0.6
    }
  end
  
  defp analyze_categorization(_state) do
    %{
      categories_defined: 20,
      uncategorized_ratio: 0.3,
      category_effectiveness: 0.6
    }
  end
  
  defp analyze_abstraction_levels(_state) do
    %{
      levels: 5,
      abstraction_quality: 0.7,
      information_preservation: 0.8
    }
  end
  
  defp analyze_prioritization(_state) do
    %{
      prioritization_scheme: :multi_criteria,
      queue_depth: 10,
      priority_accuracy: 0.75
    }
  end
  
  defp generate_variety_recommendations(_internal, _external, state) do
    recommendations = []
    
    # Amplification recommendations
    recommendations = if length(state.variety_state.amplifiers) < 3 do
      [%{
        type: :add_amplifier,
        priority: :high,
        suggestion: "Add pattern recognition amplifiers"
      } | recommendations]
    else
      recommendations
    end
    
    # Attenuation recommendations
    recommendations = if state.variety_state.variety_ratio < 0.3 do
      [%{
        type: :improve_attenuation,
        priority: :high,
        suggestion: "Enhance filtering and categorization"
      } | recommendations]
    else
      recommendations
    end
    
    # Structural recommendations
    recommendations = [%{
      type: :structural,
      priority: :medium,
      suggestion: "Consider hierarchical variety handling"
    } | recommendations]
    
    recommendations
  end
  
  defp assess_variety_handling_capacity(state) do
    factors = [
      state.variety_state.variety_ratio,
      calculate_amplifier_effectiveness(state.variety_state.amplifiers),
      0.7,  # Attenuation effectiveness placeholder
      0.6   # Adaptation capability placeholder
    ]
    
    Enum.sum(factors) / length(factors)
  end
  
  defp update_variety_state(variety_state, analysis) do
    %{variety_state |
      variety_ratio: analysis.variety_gap.ratio,
      amplifiers: update_amplifiers(variety_state.amplifiers, analysis),
      attenuators: update_attenuators(variety_state.attenuators, analysis)
    }
  end
  
  defp update_amplifiers(current_amplifiers, _analysis) do
    # Update amplifier list based on analysis
    current_amplifiers  # Simplified
  end
  
  defp update_attenuators(current_attenuators, _analysis) do
    # Update attenuator list based on analysis
    current_attenuators  # Simplified
  end
  
  # Private Functions - Meta-Synthesis
  
  defp perform_meta_synthesis(components, state) do
    %{
      # Key finding from synthesis
      key_finding: synthesize_key_finding(components),
      
      # Cross-component analysis
      internal_consistency: analyze_internal_consistency(components),
      cross_component_alignment: analyze_cross_alignment(components),
      temporal_stability: analyze_temporal_stability(components),
      goal_alignment: analyze_goal_alignment(components),
      
      # Emergent properties
      emergent_properties: identify_emergent_properties(components),
      
      # System-level insights
      system_coherence: calculate_system_coherence(components),
      adaptation_effectiveness: assess_adaptation_effectiveness(components),
      
      # Meta-findings
      novel_insights: extract_novel_insights(components, state),
      contradiction_resolved: false,
      major_limitation_discovered: check_major_limitations(components),
      
      # Metrics
      impact_score: calculate_impact_score(components),
      routine_significance: 0.5,
      significance: calculate_overall_significance(components),
      
      # Improvement paths
      improvement_opportunities: identify_improvements(components),
      
      # Variety-specific findings
      variety_capacity: components.self_assessment.variety_handling_capacity,
      learning_stagnation: detect_learning_stagnation(components),
      self_model_drift: calculate_self_model_drift(components)
    }
  end
  
  defp synthesize_key_finding(components) do
    # Extract the most important finding from all components
    findings = []
    
    # Check awareness component
    findings = if components.awareness.anomaly_count > 5 do
      ["System experiencing high anomaly rate" | findings]
    else
      findings
    end
    
    # Check self-assessment
    findings = if components.self_assessment.accuracy < 0.5 do
      ["Self-model accuracy below acceptable threshold" | findings]
    else
      findings
    end
    
    # Check decision patterns
    findings = if components.decision_patterns.confidence_trend == :declining do
      ["Decision confidence showing downward trend" | findings]
    else
      findings
    end
    
    # Return most significant finding
    if Enum.empty?(findings) do
      "System operating within normal parameters"
    else
      hd(findings)
    end
  end
  
  defp analyze_internal_consistency(components) do
    # Check if all components tell a consistent story
    consistency_score = 1.0
    
    # Check if high awareness correlates with good self-assessment
    consistency_score = if components.awareness.coherence > 0.8 &&
                          components.self_assessment.accuracy < 0.5 do
      consistency_score * 0.7
    else
      consistency_score
    end
    
    consistency_score
  end
  
  defp analyze_cross_alignment(components) do
    # Analyze alignment between components
    0.8  # Placeholder
  end
  
  defp analyze_temporal_stability(components) do
    # Check stability over time
    0.7  # Placeholder
  end
  
  defp analyze_goal_alignment(components) do
    # Check alignment with system goals
    0.9  # Placeholder
  end
  
  defp identify_emergent_properties(components) do
    properties = []
    
    # Check for meta-learning
    properties = if components.learning_metrics.effectiveness > 0.7 &&
                    components.self_assessment.accuracy > 0.7 do
      [:meta_learning_active | properties]
    else
      properties
    end
    
    # Check for self-organization
    properties = if length(components.decision_patterns) > 10 do
      [:self_organizing_patterns | properties]
    else
      properties
    end
    
    properties
  end
  
  defp calculate_system_coherence(components) do
    factors = [
      analyze_internal_consistency(components),
      analyze_cross_alignment(components),
      analyze_temporal_stability(components)
    ]
    
    Enum.sum(factors) / length(factors)
  end
  
  defp assess_adaptation_effectiveness(components) do
    if components.learning_metrics.effectiveness > 0.6 do
      :effective
    else
      :needs_improvement
    end
  end
  
  defp extract_novel_insights(components, state) do
    # Extract insights not previously known
    current_insights = MapSet.new(Enum.map(state.meta_insights, & &1.content))
    
    potential_insights = generate_potential_insights(components)
    
    Enum.filter(potential_insights, fn insight ->
      !MapSet.member?(current_insights, insight)
    end)
  end
  
  defp generate_potential_insights(components) do
    insights = []
    
    # Learning-awareness connection
    insights = if components.learning_metrics.effectiveness > 0.8 &&
                  components.awareness.awareness_level > 0.8 do
      ["High awareness enhances learning effectiveness" | insights]
    else
      insights
    end
    
    insights
  end
  
  defp check_major_limitations(components) do
    components.self_assessment.accuracy < 0.3 ||
    components.awareness.known_blind_spots > 5 ||
    components.decision_patterns.success_rate < 0.4
  end
  
  defp calculate_impact_score(components) do
    if check_major_limitations(components) do
      0.9
    else
      0.5
    end
  end
  
  defp calculate_overall_significance(components) do
    factors = [
      calculate_impact_score(components),
      length(extract_novel_insights(components, %{meta_insights: []})) / 10,
      if(check_major_limitations(components), do: 0.8, else: 0.3)
    ]
    
    Enum.sum(factors) / length(factors)
  end
  
  defp identify_improvements(components) do
    improvements = []
    
    improvements = if components.self_assessment.accuracy < 0.6 do
      ["Improve self-model calibration" | improvements]
    else
      improvements
    end
    
    improvements = if components.awareness.resource_pressure > 0.7 do
      ["Optimize resource utilization" | improvements]
    else
      improvements
    end
    
    improvements
  end
  
  defp detect_learning_stagnation(components) do
    components.learning_metrics.effectiveness < 0.3 ||
    components.learning_metrics.velocity < 0.1
  end
  
  defp calculate_self_model_drift(components) do
    abs(components.self_assessment.expected - components.self_assessment.actual)
  end
  
  # Private Functions - Computational Limits
  
  defp assess_computational_boundaries(state) do
    %{
      # Memory constraints
      memory_limits: assess_memory_constraints(),
      
      # Processing constraints
      processing_limits: assess_processing_constraints(),
      
      # Time constraints
      temporal_limits: assess_temporal_constraints(),
      
      # Complexity boundaries
      complexity_ceiling: determine_complexity_ceiling(state),
      
      # Overall assessment
      severity_score: 0.6,
      affects_all: false,
      
      # Specific bottlenecks
      bottlenecks: identify_computational_bottlenecks(state)
    }
  end
  
  defp assess_memory_constraints do
    %{
      working_memory_limit: "10MB active state",
      long_term_storage: "Bounded by disk",
      memory_pressure_threshold: 0.8,
      current_usage: 0.6
    }
  end
  
  defp assess_processing_constraints do
    %{
      max_concurrent_operations: 10,
      decision_time_limit: "5 seconds",
      reasoning_depth_limit: 10,
      pattern_complexity_limit: "O(n²)"
    }
  end
  
  defp assess_temporal_constraints do
    %{
      real_time_capability: false,
      minimum_response_time: "100ms",
      planning_horizon: "minutes to hours",
      learning_consolidation_time: "minutes"
    }
  end
  
  defp determine_complexity_ceiling(state) do
    # Determine maximum complexity the system can handle
    %{
      decision_complexity: estimate_max_decision_complexity(state),
      problem_size: estimate_max_problem_size(state),
      interaction_complexity: estimate_max_interaction_complexity(state),
      overall_ceiling: :moderate_to_high
    }
  end
  
  defp estimate_max_decision_complexity(_state) do
    "10-15 interacting factors"
  end
  
  defp estimate_max_problem_size(_state) do
    "1000-10000 elements"
  end
  
  defp estimate_max_interaction_complexity(_state) do
    "5-10 simultaneous interactions"
  end
  
  defp identify_computational_bottlenecks(state) do
    bottlenecks = []
    
    # Memory bottleneck
    bottlenecks = if length(state.meta_insights) > 1000 do
      [%{
        type: :memory_accumulation,
        impact: :medium,
        description: "Insight storage growing unbounded"
      } | bottlenecks]
    else
      bottlenecks
    end
    
    # Pattern matching bottleneck
    bottlenecks = if map_size(state.reasoning_patterns) > 100 do
      [%{
        type: :pattern_matching,
        impact: :high,
        description: "Pattern matching becoming O(n²)"
      } | bottlenecks]
    else
      bottlenecks
    end
    
    bottlenecks
  end
  
  defp update_computational_limitations(limitations, assessment) do
    new_computational = assessment.bottlenecks ++
                       limitations.computational
                       |> Enum.uniq_by(& &1.type)
                       |> Enum.take(10)
    
    %{limitations | computational: new_computational}
  end
  
  # Private Functions - Variety Constraints
  
  defp identify_systemic_variety_constraints(state) do
    %{
      structural_limits: identify_structural_limits(state),
      knowledge_limits: identify_knowledge_limits(state),
      adaptation_limits: identify_adaptation_limits(state),
      interaction_limits: identify_interaction_limits(state),
      
      # Overall constraint assessment
      constraint_level: calculate_overall_constraint_level(state),
      unhandled_variety: estimate_unhandled_variety(state),
      
      # Critical constraints
      critical_constraints: identify_critical_constraints(state)
    }
  end
  
  defp identify_structural_limits(_state) do
    %{
      hierarchical_depth: 5,
      parallel_capacity: 10,
      feedback_loops: 3,
      structural_flexibility: :limited
    }
  end
  
  defp identify_knowledge_limits(state) do
    %{
      domain_coverage: calculate_domain_coverage(state),
      knowledge_transfer_limit: 0.7,
      abstraction_capability: :moderate,
      tacit_knowledge_gap: :significant
    }
  end
  
  defp identify_adaptation_limits(_state) do
    %{
      adaptation_speed: :minutes,
      adaptation_scope: :local_changes,
      learning_transfer: :limited,
      structural_adaptation: :very_limited
    }
  end
  
  defp identify_interaction_limits(_state) do
    %{
      simultaneous_interactions: 5,
      interaction_complexity: :moderate,
      coordination_overhead: :high,
      communication_bandwidth: :limited
    }
  end
  
  defp calculate_overall_constraint_level(state) do
    # Assess how constrained the system is
    constraint_factors = [
      0.6,  # Structural constraints
      0.7,  # Knowledge constraints
      0.5,  # Adaptation constraints
      0.8   # Interaction constraints
    ]
    
    Enum.sum(constraint_factors) / length(constraint_factors)
  end
  
  defp estimate_unhandled_variety(state) do
    # Estimate what percentage of variety goes unhandled
    1.0 - state.variety_state.variety_ratio
  end
  
  defp identify_critical_constraints(state) do
    constraints = []
    
    # Critical variety gap
    constraints = if state.variety_state.variety_ratio < 0.2 do
      ["Critical variety gap - system handling < 20% of environmental variety" | constraints]
    else
      constraints
    end
    
    # Knowledge coverage
    constraints = if calculate_domain_coverage(state) < 0.3 do
      ["Insufficient knowledge coverage for variety handling" | constraints]
    else
      constraints
    end
    
    constraints
  end
  
  defp calculate_domain_coverage(_state) do
    # Calculate what percentage of necessary domains are covered
    0.6  # Placeholder
  end
  
  # Private Functions - Meta Insights
  
  defp compile_meta_insights(state) do
    %{
      recent_insights: Enum.take(state.meta_insights, 10),
      systemic_patterns: state.systemic_patterns,
      
      # Variety insights
      variety_insights: generate_variety_insights(state),
      
      # Limitation insights
      limitation_insights: generate_limitation_insights(state),
      
      # Reasoning insights
      reasoning_insights: generate_reasoning_insights(state),
      
      # Overall system insights
      system_insights: generate_system_insights(state)
    }
  end
  
  defp generate_variety_insights(state) do
    insights = []
    
    insights = if state.variety_state.variety_ratio < 0.3 do
      [%{
        type: :variety_gap,
        content: "System handling less than 30% of environmental variety",
        severity: :high,
        recommendation: "Implement additional variety amplifiers"
      } | insights]
    else
      insights
    end
    
    insights
  end
  
  defp generate_limitation_insights(state) do
    state.known_limitations
    |> Enum.flat_map(fn {type, limitations} ->
      Enum.map(Enum.take(limitations, 2), fn limitation ->
        %{
          type: type,
          limitation: limitation,
          impact: assess_limitation_impact(limitation)
        }
      end)
    end)
  end
  
  defp assess_limitation_impact(limitation) do
    # Assess impact of a specific limitation
    limitation[:impact] || :medium
  end
  
  defp generate_reasoning_insights(state) do
    patterns = Map.values(state.reasoning_patterns)
    
    if length(patterns) > 5 do
      [%{
        type: :reasoning_diversity,
        content: "Multiple reasoning patterns available",
        positive: true
      }]
    else
      [%{
        type: :reasoning_limitation,
        content: "Limited reasoning pattern diversity",
        recommendation: "Develop additional reasoning strategies"
      }]
    end
  end
  
  defp generate_system_insights(state) do
    [
      %{
        type: :overall_assessment,
        variety_handling: state.variety_state.variety_ratio,
        limitation_awareness: map_size(state.known_limitations) > 0,
        adaptation_capability: map_size(state.adaptation_strategies) > 3
      }
    ]
  end
  
  # Private Functions - Limitation Reasoning
  
  defp reason_about_specific_limitation(limitation, state) do
    %{
      # Understanding
      limitation_type: categorize_limitation(limitation),
      root_causes: analyze_root_causes(limitation, state),
      
      # Impact analysis
      direct_impact: assess_direct_impact(limitation),
      cascading_effects: identify_cascading_effects(limitation, state),
      
      # Workarounds
      possible_workarounds: generate_workarounds(limitation, state),
      mitigation_strategies: suggest_mitigations(limitation),
      
      # Meta-analysis
      fundamental_constraint: is_fundamental?(limitation),
      improvement_potential: assess_improvement_potential(limitation),
      
      # Recommendations
      recommendations: generate_limitation_recommendations(limitation, state)
    }
  end
  
  defp categorize_limitation(limitation) do
    cond do
      String.contains?(limitation.description || "", ["memory", "storage"]) -> :memory
      String.contains?(limitation.description || "", ["time", "speed"]) -> :temporal
      String.contains?(limitation.description || "", ["complex", "size"]) -> :complexity
      String.contains?(limitation.description || "", ["knowledge", "information"]) -> :knowledge
      true -> :general
    end
  end
  
  defp analyze_root_causes(limitation, _state) do
    case categorize_limitation(limitation) do
      :memory -> ["Finite storage capacity", "Information accumulation"]
      :temporal -> ["Processing speed limits", "Sequential constraints"]
      :complexity -> ["Combinatorial explosion", "Computational complexity"]
      :knowledge -> ["Incomplete information", "Learning boundaries"]
      _ -> ["System design constraints"]
    end
  end
  
  defp assess_direct_impact(limitation) do
    %{
      severity: limitation[:severity] || :medium,
      scope: limitation[:scope] || :local,
      frequency: limitation[:frequency] || :occasional
    }
  end
  
  defp identify_cascading_effects(limitation, _state) do
    case categorize_limitation(limitation) do
      :memory -> ["Reduced pattern storage", "Limited history retention"]
      :temporal -> ["Delayed responses", "Reduced real-time capability"]
      :complexity -> ["Simplified decision-making", "Reduced optimization"]
      :knowledge -> ["Uncertain decisions", "Limited predictions"]
      _ -> []
    end
  end
  
  defp generate_workarounds(limitation, _state) do
    case categorize_limitation(limitation) do
      :memory -> [
        "Implement forgetting mechanisms",
        "Use compression and summarization",
        "External storage integration"
      ]
      :temporal -> [
        "Pre-computation and caching",
        "Parallel processing",
        "Heuristic approximations"
      ]
      :complexity -> [
        "Decomposition strategies",
        "Hierarchical approaches",
        "Satisficing instead of optimizing"
      ]
      :knowledge -> [
        "Active learning strategies",
        "External knowledge sources",
        "Uncertainty quantification"
      ]
      _ -> ["General adaptation strategies"]
    end
  end
  
  defp suggest_mitigations(limitation) do
    severity = limitation[:severity] || :medium
    
    case severity do
      :critical -> ["Immediate architectural changes required"]
      :high -> ["Prioritize workaround implementation"]
      :medium -> ["Monitor and adapt as needed"]
      :low -> ["Accept and document limitation"]
      _ -> []
    end
  end
  
  defp is_fundamental?(limitation) do
    # Determine if limitation is fundamental to the system
    limitation[:fundamental] || 
    categorize_limitation(limitation) in [:memory, :temporal]
  end
  
  defp assess_improvement_potential(limitation) do
    if is_fundamental?(limitation) do
      :low
    else
      :moderate_to_high
    end
  end
  
  defp generate_limitation_recommendations(limitation, state) do
    recommendations = generate_workarounds(limitation, state)
    mitigations = suggest_mitigations(limitation)
    
    recommendations ++ mitigations
    |> Enum.uniq()
    |> Enum.take(5)
  end
  
  defp integrate_limitation_reasoning(state, limitation, reasoning) do
    # Store reasoning about this limitation
    limitation_key = {
      categorize_limitation(limitation),
      limitation[:description] || "unknown"
    }
    
    new_reasoning = Map.put(state.reasoning_patterns, limitation_key, reasoning)
    
    Map.put(state, :reasoning_patterns, new_reasoning)
  end
  
  # Private Functions - Periodic Analysis
  
  defp perform_periodic_meta_analysis(state) do
    %{
      variety_drift: calculate_variety_drift(state),
      limitation_evolution: track_limitation_changes(state),
      reasoning_effectiveness: assess_reasoning_effectiveness(state),
      emerging_patterns: detect_emerging_patterns(state)
    }
  end
  
  defp calculate_variety_drift(state) do
    # Detect changes in variety handling over time
    current_ratio = state.variety_state.variety_ratio
    
    %{
      current: current_ratio,
      trend: :stable,  # Would calculate from history
      concern_level: if(current_ratio < 0.3, do: :high, else: :low)
    }
  end
  
  defp track_limitation_changes(state) do
    # Track how limitations evolve
    total_limitations = state.known_limitations
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
    
    %{
      total_count: total_limitations,
      new_discoveries: 0,  # Would track new vs old
      resolved: 0  # Would track resolved limitations
    }
  end
  
  defp assess_reasoning_effectiveness(state) do
    # Assess how effective meta-reasoning has been
    pattern_count = map_size(state.reasoning_patterns)
    
    if pattern_count > 20 do
      :highly_effective
    elsif pattern_count > 10 do
      :effective
    else
      :developing
    end
  end
  
  defp detect_emerging_patterns(state) do
    # Detect new patterns in system behavior
    # Simplified - would use pattern detection algorithms
    []
  end
  
  defp integrate_periodic_findings(state, analysis) do
    # Update state based on periodic findings
    
    # Update systemic patterns if new ones found
    new_patterns = state.systemic_patterns ++ analysis.emerging_patterns
    
    state
    |> Map.put(:systemic_patterns, new_patterns)
    |> maybe_add_insight(analysis)
  end
  
  defp maybe_add_insight(state, analysis) do
    if analysis.variety_drift.concern_level == :high do
      insight = %{
        type: :variety_concern,
        content: "Variety handling capacity declining",
        timestamp: DateTime.utc_now(),
        data: analysis.variety_drift
      }
      
      Map.update!(state, :meta_insights, &[insight | &1])
    else
      state
    end
  end
  
  defp store_meta_insight(state, synthesis) do
    insight = %{
      type: :synthesis,
      content: synthesis.key_finding,
      significance: synthesis.significance,
      timestamp: DateTime.utc_now(),
      data: synthesis
    }
    
    Map.update!(state, :meta_insights, &[insight | &1])
  end
end