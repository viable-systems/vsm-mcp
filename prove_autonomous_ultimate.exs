#!/usr/bin/env elixir

# ULTIMATE PROOF OF AUTONOMOUS VSM-MCP
# NO HOLDS BARRED - REAL EXECUTION

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║     ULTIMATE AUTONOMOUS VSM-MCP DEMONSTRATION              ║
║     REAL VARIETY GAP → REAL ACQUISITION → REAL PROOF      ║
╚═══════════════════════════════════════════════════════════╝
"""

# Ensure we're in the right directory
File.cd!("/home/batmanosama/viable-systems/vsm-mcp")

# First, let's get the dependencies
IO.puts "\n📦 Installing dependencies..."
System.cmd("mix", ["deps.get"], into: IO.stream(:stdio, :line))

# Compile everything
IO.puts "\n🔧 Compiling VSM-MCP..."
System.cmd("mix", ["compile", "--force"], into: IO.stream(:stdio, :line))

# Now start the application
IO.puts "\n🚀 Starting VSM-MCP Application..."
{:ok, _} = Application.ensure_all_started(:vsm_mcp)

# Give it a moment to initialize
Process.sleep(2000)

# Define our downstream task
task = %{
  name: "Build AI-Powered Documentation Generator",
  description: "Generate comprehensive documentation from code using AI",
  required_capabilities: [
    "markdown_generation",
    "code_analysis", 
    "ai_summarization"
  ]
}

IO.puts "\n🎯 DOWNSTREAM TASK:"
IO.puts "   Name: #{task.name}"
IO.puts "   Required: #{inspect(task.required_capabilities)}"

# Check current state
IO.puts "\n📊 Current System State:"
current_capabilities = try do
  VsmMcp.Integration.CapabilityMatcher.get_all_capabilities()
rescue
  _ -> ["core", "base"]  # Fallback if not implemented
end
IO.puts "   Available: #{inspect(current_capabilities)}"

missing = task.required_capabilities -- current_capabilities
IO.puts "   Missing: #{inspect(missing)}"

if length(missing) > 0 do
  IO.puts "\n⚡ TRIGGERING AUTONOMOUS ACQUISITION..."
  
  # Method 1: Direct variety gap injection
  IO.puts "\n💉 Injecting variety gap..."
  gap_info = %{
    type: :capability_requirement,
    severity: :high,
    required_capabilities: missing,
    task_description: task.description,
    timestamp: DateTime.utc_now()
  }
  
  # Try to inject via VarietyDetector
  try do
    VsmMcp.Integration.VarietyDetector.inject_variety_gap(gap_info)
    IO.puts "   ✅ Gap injected to VarietyDetector"
  rescue
    e -> IO.puts "   ⚠️  VarietyDetector not available: #{inspect(e)}"
  end
  
  # Try DaemonMode directly
  try do
    VsmMcp.DaemonMode.inject_variety_gap(gap_info)
    IO.puts "   ✅ Gap injected to DaemonMode"
  rescue
    e -> IO.puts "   ⚠️  DaemonMode not available: #{inspect(e)}"
  end
  
  # Method 2: Direct integration attempt
  IO.puts "\n🔄 Attempting direct integration..."
  result = try do
    VsmMcp.Integration.integrate_capabilities(missing)
  rescue
    e -> 
      IO.puts "   ⚠️  Direct integration failed: #{inspect(e)}"
      {:error, e}
  end
  
  case result do
    {:ok, results} ->
      IO.puts "\n✅ INTEGRATION SUCCESS!"
      Enum.each(results, fn {cap, res} ->
        case res do
          {:ok, _} -> IO.puts "   ✅ #{cap} - Integrated"
          {:error, reason} -> IO.puts "   ❌ #{cap} - Failed: #{inspect(reason)}"
        end
      end)
      
    {:error, _} ->
      IO.puts "\n🔍 Let's check what's actually available..."
      
      # Try discovery directly
      IO.puts "\n📡 Running MCP Discovery..."
      discovered = try do
        VsmMcp.Core.MCPDiscovery.discover_servers(missing)
      rescue
        e -> 
          IO.puts "   Discovery error: #{inspect(e)}"
          {:error, e}
      end
      
      case discovered do
        {:ok, servers} ->
          IO.puts "   Found #{length(servers)} potential servers"
          Enum.each(servers, fn s ->
            IO.puts "   • #{s.name} - Score: #{s.score}"
          end)
        _ ->
          IO.puts "   Discovery not functioning"
      end
  end
  
  # Monitor for autonomous action
  IO.puts "\n⏳ Monitoring autonomous system for 10 seconds..."
  Enum.each(1..10, fn i ->
    Process.sleep(1000)
    
    # Check daemon status
    status = try do
      VsmMcp.DaemonMode.get_status()
    rescue
      _ -> %{state: :unknown}
    end
    
    IO.puts "   [#{i}s] Daemon state: #{status.state}"
    
    # Check if capabilities were acquired
    new_caps = try do
      VsmMcp.Integration.CapabilityMatcher.get_all_capabilities()
    rescue
      _ -> current_capabilities
    end
    
    newly_acquired = new_caps -- current_capabilities
    if length(newly_acquired) > 0 do
      IO.puts "   🎉 NEW CAPABILITIES ACQUIRED: #{inspect(newly_acquired)}"
    end
  end)
  
else
  IO.puts "\n✅ System already has all required capabilities!"
end

# Final assessment
IO.puts "\n📋 FINAL ASSESSMENT:"
final_capabilities = try do
  VsmMcp.Integration.CapabilityMatcher.get_all_capabilities()
rescue
  _ -> current_capabilities
end

acquired = final_capabilities -- current_capabilities
can_do_task = Enum.all?(task.required_capabilities, &(&1 in final_capabilities))

IO.puts "   Started with: #{length(current_capabilities)} capabilities"
IO.puts "   Ended with: #{length(final_capabilities)} capabilities"
IO.puts "   Acquired: #{inspect(acquired)}"
IO.puts "   Can complete task: #{can_do_task}"

if can_do_task do
  IO.puts """
  
  🏆 AUTONOMOUS PROOF COMPLETE!
  The system successfully acquired the capabilities needed
  for the downstream task WITHOUT HUMAN INTERVENTION!
  """
else
  IO.puts """
  
  📊 PARTIAL DEMONSTRATION
  The autonomous systems are in place but may need:
  - Real NPM registry access
  - Network connectivity
  - Additional configuration
  """
end

IO.puts "\n✨ Demonstration finished!"