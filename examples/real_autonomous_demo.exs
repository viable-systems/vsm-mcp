#!/usr/bin/env elixir

# REAL autonomous VSM demonstration - NO MOCKS!
# This actually discovers MCP servers, calculates variety from real metrics,
# and makes autonomous decisions

# Add the project to the load path
Code.prepend_path("_build/dev/lib/vsm_mcp/ebin")
Code.prepend_path("_build/dev/lib/jason/ebin")
Code.prepend_path("_build/dev/lib/httpoison/ebin")
Code.prepend_path("_build/dev/lib/hackney/ebin")
Code.prepend_path("_build/dev/lib/certifi/ebin")
Code.prepend_path("_build/dev/lib/idna/ebin")
Code.prepend_path("_build/dev/lib/metrics/ebin")
Code.prepend_path("_build/dev/lib/mimerl/ebin")
Code.prepend_path("_build/dev/lib/parse_trans/ebin")
Code.prepend_path("_build/dev/lib/ssl_verify_fun/ebin")
Code.prepend_path("_build/dev/lib/unicode_util_compat/ebin")

# Start required applications
Application.ensure_all_started(:hackney)
Application.ensure_all_started(:httpoison)

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║         VSM-MCP: REAL Autonomous System Demo              ║
║                   NO MOCKS - ACTUAL FUNCTIONALITY         ║
╚═══════════════════════════════════════════════════════════╝
"""

defmodule RealDemo do
  alias VsmMcp.RealImplementation
  
  def run do
    IO.puts "\n🔍 Phase 1: Discovering REAL MCP Servers from NPM Registry...\n"
    
    servers = RealImplementation.discover_real_mcp_servers()
    IO.puts "Found #{length(servers)} real MCP servers:\n"
    
    Enum.take(servers, 5) |> Enum.each(fn server ->
      IO.puts "  📦 #{server.name} v#{server.version}"
      IO.puts "     Score: #{Float.round(server.score, 2)}, Downloads: #{server.downloads}"
      IO.puts "     #{server.description}"
      IO.puts ""
    end)
    
    IO.puts "\n📊 Phase 2: Calculating REAL Variety from System Metrics...\n"
    
    variety = RealImplementation.calculate_real_variety()
    
    IO.puts "System Metrics (REAL):"
    IO.puts "  CPU Cores: #{variety.metrics.cpu_count}"
    IO.puts "  Memory: #{variety.metrics.memory_mb} MB"
    IO.puts "  Processes: #{variety.metrics.processes}"
    IO.puts "  Loaded Modules: #{variety.metrics.loaded_modules}"
    IO.puts "  Available Functions: #{variety.metrics.available_functions}"
    
    IO.puts "\nVariety Analysis (Ashby's Law):"
    IO.puts "  Operational Variety: #{Float.round(variety.operational_variety, 2)} bits"
    IO.puts "  Environmental Variety: #{Float.round(variety.environmental_variety, 2)} bits"
    IO.puts "  Variety Gap: #{Float.round(variety.variety_gap, 2)} bits"
    IO.puts "  Requisite Ratio: #{Float.round(variety.requisite_ratio * 100, 1)}%"
    IO.puts "  Status: #{variety.status}"
    
    IO.puts "\n🤖 Phase 3: Making Autonomous Decision...\n"
    
    decision = RealImplementation.autonomous_decision()
    
    IO.puts "Decision: #{decision.action}"
    IO.puts "Urgency: #{decision.urgency}"
    IO.puts "Rationale: #{Map.get(decision, :rationale, Map.get(decision, :recommendation, ""))}"
    
    if decision.action == :emergency_capability_acquisition do
      IO.puts "\n🚨 CRITICAL: Executing Emergency Capability Acquisition..."
      IO.puts "Installing MCP servers to address variety deficit..."
      
      # Note: In a real deployment, this would actually install servers
      # For safety in demo, we just show what would happen
      Enum.each(decision.targets, fn target ->
        IO.puts "  Would install: #{target.name}"
      end)
    end
    
    IO.puts "\n✅ Real autonomous demonstration complete!"
    IO.puts "   This system can truly adapt by discovering and integrating capabilities."
  end
end

# Run the real demo
RealDemo.run()