#!/usr/bin/env elixir

# Simple test of autonomous MCP acquisition
# This connects directly to the running VSM-MCP system

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║        TESTING VSM-MCP AUTONOMOUS CAPABILITIES             ║
╚═══════════════════════════════════════════════════════════╝
"""

# Change to project directory
File.cd!("/home/batmanosama/viable-systems/vsm-mcp")

# Start application
IO.puts "Starting VSM-MCP application..."
case Application.ensure_all_started(:vsm_mcp) do
  {:ok, apps} ->
    IO.puts "✅ Started #{length(apps)} applications"
  {:error, {app, reason}} ->
    IO.puts "❌ Failed to start #{app}: #{inspect(reason)}"
    System.halt(1)
end

# Wait for services to initialize
Process.sleep(2000)

# Check what's running
IO.puts "\n📊 SYSTEM STATUS:"
IO.puts "DaemonMode: #{inspect(Process.whereis(VsmMcp.DaemonMode))}"
IO.puts "VarietyDetector: #{inspect(Process.whereis(VsmMcp.Integration.VarietyDetector))}"
IO.puts "CapabilityMatcher: #{inspect(Process.whereis(VsmMcp.Integration.CapabilityMatcher))}"

# Get current capabilities
IO.puts "\n📋 CURRENT CAPABILITIES:"
try do
  caps = VsmMcp.Integration.CapabilityMatcher.get_all_capabilities()
  IO.puts "   #{inspect(caps)}"
rescue
  e -> IO.puts "   Error: #{inspect(e)}"
end

# Inject a variety gap
IO.puts "\n🚀 INJECTING VARIETY GAP..."
gap = %{
  type: :capability_gap,
  severity: :critical,
  required_capabilities: ["database", "filesystem"],
  source: "test_script",
  timestamp: DateTime.utc_now()
}

try do
  :ok = VsmMcp.Integration.VarietyDetector.inject_variety_gap(gap)
  IO.puts "✅ Gap injected successfully"
rescue
  e -> IO.puts "❌ Error injecting gap: #{inspect(e)}"
end

# Trigger daemon check
IO.puts "\n⚡ TRIGGERING DAEMON CHECK..."
case Process.whereis(VsmMcp.DaemonMode) do
  nil -> 
    IO.puts "❌ DaemonMode not running"
  pid ->
    send(pid, :check_variety)
    IO.puts "✅ Daemon check triggered"
end

# Monitor for 20 seconds
IO.puts "\n📊 MONITORING FOR AUTONOMOUS ACTION (20 seconds)..."
Enum.each(1..4, fn i ->
  Process.sleep(5000)
  
  # Check daemon status
  try do
    status = VsmMcp.DaemonMode.get_status()
    IO.puts "\n#{i*5}s - Daemon state: #{status.state}"
    IO.puts "   Monitoring: #{status.monitoring_active}"
    IO.puts "   Actions: #{length(status.autonomous_actions || [])}"
  rescue
    _ -> IO.puts "#{i*5}s - Unable to get daemon status"
  end
  
  # Check capabilities
  try do
    caps = VsmMcp.Integration.CapabilityMatcher.get_all_capabilities()
    new_caps = caps -- ["core", "base", "vsm_integration"]
    if length(new_caps) > 0 do
      IO.puts "   🎉 NEW CAPABILITIES: #{inspect(new_caps)}"
    end
  rescue
    _ -> :ok
  end
end)

IO.puts "\n✅ TEST COMPLETE"