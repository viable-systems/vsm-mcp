#!/usr/bin/env elixir

# Consciousness Interface Demo
# This script demonstrates the meta-cognitive capabilities of the VSM consciousness interface

IO.puts("\n🧠 VSM Consciousness Interface Demo")
IO.puts("=" <> String.duplicate("=", 50))

# Start the application
{:ok, _} = Application.ensure_all_started(:vsm_mcp)
Process.sleep(500)  # Allow initialization

IO.puts("\n1️⃣ Initial Consciousness State")
IO.puts("-" <> String.duplicate("-", 30))

initial_state = VsmMcp.get_consciousness_state()
IO.puts("Consciousness Level: #{initial_state.consciousness_level}")
IO.puts("Meta-insights: #{length(initial_state.meta_insights)}")
IO.puts("Recent Reflections: #{length(initial_state.recent_reflections)}")

IO.puts("\n2️⃣ Performing Meta-Cognitive Reflection")
IO.puts("-" <> String.duplicate("-", 30))

reflection = VsmMcp.reflect_on_consciousness(%{
  trigger: :demo,
  purpose: "Demonstrate consciousness capabilities"
})

IO.puts("Primary Insight: #{reflection.primary_insight}")
IO.puts("Consciousness Coherence: #{Float.round(reflection.consciousness_coherence, 2)}")
IO.puts("Self-Model Accuracy: #{Float.round(reflection.self_model_accuracy, 2)}")
IO.puts("Learning Effectiveness: #{Float.round(reflection.learning_effectiveness, 2)}")
IO.puts("Variety Handling Capacity: #{Float.round(reflection.variety_handling_capacity, 2)}")

IO.puts("\nLimitations Identified:")
Enum.each(reflection.limitations_identified, fn limitation ->
  IO.puts("  • #{inspect(limitation)}")
end)

IO.puts("\nRecommendations:")
Enum.each(reflection.recommendations, fn rec ->
  IO.puts("  • #{rec}")
end)

IO.puts("\n3️⃣ Variety Gap Analysis")
IO.puts("-" <> String.duplicate("-", 30))

variety_analysis = VsmMcp.analyze_variety_gaps()

IO.puts("Variety Gap Magnitude: #{variety_analysis.variety_gap.magnitude}")
IO.puts("Critical: #{variety_analysis.variety_gap.critical}")
IO.puts("Variety Ratio: #{variety_analysis.variety_gap.ratio}")

IO.puts("\nSpecific Gaps:")
Enum.each(variety_analysis.gaps, fn gap ->
  IO.puts("  • #{gap.type} (#{gap.severity}): #{gap.description}")
end)

IO.puts("\nActive Amplifiers: #{variety_analysis.amplifiers_active.count}")
IO.puts("Amplifier Effectiveness: #{Float.round(variety_analysis.amplifiers_active.effectiveness, 2)}")

IO.puts("\nVariety Recommendations:")
Enum.each(variety_analysis.recommendations, fn rec ->
  IO.puts("  • [#{rec.priority}] #{rec.suggestion}")
end)

IO.puts("\n4️⃣ Decision Tracing Demo")
IO.puts("-" <> String.duplicate("-", 30))

# Trace a sample decision
decision = %{
  type: :strategic,
  action: "Implement consciousness monitoring dashboard",
  alternatives: [
    %{
      action: "Basic metrics only",
      pros: ["Simple", "Fast to implement"],
      cons: ["Limited insight", "No meta-cognition"]
    },
    %{
      action: "Full consciousness interface",
      pros: ["Complete visibility", "Meta-cognitive insights"],
      cons: ["Complex", "Resource intensive"]
    }
  ]
}

rationale = %{
  primary: "Need visibility into system consciousness state",
  supporting: [
    "Enables proactive system optimization",
    "Provides meta-cognitive insights",
    "Supports variety gap management"
  ],
  confidence: 0.85,
  assumptions: ["Resources available", "Team has expertise"]
}

