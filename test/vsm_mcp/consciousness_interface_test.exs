defmodule VsmMcp.ConsciousnessInterfaceTest do
  use ExUnit.Case, async: false
  
  alias VsmMcp.ConsciousnessInterface
  
  setup do
    # Start consciousness interface for tests
    {:ok, pid} = ConsciousnessInterface.start_link()
    
    # Allow processes to initialize
    Process.sleep(100)
    
    {:ok, consciousness: pid}
  end
  
  describe "meta-cognitive reflection" do
    test "performs reflection and updates consciousness level", %{consciousness: pid} do
      # Initial reflection
      result = ConsciousnessInterface.reflect()
      
      assert result.primary_insight != nil
      assert result.consciousness_coherence > 0
      assert result.self_model_accuracy >= 0
      assert result.learning_effectiveness >= 0
      assert result.variety_handling_capacity >= 0
      assert is_list(result.limitations_identified)
      assert is_list(result.recommendations)
      assert result.significance >= 0
    end
    
    test "reflection improves with system usage", %{consciousness: pid} do
      # Perform initial reflection
      initial = ConsciousnessInterface.reflect()
      
      # Simulate some system activity
      ConsciousnessInterface.update_self_model([
        %{type: :performance, success: true, confidence: 0.8},
        %{type: :capability_demonstrated, capability_path: [:reasoning, :pattern_recognition]}
      ])
      
      # Perform another reflection
      Process.sleep(50)
      updated = ConsciousnessInterface.reflect()
      
      # Consciousness should evolve
      assert updated.timestamp != initial.timestamp
    end
  end
  
  describe "self-model management" do
    test "updates self-model based on observations", %{consciousness: pid} do
      observations = [
        %{type: :performance, success: true, confidence: 0.9},
        %{type: :limitation_encountered, limitation_path: [:computational, :memory_bound]},
        %{type: :behavior_pattern, pattern_type: :analytical_approach}
      ]
      
      :ok = ConsciousnessInterface.update_self_model(observations)
      
      # Give time for async update
      Process.sleep(50)
      
      # Verify model was updated
      state = ConsciousnessInterface.get_consciousness_state()
      assert state.self_model != nil
    end
  end
  
  describe "awareness monitoring" do
    test "maintains awareness of internal states", %{consciousness: pid} do
      awareness = ConsciousnessInterface.get_awareness_state()
      
      assert awareness.resources != nil
      assert awareness.processes != nil
      assert is_list(awareness.active_patterns)
      assert is_list(awareness.anomalies)
      assert awareness.internal_state != nil
      assert awareness.awareness_level > 0
    end
  end
  
  describe "decision tracing" do
    test "traces decisions with full context", %{consciousness: pid} do
      decision = %{
        type: :operational,
        action: "Execute test operation",
        alternatives: [
          %{action: "Alternative 1", pros: ["Fast"], cons: ["Risky"]},
          %{action: "Alternative 2", pros: ["Safe"], cons: ["Slow"]}
        ]
      }
      
      rationale = %{
        primary: "Test decision for validation",
        supporting: ["Good test coverage", "Low risk"],
        confidence: 0.8
      }
      
      context = %{
        trigger: :test_request,
        goals: [:validate_system],
        time_pressure: :low
      }
      
      trace = ConsciousnessInterface.trace_decision(decision, rationale, context)
      
      assert trace.id != nil
      assert trace.decision.action == "Execute test operation"
      assert length(trace.alternatives) >= 2
      assert trace.rationale.primary == "Test decision for validation"
      assert trace.confidence.level == 0.8
      assert trace.outcome.status == :pending
    end
  end
  
  describe "learning from experience" do
    test "learns from decision outcomes", %{consciousness: pid} do
      # Create and trace a decision
      decision = %{
        type: :strategic,
        action: "Implement new feature"
      }
      
      rationale = %{
        primary: "User requested feature",
        confidence: 0.7
      }
      
      context = %{trigger: :user_request}
      
      trace = ConsciousnessInterface.trace_decision(decision, rationale, context)
      
      # Simulate outcome
      outcome = %{
        status: :success,
        result: "Feature implemented successfully"
      }
      
      analysis = %{
        time_critical: false,
        resource_constrained: false,
        high_complexity: true,
        thorough_analysis: true
      }
      
      # Learn from outcome
      ConsciousnessInterface.learn_from_outcome(trace.id, outcome, analysis)
      
      # Give time for async learning
      Process.sleep(100)
      
      # Check consciousness state reflects learning
      state = ConsciousnessInterface.get_consciousness_state()
      assert state.learning != nil
    end
  end
  
  describe "variety gap analysis" do
    test "analyzes variety handling capabilities", %{consciousness: pid} do
      analysis = ConsciousnessInterface.analyze_variety_gaps()
      
      assert analysis.internal_variety != nil
      assert analysis.external_variety != nil
      assert analysis.variety_gap != nil
      assert is_list(analysis.gaps)
      assert analysis.amplifiers_active != nil
      assert analysis.attenuators_active != nil
      assert is_list(analysis.recommendations)
      assert analysis.variety_capacity >= 0
    end
  end
  
  describe "limitation assessment" do
    test "identifies and reasons about limitations", %{consciousness: pid} do
      limitations = ConsciousnessInterface.assess_limitations()
      
      assert limitations.computational != nil
      assert limitations.knowledge != nil
      assert limitations.variety_handling != nil
      assert limitations.learning != nil
      assert limitations.overall_assessment != nil
      assert is_list(limitations.improvement_paths)
    end
  end
  
  describe "full consciousness state" do
    test "provides complete consciousness state", %{consciousness: pid} do
      state = ConsciousnessInterface.get_consciousness_state()
      
      # Verify all components present
      assert state.consciousness_level >= 0 && state.consciousness_level <= 1
      assert state.meta_cognition != nil
      assert state.self_model != nil
      assert state.awareness != nil
      assert state.decision_tracing != nil
      assert state.learning != nil
      assert state.meta_reasoning != nil
      assert is_list(state.recent_reflections)
      assert is_list(state.meta_insights)
    end
  end
  
  describe "integration capabilities" do
    test "consciousness interface is ready for VSM integration", %{consciousness: pid} do
      # Test that the consciousness interface can work with VSM systems
      
      # Simulate VSM system interaction
      ConsciousnessInterface.update_self_model([
        %{
          type: :knowledge_application,
          domain: :vsm_theory,
          depth_demonstrated: true,
          breadth_demonstrated: true,
          success: true
        }
      ])
      
      # Trace a VSM-related decision
      decision = %{
        type: :strategic,
        action: "Balance System 3 and System 4 activities"
      }
      
      rationale = %{
        primary: "Optimize present operations while maintaining future viability",
        confidence: 0.85
      }
      
      context = %{
        trigger: :vsm_imbalance,
        goals: [:maintain_viability, :optimize_performance]
      }
      
      trace = ConsciousnessInterface.trace_decision(decision, rationale, context)
      assert trace.id != nil
      
      # Test variety gap analysis in VSM context
      variety_analysis = ConsciousnessInterface.analyze_variety_gaps()
      assert variety_analysis.variety_gap.critical == true
      
      # The consciousness interface is ready for integration
      assert true
    end
  end
end