#!/usr/bin/env elixir

# Test script to verify that VSM-MCP System1 requires real MCP servers
# and doesn't fall back to simulation

require Logger

Logger.configure(level: :debug)

# Start the application
{:ok, _} = Application.ensure_all_started(:vsm_mcp)

# Test 1: Try to process an operation without MCP capability
Logger.info("=== Test 1: Process operation without MCP ===")
operation = %{type: :unknown_capability, data: "test data"}
result = VsmMcp.Systems.System1.execute_operation(operation)
IO.inspect(result, label: "Result")

# Test 2: Try to transform data without MCP capability
Logger.info("\n=== Test 2: Transform operation without MCP ===")
transform_op = %{type: :transform, input: "input data", output: "output format"}
result2 = VsmMcp.Systems.System1.execute_operation(transform_op)
IO.inspect(result2, label: "Result")

# Test 3: Try to acquire a capability via MCP (should fail without real MCP server)
Logger.info("\n=== Test 3: Acquire capability via MCP ===")
capability_op = %{
  type: :capability_acquisition,
  target: :document_creation,
  method: :mcp_integration
}
result3 = VsmMcp.Systems.System1.execute_operation(capability_op)
IO.inspect(result3, label: "Result")

# Test 4: Try unknown acquisition method (should fail)
Logger.info("\n=== Test 4: Unknown acquisition method ===")
unknown_op = %{
  type: :capability_acquisition,
  target: :image_generation,
  method: :unknown_method
}
result4 = VsmMcp.Systems.System1.execute_operation(unknown_op)
IO.inspect(result4, label: "Result")

# Test 5: Check system status
Logger.info("\n=== Test 5: System Status ===")
status = VsmMcp.Systems.System1.get_status()
IO.inspect(status, label: "System Status")

Logger.info("\n=== All tests completed ===")
Logger.info("The system should now properly require real MCP servers and not fall back to simulation.")