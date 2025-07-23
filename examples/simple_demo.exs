#!/usr/bin/env elixir

# Simple VSM-MCP Demo
# A quick demonstration of basic VSM operations

IO.puts """
=====================================
VSM-MCP Simple Demo
=====================================
"""

# Start the application
{:ok, _} = Application.ensure_all_started(:vsm_mcp)
Process.sleep(1000)

# Execute a simple operation
IO.puts "1. Executing a simple operation..."
result = VsmMcp.execute_operation(%{type: :process, data: "Hello VSM!"})
IO.inspect(result, label: "Operation Result")

# Get system status
IO.puts "\n2. Checking system status..."
status = VsmMcp.system_status()
IO.puts "All systems operational: #{inspect(Map.keys(status))}"

# Make a decision
IO.puts "\n3. Validating a decision..."
decision = VsmMcp.validate_decision(%{
  type: :operational,
  description: "Process customer request",
  resources: %{time: 5, personnel: 1}
})
IO.puts "Decision valid: #{decision.valid}"
IO.puts "Recommendation: #{decision.recommendation}"

IO.puts "\nSimple demo complete!"