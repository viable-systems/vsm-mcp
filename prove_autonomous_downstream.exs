#!/usr/bin/env elixir

# PROOF OF AUTONOMOUS VSM-MCP OPERATION
# This demonstrates the system autonomously detecting and responding to a real downstream task

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║  AUTONOMOUS VSM-MCP DOWNSTREAM TASK DEMONSTRATION         ║
║  Proving Real Autonomous Capability Acquisition           ║
╚═══════════════════════════════════════════════════════════╝
"""

# Start the VSM-MCP application
{:ok, _} = Application.ensure_all_started(:vsm_mcp)

# Choose a random downstream task that requires capabilities we don't have
downstream_tasks = [
  %{
    name: "Generate Financial Report PDF",
    required_capabilities: ["pdf_generation", "chart_creation", "data_visualization"],
    description: "Create a PDF financial report with charts and graphs"
  },
  %{
    name: "Analyze GitHub Repository",
    required_capabilities: ["github_api", "code_analysis", "complexity_metrics"],
    description: "Analyze a GitHub repository for code quality and metrics"
  },
  %{
    name: "Process Natural Language Query",
    required_capabilities: ["nlp_processing", "entity_extraction", "sentiment_analysis"],
    description: "Process and analyze natural language text"
  },
  %{
    name: "Generate API Documentation",
    required_capabilities: ["openapi_spec", "markdown_generation", "api_testing"],
    description: "Generate comprehensive API documentation from code"
  }
]

# Pick a random task
task = Enum.random(downstream_tasks)

IO.puts "\n🎯 DOWNSTREAM TASK SELECTED:"
IO.puts "   Task: #{task.name}"
IO.puts "   Description: #{task.description}"
IO.puts "   Required Capabilities: #{inspect(task.required_capabilities)}"

# Start the daemon mode to enable autonomous monitoring
IO.puts "\n🚀 Starting Autonomous Daemon Mode..."
{:ok, daemon_pid} = VsmMcp.DaemonMode.start_link(interval: 5_000) # 5 second interval for demo

# Inject the downstream task as a variety gap
IO.puts "\n📊 Injecting variety gap for: #{task.name}"
VsmMcp.Integration.VarietyDetector.inject_variety_gap(%{
  type: :capability_requirement,
  severity: :high,
  required_capabilities: task.required_capabilities,
  task_description: task.description,
  timestamp: DateTime.utc_now()
})

# Let the autonomous system work
IO.puts "\n⏳ Autonomous system is now operating..."
IO.puts "   Monitoring variety gaps..."
IO.puts "   Searching for MCP servers..."
IO.puts "   Evaluating capabilities..."
IO.puts "   Making autonomous decisions..."

# Monitor the autonomous operation
monitor_task = Task.async(fn ->
  Enum.each(1..30, fn i ->
    Process.sleep(1000)
    
    # Check daemon status
    status = VsmMcp.DaemonMode.get_status(daemon_pid)
    
    # Check discovered servers
    discovered = VsmMcp.Core.MCPDiscovery.list_discovered_servers()
    
    # Check integration status
    integrated = VsmMcp.Integration.ServerManager.list_servers()
    
    IO.puts "\n📊 [#{i}s] Autonomous Status:"
    IO.puts "   Daemon: #{status.state}"
    IO.puts "   Discovered Servers: #{length(discovered)}"
    IO.puts "   Integrated Servers: #{length(integrated)}"
    
    if status.last_decision do
      IO.puts "   Last Decision: #{status.last_decision.action} - #{status.last_decision.reason}"
    end
    
    # Check if we've acquired the needed capabilities
    current_capabilities = VsmMcp.Integration.CapabilityMatcher.get_all_capabilities()
    acquired = Enum.filter(task.required_capabilities, &(&1 in current_capabilities))
    
    if length(acquired) > 0 do
      IO.puts "   ✅ Acquired Capabilities: #{inspect(acquired)}"
    end
    
    # If all capabilities acquired, we're done
    if length(acquired) == length(task.required_capabilities) do
      IO.puts "\n🎉 SUCCESS! All required capabilities autonomously acquired!"
      :success
    else
      :continue
    end
  end)
end)

# Wait for completion or timeout
result = Task.await(monitor_task, 35_000)

# Get final report
IO.puts "\n📋 FINAL AUTONOMOUS OPERATION REPORT:"

# Show consciousness interface activity
consciousness_state = VsmMcp.ConsciousnessInterface.get_awareness_state()
IO.puts "\n🧠 Consciousness Interface Activity:"
IO.puts "   Awareness Level: #{consciousness_state.awareness_level}"
IO.puts "   Decisions Made: #{length(consciousness_state.recent_decisions)}"
IO.puts "   Learning Events: #{consciousness_state.learning_count}"

# Show what servers were discovered and integrated
discovered_servers = VsmMcp.Core.MCPDiscovery.list_discovered_servers()
integrated_servers = VsmMcp.Integration.ServerManager.list_servers()

IO.puts "\n🔍 Autonomous Discovery Results:"
Enum.each(discovered_servers, fn server ->
  IO.puts "   • #{server.name} - Score: #{server.score}/100"
  IO.puts "     Capabilities: #{inspect(server.capabilities)}"
end)

IO.puts "\n🔌 Autonomous Integration Results:"
Enum.each(integrated_servers, fn {_id, server} ->
  IO.puts "   • #{server.name} - Status: #{server.status}"
  IO.puts "     Protocol: #{server.protocol}"
  if server.health_check do
    IO.puts "     Health: #{server.health_check.status}"
  end
end)

# Verify the task can now be completed
final_capabilities = VsmMcp.Integration.CapabilityMatcher.get_all_capabilities()
task_possible = Enum.all?(task.required_capabilities, &(&1 in final_capabilities))

IO.puts "\n✨ AUTONOMOUS PROOF RESULTS:"
IO.puts "   Task: #{task.name}"
IO.puts "   Required: #{inspect(task.required_capabilities)}"
IO.puts "   Acquired: #{inspect(final_capabilities -- ["base", "core"])}"
IO.puts "   Task Possible: #{task_possible}"

if task_possible do
  IO.puts "\n🏆 PROOF COMPLETE: The VSM-MCP system autonomously:"
  IO.puts "   1. Detected the variety gap from the downstream task"
  IO.puts "   2. Searched for appropriate MCP servers"
  IO.puts "   3. Evaluated and ranked server capabilities"
  IO.puts "   4. Made autonomous integration decisions"
  IO.puts "   5. Acquired the necessary capabilities"
  IO.puts "   6. Can now complete the downstream task!"
else
  IO.puts "\n⚠️  Autonomous operation in progress..."
end

# Stop the daemon
IO.puts "\n🛑 Stopping autonomous daemon..."
GenServer.stop(daemon_pid)

IO.puts "\n✅ Demonstration complete!"