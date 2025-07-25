#!/usr/bin/env elixir

# Full Autonomous VSM-MCP Demo
# Demonstrates the complete integrated system with all components working together

IO.puts """
=====================================
VSM-MCP Full Autonomous Demo
=====================================

This demo showcases:
1. All 5 VSM Systems working in harmony
2. MCP Server integration for AI tools
3. Variety Calculator with automatic capability acquisition
4. Consciousness Interface for meta-cognitive operations
5. Event Bus for inter-system communication
6. Pattern Engine for anomaly detection
"""

# Start the application
{:ok, _} = Application.ensure_all_started(:vsm_mcp)

# Wait for all systems to initialize
Process.sleep(2000)

IO.puts "\n=== System Status Check ===\n"

# Get system status
status = VsmMcp.system_status()
IO.inspect(status, label: "All Systems Status", pretty: true)

IO.puts "\n=== Demonstrating Operational Flow ===\n"

# 1. System 1 - Execute operations
IO.puts "1. System 1 - Executing operations..."
op1 = VsmMcp.execute_operation(%{type: :process, data: "customer_order_123"})
op2 = VsmMcp.execute_operation(%{type: :transform, input: "raw_data", output: "processed_data"})
IO.inspect(op1, label: "Process Operation")
IO.inspect(op2, label: "Transform Operation")

# 2. System 2 - Coordinate multiple units
IO.puts "\n2. System 2 - Coordinating units..."
coordination = VsmMcp.coordinate_task(
  [:order_processing, :inventory_management],
  %{name: "fulfill_order", priority: "high", order_id: "123"}
)
IO.inspect(coordination, label: "Coordination Result")

# 3. System 3 - Audit and optimize
IO.puts "\n3. System 3 - Auditing and optimizing..."
audit = VsmMcp.audit_and_optimize(:order_processing)
IO.inspect(audit, label: "Audit & Optimization")

# 4. System 4 - Environmental intelligence
IO.puts "\n4. System 4 - Environmental scanning..."
intelligence = VsmMcp.environmental_intelligence()
IO.inspect(intelligence, label: "Environmental Intelligence")

# 5. System 5 - Policy validation
IO.puts "\n5. System 5 - Validating strategic decision..."
decision = %{
  type: :strategic,
  description: "Expand into new market segment",
  resources: %{budget: 100_000, personnel: 10}
}
validation = VsmMcp.validate_decision(decision)
IO.inspect(validation, label: "Decision Validation")

IO.puts "\n=== Demonstrating Variety Management ===\n"

# Check variety gap
IO.puts "Calculating variety gap..."
variety_result = VsmMcp.Core.VarietyCalculator.calculate_variety_gap(
  %{capabilities: [:process, :transform], metrics: %{success_rate: 0.85}},
  %{complexity: 10, uncertainty: 5, rate_of_change: 3}
)
IO.inspect(variety_result, label: "Variety Analysis")

IO.puts "\n=== Demonstrating Consciousness Interface ===\n"

# Query consciousness
IO.puts "Querying consciousness interface..."
awareness = VsmMcp.ConsciousnessInterface.query(:awareness)
IO.inspect(awareness, label: "Consciousness Awareness")

# Make conscious decision
conscious_decision = VsmMcp.ConsciousnessInterface.make_conscious_decision(%{
  type: :strategic,
  options: ["expand", "consolidate", "pivot"],
  context: %{market_conditions: :volatile, resources: :limited}
})
IO.inspect(conscious_decision, label: "Conscious Decision")

IO.puts "\n=== Demonstrating Pattern Detection ===\n"

# Analyze patterns
IO.puts "Analyzing system patterns..."
pattern_data = [10, 12, 11, 13, 12, 14, 13, 15, 14, 16]
patterns = VsmMcp.Integrations.PatternEngineIntegration.analyze_patterns(pattern_data)
IO.inspect(patterns, label: "Pattern Analysis")

# Detect anomalies
anomaly_data = [10, 11, 12, 11, 45, 12, 11, 10]  # 45 is an anomaly
anomalies = VsmMcp.Integrations.PatternEngineIntegration.detect_anomalies(anomaly_data)
IO.inspect(anomalies, label: "Anomaly Detection")

