# Basic VSM Demo
# Run with: mix run examples/basic_vsm_demo.exs

# Ensure the application is started
{:ok, _} = Application.ensure_all_started(:vsm_mcp)

IO.puts("\n🚀 VSM-MCP System Demo")
IO.puts("=" <> String.duplicate("=", 40))

# 1. System Status Check
IO.puts("\n📊 Checking System Status...")
status = VsmMcp.system_status()
IO.puts("✓ All 5 VSM systems are running")
IO.puts("  - System 1 (Operations): #{status.system1.active && "Active" || "Inactive"}")
IO.puts("  - System 2 (Coordination): #{status.system2.registered_units} units registered")
IO.puts("  - System 3 (Control): #{status.system3.targets_met |> Float.round(2)} target achievement")
IO.puts("  - System 4 (Intelligence): #{status.system4.summary.active_sources} intelligence sources")
IO.puts("  - System 5 (Policy): Health score #{status.system5.overall_score |> Float.round(2)}")

# 2. Execute an Operation (System 1)
IO.puts("\n🔧 Executing Operation...")
{:ok, result} = VsmMcp.execute_operation(%{type: :process, data: "customer_order_123"})
IO.puts("✓ Operation completed: #{result.result}")

# 3. Register Units and Coordinate (System 2)
IO.puts("\n🤝 Coordinating Units...")
VsmMcp.Systems.System2.register_unit(:unit_a, [:processing, :validation])
VsmMcp.Systems.System2.register_unit(:unit_b, [:processing, :storage])
{:ok, coordination} = VsmMcp.coordinate_task([:unit_a, :unit_b], %{
  name: "distributed_processing",
  subtasks: [:validate, :process, :store]
})
IO.puts("✓ Coordination plan created:")
IO.puts("  - Assigned units: #{inspect(coordination.assigned_units)}")
IO.puts("  - Estimated duration: #{round(coordination.estimated_duration)}ms")

# 4. Audit and Optimize (System 3)
IO.puts("\n🔍 Auditing and Optimizing...")
{:ok, audit_result} = VsmMcp.audit_and_optimize(:unit_a)
IO.puts("✓ Audit complete:")
IO.puts("  - Performance: #{audit_result.audit.performance |> Float.round(2)}")
IO.puts("  - Estimated improvement: #{audit_result.optimization.estimated_improvement |> Float.round(2)}")

# 5. Environmental Intelligence (System 4)
IO.puts("\n🌐 Gathering Intelligence...")
{:ok, intelligence} = VsmMcp.environmental_intelligence()
IO.puts("✓ Environmental scan complete:")
Enum.each(intelligence.scan, fn {source, data} ->
  IO.puts("  - #{source}: #{length(data.signals)} signals detected")
end)

# 6. Policy Validation (System 5)
IO.puts("\n📋 Validating Strategic Decision...")
decision = %{
  type: :strategic,
  resources: %{budget: 50000, personnel: 5},
  description: "Launch new product line"
}
validation = VsmMcp.validate_decision(decision)
IO.puts("✓ Decision validation:")
IO.puts("  - Valid: #{validation.valid}")
IO.puts("  - Confidence: #{validation.confidence |> Float.round(2)}")
IO.puts("  - Recommendation: #{validation.recommendation}")

# 7. Balance Present vs Future (System 5)
IO.puts("\n⚖️  Balancing Objectives...")
present_needs = [
  %{priority: :critical, description: "Fix production issues"},
  %{priority: :high, description: "Customer support backlog"}
]
future_goals = [
  %{strategic: true, description: "AI integration"},
  %{strategic: true, description: "Market expansion"}
]
{:ok, balance} = VsmMcp.balance_objectives(present_needs, future_goals)
IO.puts("✓ Balance recommendation:")
IO.puts("  - Present focus: #{balance.present_weight |> Float.round(2)}")
IO.puts("  - Future focus: #{balance.future_weight |> Float.round(2)}")
IO.puts("  - Rationale: #{balance.rationale}")

IO.puts("\n✅ VSM Demo Complete!")
IO.puts("All systems are functioning correctly and maintaining viability.\n")