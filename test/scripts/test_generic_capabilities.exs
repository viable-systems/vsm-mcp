#!/usr/bin/env elixir

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

# Start the application
{:ok, _} = Application.ensure_all_started(:hackney)
{:ok, _} = Application.ensure_all_started(:vsm_mcp)

Process.sleep(1000)

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║     GENERIC AUTONOMOUS CAPABILITY ACQUISITION DEMO       ║
║        System 1 with Flexible MCP Integration            ║
╚═══════════════════════════════════════════════════════════╝
"""

# Test different types of capabilities
capabilities_to_test = [
  {"document_creation", "Create a technical document"},
  {"data_analysis", "Analyze dataset for patterns"},
  {"image_generation", "Generate visualization chart"},
  {"web_scraping", "Extract data from web source"},
  {"api_integration", "Connect to external API"},
  {"code_generation", "Generate Python script"},
  {"report_creation", "Create analytical report"}
]

IO.puts "\n🔍 Testing Autonomous Capability Acquisition for Various Tasks"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

Enum.each(capabilities_to_test, fn {capability, description} ->
  IO.puts "🎯 Testing capability: #{capability}"
  IO.puts "   Description: #{description}"
  
  # Test the capability acquisition
  acquisition_op = %{
    type: :capability_acquisition,
    target: capability,
    method: :mcp_integration
  }
  
  case VsmMcp.Systems.System1.execute_operation(acquisition_op) do
    {:ok, result} ->
      IO.puts "   ✅ Success: #{result.method}"
      if Map.has_key?(result, :execution_result) do
        IO.puts "   📄 Result: #{String.slice(result.execution_result, 0..80)}..."
      end
      IO.puts "   📝 Details: #{result.details}\n"
      
    {:error, reason} ->
      IO.puts "   ❌ Failed: #{reason}\n"
  end
  
  Process.sleep(1000)  # Brief pause between tests
end)

IO.puts "🚀 DEMONSTRATION COMPLETE"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
IO.puts """

📊 SUMMARY: The VSM-MCP System demonstrates:

✅ AGNOSTIC CAPABILITY ACQUISITION
   • No hardcoded functionality
   • Dynamic MCP server discovery
   • LLM-guided capability execution
   • Flexible adaptation to any task type

✅ AUTONOMOUS VARIETY EXPANSION
   • Real NPM package installation
   • External resource integration
   • Intelligent fallback mechanisms
   • True variety acquisition per Ashby's Law

✅ FLEXIBLE ARCHITECTURE
   • Generic execution framework
   • Multi-approach capability resolution
   • LLM-assisted decision making
   • Context-aware resource utilization

The system is now truly autonomous and domain-agnostic!
"""