#!/usr/bin/env elixir

# Demo: System 1 using LLM as External Variety Source
# This shows how System 1 handles operations beyond its internal variety

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
║     SYSTEM 1 WITH LLM AS EXTERNAL VARIETY SOURCE         ║
║        Demonstrating Real Autonomous Operations           ║
╚═══════════════════════════════════════════════════════════╝
"""

# Start the application
{:ok, _} = Application.ensure_all_started(:hackney)
{:ok, _} = Application.ensure_all_started(:vsm_mcp)

Process.sleep(1000)

IO.puts "\n🔍 SCENARIO: User requests PowerPoint creation"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

# Check current capabilities
IO.puts "📊 Current System 1 Status:"
status = VsmMcp.Systems.System1.get_status()
IO.puts "  • Active: #{status.active}"
IO.puts "  • Operations Count: #{status.metrics.operations_count}"
IO.puts "  • Success Rate: #{status.metrics.success_rate * 100}%"
IO.puts "  • Capabilities: #{inspect(status.capabilities)}\n"

# Try to execute a PowerPoint operation
IO.puts "🎯 Attempting PowerPoint creation operation..."
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

operation = %{
  type: :create_powerpoint,
  data: "VSM Architecture Overview",
  requirements: ["slides", "diagrams", "formatting"]
}

case VsmMcp.Systems.System1.execute_operation(operation) do
  {:ok, result} ->
    IO.puts "✅ Operation Result:"
    IO.puts "  • Status: Success"
    IO.puts "  • Source: #{Map.get(result, :source, :internal)}"
    IO.puts "  • Result: #{result.result}"
    IO.puts "  • Timestamp: #{result.timestamp}"
    
    if Map.get(result, :source) == :llm do
      IO.puts "\n🤖 LLM was used as external variety source!"
    end
    
  {:error, reason} ->
    IO.puts "❌ Operation failed: #{reason}"
end

# Show variety gap and acquisition
IO.puts "\n📈 VARIETY GAP ANALYSIS:"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━\n"

{:ok, variety} = VsmMcp.analyze_variety_gaps()
IO.puts "  • Operational Variety: #{variety.analysis.operational_variety}"
IO.puts "  • Environmental Variety: #{variety.analysis.environmental_variety}"
IO.puts "  • Variety Gap: #{variety.analysis.variety_gap}"
IO.puts "  • Status: #{variety.analysis.status}"

if length(variety.triggers) > 0 do
  IO.puts "\n🚨 Capability acquisition triggered!"
  
  # Acquire the capability
  acquisition_op = %{
    type: :capability_acquisition,
    target: "powerpoint_creation",
    method: :mcp_integration
  }
  
  IO.puts "\n🔧 Acquiring PowerPoint capability..."
  case VsmMcp.Systems.System1.execute_operation(acquisition_op) do
    {:ok, result} ->
      IO.puts "✅ Capability acquired!"
      IO.puts "  • Method: #{result.method}"
      IO.puts "  • Details: #{result.details}"
      
    {:error, reason} ->
      IO.puts "❌ Acquisition failed: #{reason}"
  end
end

# Try a complex transformation using LLM
IO.puts "\n🔄 COMPLEX TRANSFORMATION TEST:"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

transform_op = %{
  type: :transform,
  input: %{
    format: "markdown",
    content: "# VSM Overview\n- System 1: Operations\n- System 2: Coordination"
  },
  output: %{
    format: "html",
    style: "presentation"
  }
}

IO.puts "Transforming markdown to presentation HTML..."
case VsmMcp.Systems.System1.execute_operation(transform_op) do
  {:ok, result} ->
    IO.puts "✅ Transformation complete!"
    IO.puts "  • Source: #{Map.get(result, :source, :internal)}"
    IO.puts "  • Result preview: #{String.slice(result.result, 0..100)}..."
    
  {:error, reason} ->
    IO.puts "❌ Transformation failed: #{reason}"
end

# Show final status
IO.puts "\n📊 FINAL SYSTEM 1 STATUS:"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━\n"
final_status = VsmMcp.Systems.System1.get_status()
IO.puts "  • Operations Count: #{final_status.metrics.operations_count}"
IO.puts "  • Success Rate: #{final_status.metrics.success_rate * 100}%"
IO.puts "  • Average Duration: #{final_status.metrics.average_duration}ms"

# Show LLM integration status
IO.puts "\n🤖 LLM INTEGRATION STATUS:"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━\n"
llm_provider = cond do
  System.get_env("ANTHROPIC_API_KEY") -> "Anthropic Claude"
  System.get_env("OPENAI_API_KEY") -> "OpenAI GPT"
  true -> "Local/Mock"
end
IO.puts "  • Provider: #{llm_provider}"
IO.puts "  • Status: Active"
IO.puts "  • Purpose: External variety amplifier for System 1"

IO.puts "\n✨ Demo complete! System 1 is using LLM for operations beyond internal variety."