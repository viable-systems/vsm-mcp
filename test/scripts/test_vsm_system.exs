#!/usr/bin/env elixir

# Test script to verify all VSM system modules have required functions

IO.puts("Testing VSM System Modules...")

# Start the application
{:ok, _} = Application.ensure_all_started(:vsm_mcp)

# Test System1
IO.puts("\n=== Testing System1 ===")
status1 = VsmMcp.Systems.System1.get_status()
IO.inspect(status1, label: "System1 Status")

operation = %{type: :process, data: "test_data"}
{:ok, result} = VsmMcp.Systems.System1.execute_operation(operation)
IO.inspect(result, label: "System1 Operation Result")

# Test System2
IO.puts("\n=== Testing System2 ===")
status2 = VsmMcp.Systems.System2.get_status()
IO.inspect(status2, label: "System2 Status")

{:ok, coord_result} = VsmMcp.Systems.System2.coordinate_units([:unit1, :unit2])
IO.inspect(coord_result, label: "System2 Coordination Result")

variety_input = %{complexity: 0.8, data: "test"}
{:ok, transform_result} = VsmMcp.Systems.System2.transform_variety(variety_input, %{limit: 10})
IO.inspect(transform_result, label: "System2 Transform Result")

# Test System3
IO.puts("\n=== Testing System3 ===")
status3 = VsmMcp.Systems.System3.get_status()
IO.inspect(status3, label: "System3 Status")

{:ok, audit_result} = VsmMcp.Systems.System3.audit_all()
IO.inspect(audit_result, label: "System3 Audit All Result")

operations = [%{type: :compute, priority: 0.8}, %{type: :store, priority: 0.5}]
{:ok, coord_ops} = VsmMcp.Systems.System3.coordinate_operations(operations)
IO.inspect(coord_ops, label: "System3 Coordinate Operations Result")

# Test System4
IO.puts("\n=== Testing System4 ===")
status4 = VsmMcp.Systems.System4.get_status()
IO.inspect(status4, label: "System4 Status")

env_data = VsmMcp.Systems.System4.get_environmental_data()
IO.inspect(env_data, label: "System4 Environmental Data")

{:ok, analysis} = VsmMcp.Systems.System4.analyze_environment(:all, %{focus: :opportunities})
IO.inspect(analysis, label: "System4 Environment Analysis")

# Test System5
IO.puts("\n=== Testing System5 ===")
status5 = VsmMcp.Systems.System5.get_status()
IO.inspect(status5, label: "System5 Status")

context = %{type: :strategic, urgency: :high}
options = [
  %{name: "Option A", impact_score: 0.8, resources: %{budget: 50_000}},
  %{name: "Option B", impact_score: 0.6, resources: %{budget: 30_000}}
]
decision_result = VsmMcp.Systems.System5.make_decision(context, options)
IO.inspect(decision_result, label: "System5 Decision Result")

# Test ConsciousnessInterface
IO.puts("\n=== Testing ConsciousnessInterface ===")
ci_state = VsmMcp.ConsciousnessInterface.get_state()
IO.inspect(ci_state, label: "ConsciousnessInterface State")

decision = %{type: :operational, risk_level: 0.3}
criteria = %{weights: %{awareness: 0.3, learning: 0.4}}
assessment = VsmMcp.ConsciousnessInterface.assess_decision(decision, criteria)
IO.inspect(assessment, label: "Decision Assessment")

query_result = VsmMcp.ConsciousnessInterface.query(:consciousness_level, %{})
IO.inspect(query_result, label: "Consciousness Query Result")

IO.puts("\n✅ All VSM system modules are functioning correctly!")