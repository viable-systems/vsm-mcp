#!/usr/bin/env elixir

# Full VSM-MCP System Demo - Using the Proper API
# This demonstrates using the actual VSM system instead of standalone functions

# Ensure all dependencies are available
Mix.install([
  {:vsm_mcp, path: "."},
  {:jason, "~> 1.4"},
  {:httpoison, "~> 2.0"}
])

# Load environment
if File.exists?(".env") do
  File.read!(".env")
  |> String.split("\n")
  |> Enum.each(fn line ->
    case String.split(line, "=", parts: 2) do
      [key, value] when key != "" ->
        unless String.starts_with?(key, "#") do
          System.put_env(key, String.trim(value))
        end
      _ -> :ok
    end
  end)
end

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║          FULL VSM-MCP SYSTEM API DEMONSTRATION            ║
║         Using Proper VSM Architecture & Endpoints         ║
╚═══════════════════════════════════════════════════════════╝
"""

# Start the VSM-MCP application
IO.puts "\n🚀 Starting VSM-MCP Application..."
{:ok, _} = Application.ensure_all_started(:hackney)
{:ok, _} = Application.ensure_all_started(:vsm_mcp)
IO.puts "✅ VSM-MCP Application started successfully!\n"

# Wait for systems to initialize
Process.sleep(1000)

# 1. Check System Status
IO.puts "📊 STEP 1: CHECKING SYSTEM STATUS"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
status = VsmMcp.system_status()
IO.puts "System 1 (Operations): #{status.system1.active && "✅ Active" || "❌ Inactive"}"
IO.puts "System 2 (Coordination): #{status.system2.active && "✅ Active" || "❌ Inactive"}"
IO.puts "System 3 (Control): #{status.system3.active && "✅ Active" || "❌ Inactive"}"
IO.puts "System 4 (Intelligence): #{status.system4.active && "✅ Active" || "❌ Inactive"}"
IO.puts "System 5 (Policy): #{status.system5.active && "✅ Active" || "❌ Inactive"}"

# 2. Analyze Variety
IO.puts "\n📈 STEP 2: VARIETY ANALYSIS"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━"
case VsmMcp.analyze_variety_gaps() do
  {:ok, analysis} ->
    IO.puts "Operational Variety: #{analysis.analysis.operational_variety}"
    IO.puts "Environmental Variety: #{analysis.analysis.environmental_variety}"
    IO.puts "Variety Gap: #{analysis.analysis.variety_gap}"
    IO.puts "Status: #{analysis.analysis.status}"
    
  {:error, reason} ->
    IO.puts "Error analyzing variety: #{inspect(reason)}"
end

# 3. Query Consciousness
IO.puts "\n🧠 STEP 3: CONSCIOUSNESS QUERY"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
consciousness_response = VsmMcp.consciousness_query(
  "What capabilities do we need to create a PowerPoint?",
  %{context: "user_request"}
)
IO.puts "Consciousness says: #{inspect(consciousness_response)}"

# 4. Make Strategic Decision
IO.puts "\n🎯 STEP 4: STRATEGIC DECISION"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
decision_request = %{
  objective: "acquire_capability",
  capability: "powerpoint_creation",
  constraints: ["use_mcp", "npm_packages_only"]
}

case VsmMcp.make_decision(decision_request) do
  {:ok, decision} ->
    IO.puts "Decision made: #{inspect(decision)}"
  {:error, reason} ->
    IO.puts "Decision error: #{inspect(reason)}"
end

# 5. Search for Capabilities
IO.puts "\n🔍 STEP 5: CAPABILITY SEARCH"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
gap = %{
  capability_type: "document_generation",
  requirements: ["powerpoint", "presentation", "slides"]
}

servers = VsmMcp.search_capabilities(gap)
IO.puts "Found #{length(servers)} potential MCP servers"
Enum.take(servers, 3) |> Enum.each(fn server ->
  IO.puts "  📦 #{server.name} - #{server.description}"
end)

# 6. Execute Operation through System 1
IO.puts "\n⚙️  STEP 6: OPERATIONAL EXECUTION"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
operation = %{
  type: :capability_acquisition,
  target: "powerpoint_creation",
  method: :mcp_integration
}

{:ok, result} = VsmMcp.Systems.System1.execute_operation(operation)
IO.puts "Operation executed: #{inspect(result)}"

# 7. Coordinate Through System 2
IO.puts "\n🔄 STEP 7: COORDINATION"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━"
VsmMcp.Systems.System2.coordinate_units([:discovery, :integration, :validation])
coordination_status = VsmMcp.Systems.System2.get_status()
IO.puts "Coordination active: #{coordination_status.active}"
IO.puts "Units coordinated: #{coordination_status.coordination_count}"

# 8. System 3 Audit
IO.puts "\n✅ STEP 8: CONTROL & AUDIT"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━"
VsmMcp.Systems.System3.audit_all()
audit_status = VsmMcp.Systems.System3.get_status()
IO.puts "Audits performed: #{audit_status.audits_performed}"
IO.puts "Control effectiveness: #{audit_status.control_effectiveness}%"

# 9. Environmental Scan
IO.puts "\n🌍 STEP 9: ENVIRONMENTAL INTELLIGENCE"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
VsmMcp.Systems.System4.scan_environment()
env_status = VsmMcp.Systems.System4.get_status()
IO.puts "Opportunities identified: #{length(env_status.opportunities)}"
IO.puts "Threats detected: #{length(env_status.threats)}"

# 10. Policy Decision
IO.puts "\n📋 STEP 10: POLICY & IDENTITY"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
policy_status = VsmMcp.Systems.System5.get_status()
IO.puts "Current purpose: #{policy_status.purpose}"
IO.puts "Decisions made: #{policy_status.decisions_made}"

# 11. Meta-Cognitive Reflection
IO.puts "\n🔮 STEP 11: META-COGNITIVE REFLECTION"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
reflection = VsmMcp.reflect()
IO.puts "Reflection: #{inspect(reflection)}"

# 12. Final System Status
IO.puts "\n📊 FINAL SYSTEM STATUS"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━"
final_status = VsmMcp.system_status()
IO.puts "All systems operational: #{
  final_status.system1.active && 
  final_status.system2.active && 
  final_status.system3.active && 
  final_status.system4.active && 
  final_status.system5.active
}"

# Optional: Start MCP Server
IO.puts "\n🌐 OPTIONAL: MCP SERVER"
IO.puts "━━━━━━━━━━━━━━━━━━━━━"
IO.puts "To expose VSM as MCP server, you would run:"
IO.puts "  {:ok, server} = VsmMcp.MCP.Server.start_link(port: 8080)"
IO.puts "  Available tools: vsm_status, variety_analysis, capability_search, etc."

IO.puts "\n✨ Demo complete! The VSM-MCP system is fully operational."
IO.puts "This demonstrates using the proper VSM architecture and API."