IO.puts "\n=== Demonstrating Event-Driven Coordination ===\n"

# Subscribe to events
VsmMcp.Integrations.EventBusIntegration.subscribe_all()

# Emit a variety gap event
IO.puts "Emitting variety gap event..."
VsmMcp.Integrations.EventBusIntegration.emit_variety_gap(%{
  system_variety: 10,
  environmental_variety: 15,
  gap: %{ratio: 0.67, critical_areas: ["operational_capabilities"]},
  acquisition_needed: true
})

# Emit consciousness insight
IO.puts "Emitting consciousness insight..."
VsmMcp.Integrations.EventBusIntegration.emit_consciousness_insight(%{
  type: :strategic,
  insight: "Market conditions suggest pivot opportunity",
  confidence: 0.85,
  recommendation: "Consider new product line"
})

Process.sleep(1000)

IO.puts "\n=== Demonstrating Autonomous Adaptation ===\n"

# Simulate environmental change
IO.puts "Simulating environmental change requiring adaptation..."

# 1. System 4 detects change
env_change = %{
  type: :market_shift,
  severity: :high,
  opportunities: ["new_segment", "technology_adoption"],
  threats: ["competitor_entry", "regulation_change"]
}

# 2. System 5 makes policy decision
policy_decision = VsmMcp.Systems.System5.validate_decision(
  %{type: :adaptive, response_to: env_change},
  %{urgency: :high}
)
IO.inspect(policy_decision, label: "Policy Response")

# 3. System 3 optimizes resources
resource_optimization = VsmMcp.Systems.System3.optimize_resources(%{
  constraint: :budget,
  objective: :maximize_adaptation_speed
})
IO.inspect(resource_optimization, label: "Resource Optimization")

# 4. System 2 coordinates implementation
implementation = VsmMcp.Systems.System2.coordinate(
  [:development, :marketing, :operations],
  %{name: "market_adaptation", plan: resource_optimization}
)
IO.inspect(implementation, label: "Coordinated Implementation")

# 5. System 1 executes new operations
new_operations = [
  %{type: :process, data: "new_market_analysis"},
  %{type: :transform, input: "market_data", output: "strategic_insights"}
]

Enum.each(new_operations, fn op ->
  result = VsmMcp.Systems.System1.execute_operation(op)
  IO.inspect(result, label: "New Operation")
end)

IO.puts "\n=== MCP Server Integration ===\n"

# List available MCP tools
IO.puts "Available MCP tools:"
{:ok, tools} = VsmMcp.Interfaces.MCPServer.list_tools()
Enum.each(tools, fn tool ->
  IO.puts "  - #{tool.name}: #{tool.description}"
end)

IO.puts "\n=== Final System Report ===\n"

# Generate comprehensive report
final_status = VsmMcp.system_status()
variety_report = VsmMcp.Core.VarietyCalculator.get_variety_report()
consciousness_report = VsmMcp.ConsciousnessInterface.generate_awareness_report()
pattern_report = VsmMcp.Integrations.PatternEngineIntegration.get_pattern_report()

IO.puts """
System Health Summary:
- System 1: #{inspect(final_status.system1.active)}
- System 2: #{inspect(Map.get(final_status.system2, :status, :unknown))}
- System 3: #{inspect(Map.get(final_status.system3, :effectiveness, :unknown))}
- System 4: #{inspect(Map.get(final_status.system4, :scanning, :unknown))}
- System 5: #{inspect(final_status.system5.overall_score)}

Variety Management:
- Recent calculations: #{variety_report.metrics.calculations}
- Gaps detected: #{variety_report.metrics.gaps_detected}
- Acquisitions triggered: #{variety_report.metrics.acquisitions_triggered}

Consciousness Level:
- Awareness: #{consciousness_report.awareness_level}
- Insights: #{length(consciousness_report.recent_insights)}
- Coherence: #{consciousness_report.system_coherence.overall_coherence}

Pattern Recognition:
- Patterns analyzed: #{pattern_report.metrics.patterns_analyzed}
- Anomalies detected: #{pattern_report.metrics.anomalies_detected}
- Active models: #{length(pattern_report.active_models)}
"""

IO.puts "\n=====================================\nDemo Complete! The VSM-MCP system is fully operational and autonomous.\n====================================="