context = %{
  trigger: :system_improvement,
  goals: [:enhance_visibility, :improve_adaptability],
  time_pressure: :medium
}

trace = VsmMcp.trace_decision(decision, rationale, context)

IO.puts("Decision ID: #{trace.id}")
IO.puts("Decision Type: #{trace.decision.type}")
IO.puts("Action: #{trace.decision.action}")
IO.puts("Confidence Level: #{trace.confidence.level}")
IO.puts("Alternatives Considered: #{length(trace.alternatives)}")

IO.puts("\n5️⃣ System Limitations Assessment")
IO.puts("-" <> String.duplicate("-", 30))

limitations = VsmMcp.assess_limitations()

IO.puts("Overall Assessment:")
IO.puts("  • Severity: #{limitations.overall_assessment.severity}")
IO.puts("  • Primary Bottleneck: #{limitations.overall_assessment.primary_bottleneck}")

IO.puts("\nComputational Limitations:")
Enum.each(limitations.computational, fn limit ->
  IO.puts("  • #{inspect(limit)}")
end)

IO.puts("\nKnowledge Limitations:")
Enum.each(limitations.knowledge, fn gap ->
  IO.puts("  • #{inspect(gap)}")
end)

IO.puts("\nImprovement Paths:")
Enum.each(limitations.improvement_paths, fn path ->
  IO.puts("  • [#{path.priority}] #{path.type} → #{path.target}")
end)

IO.puts("\n6️⃣ Simulating Learning from Experience")
IO.puts("-" <> String.duplicate("-", 30))

# Update self-model with observations
VsmMcp.ConsciousnessInterface.update_self_model([
  %{type: :performance, success: true, confidence: 0.9},
  %{type: :capability_demonstrated, capability_path: [:reasoning, :meta_reasoning]},
  %{type: :behavior_pattern, pattern_type: :reflective_analysis}
])

# Simulate outcome and learning
outcome = %{
  status: :success,
  result: "Successfully implemented consciousness monitoring"
}

analysis = %{
  thorough_analysis: true,
  learned_from_past: true,
  high_complexity: true
}

VsmMcp.ConsciousnessInterface.learn_from_outcome(trace.id, outcome, analysis)

Process.sleep(200)  # Allow async processing

IO.puts("Learning cycle completed!")

IO.puts("\n7️⃣ Final Consciousness State")
IO.puts("-" <> String.duplicate("-", 30))

final_state = VsmMcp.get_consciousness_state()

IO.puts("Final Consciousness Level: #{final_state.consciousness_level}")
IO.puts("Meta-insights Generated: #{length(final_state.meta_insights)}")

# Show awareness state
awareness = VsmMcp.ConsciousnessInterface.get_awareness_state()
IO.puts("\nAwareness State:")
IO.puts("  • Resource Pressure: #{Float.round(awareness.resources.memory_pressure, 2)}")
IO.puts("  • Process Health: #{awareness.processes.consciousness_health}")
IO.puts("  • Active Patterns: #{length(awareness.active_patterns)}")
IO.puts("  • Current Anomalies: #{length(awareness.anomalies)}")
IO.puts("  • Awareness Level: #{Float.round(awareness.awareness_level, 2)}")

IO.puts("\n✅ Consciousness Interface Demo Complete!")
IO.puts("\nThe VSM system now has meta-cognitive capabilities including:")
IO.puts("  • Self-awareness and reflection")
IO.puts("  • Dynamic self-model updating")
IO.puts("  • Decision tracing and learning")
IO.puts("  • Variety gap analysis")
IO.puts("  • Limitation awareness")
IO.puts("  • Meta-reasoning about system boundaries")

IO.puts("\nThis enables the system to understand and adapt to its own limitations,")
IO.puts("continuously improving its decision-making and variety handling capabilities.")
IO.puts("")