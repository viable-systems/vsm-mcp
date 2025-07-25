#!/usr/bin/env elixir

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║        PROOF OF REAL MCP SERVER INSTALLATION               ║
╚═══════════════════════════════════════════════════════════╝

This will demonstrate ACTUAL MCP server discovery and installation.
No mocks, no simulations - real NPM packages!
"""

# Start the application
{:ok, _} = Application.ensure_all_started(:vsm_mcp)
Process.sleep(2000)

IO.puts "\n📊 INITIAL STATE:"
IO.puts "Capabilities: #{inspect(VsmMcp.Integration.CapabilityMatcher.get_all_capabilities())}"

# Test 1: Direct capability mapping
IO.puts "\n🧪 TEST 1: Capability Mapping"
mappings = VsmMcp.Core.CapabilityMapping.get_mcp_packages("filesystem")
IO.puts "Filesystem maps to: #{inspect(mappings)}"

# Test 2: Direct NPM search
IO.puts "\n🧪 TEST 2: Direct NPM Search"
case VsmMcp.Core.MCPDiscovery.discover_servers(["filesystem"]) do
  {:ok, servers} ->
    IO.puts "Found #{length(servers)} servers:"
    Enum.each(servers, fn s ->
      IO.puts "  - #{s[:name]} (#{s[:package]})"
    end)
  error ->
    IO.puts "Search failed: #{inspect(error)}"
end

# Test 3: Inject variety gap with real capabilities
IO.puts "\n🧪 TEST 3: Triggering Autonomous Installation"

gap = %{
  type: :capability_gap,
  severity: :critical,
  required_capabilities: ["filesystem", "memory", "sqlite"],
  source: "proof_test",
  timestamp: DateTime.utc_now()
}

:ok = VsmMcp.Integration.VarietyDetector.inject_variety_gap(gap)
send(Process.whereis(VsmMcp.DaemonMode), :check_variety)

IO.puts "Gap injected, monitoring for 30 seconds..."

# Monitor progress
Enum.each(1..6, fn i ->
  Process.sleep(5000)
  
  IO.puts "\n#{i*5}s Status:"
  
  # Check capabilities
  caps = VsmMcp.Integration.CapabilityMatcher.get_all_capabilities()
  new_caps = caps -- ["core", "base", "vsm_integration"]
  IO.puts "  Capabilities: #{length(caps)} total"
  if length(new_caps) > 0 do
    IO.puts "  🎉 NEW: #{inspect(new_caps)}"
  end
  
  # Check running servers
  servers = VsmMcp.MCP.ExternalServerSpawner.list_running_servers()
  IO.puts "  MCP Servers: #{length(servers)} running"
  Enum.each(servers, fn s ->
    IO.puts "    - #{s.package} (PID: #{inspect(s.pid)})"
  end)
  
  # Check installed packages
  {output, _} = System.cmd("ls", ["-la", "/tmp/vsm_mcp_servers/"], stderr_to_stdout: true)
  if String.contains?(output, "node_modules") do
    IO.puts "  📦 Packages installed in /tmp/vsm_mcp_servers/"
  end
end)

# Final check - list actual installed files
IO.puts "\n📁 CHECKING FOR INSTALLED MCP SERVERS:"
{files, _} = System.cmd("find", ["/tmp", "-name", "*mcp-server*", "-o", "-name", "*modelcontextprotocol*"], 
                       stderr_to_stdout: true)

if files != "" do
  IO.puts "FOUND INSTALLED MCP PACKAGES:"
  files
  |> String.split("\n")
  |> Enum.filter(&(&1 != ""))
  |> Enum.each(&IO.puts("  ✅ #{&1}"))
else
  IO.puts "No MCP packages found yet"
end

IO.puts "\n✅ Test complete!"