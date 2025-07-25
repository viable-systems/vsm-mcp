#!/usr/bin/env elixir

# VSM-MCP Demo Runner
# Consolidated entry point for all demo scenarios
# 
# Usage:
#   elixir examples/demo_runner.exs [scenario]
#
# Available scenarios:
#   basic       - Basic VSM demonstration
#   consciousness - Consciousness interface demo
#   full        - Full autonomous system demo
#   resilience  - Resilience and error handling demo
#   llm         - LLM integration demo
#   mcp         - MCP server discovery demo
#   api         - API vs Direct comparison
#   all         - Run all demos in sequence

defmodule DemoRunner do
  @demos %{
    "basic" => "basic_vsm_demo.exs",
    "consciousness" => "consciousness_demo.exs", 
    "full" => "full_autonomous_demo.exs",
    "resilience" => "resilience_demo.exs",
    "llm" => "real_llm_demo.exs",
    "mcp" => "mcp_demo.exs",
    "api" => "api_vs_direct_comparison.exs",
    "autonomous" => "autonomous_prompt.exs",
    "variety" => "demo_variety_gaps.exs"
  }

  def run(scenario \\ "help") do
    case scenario do
      "all" ->
        IO.puts("\n🚀 Running all demos...\n")
        @demos
        |> Enum.each(fn {name, file} ->
          IO.puts("\n" <> String.duplicate("=", 60))
          IO.puts("Running #{name} demo...")
          IO.puts(String.duplicate("=", 60) <> "\n")
          run_demo(file)
          Process.sleep(2000)
        end)

      "help" ->
        show_help()

      scenario when is_map_key(@demos, scenario) ->
        IO.puts("\n🎯 Running #{scenario} demo...\n")
        run_demo(@demos[scenario])

      _ ->
        IO.puts("\n❌ Unknown scenario: #{scenario}")
        show_help()
    end
  end

  defp run_demo(file) do
    script_path = Path.join([__DIR__, file])
    
    if File.exists?(script_path) do
      Code.eval_file(script_path)
    else
      IO.puts("⚠️  Demo file not found: #{file}")
    end
  rescue
    e ->
      IO.puts("❌ Error running demo: #{inspect(e)}")
  end

  defp show_help do
    IO.puts("""
    
    VSM-MCP Demo Runner
    ===================
    
    Usage: elixir examples/demo_runner.exs [scenario]
    
    Available scenarios:
      basic         - Basic VSM demonstration
      consciousness - Consciousness interface demo
      full          - Full autonomous system demo  
      resilience    - Resilience and error handling demo
      llm           - LLM integration demo
      mcp           - MCP server discovery demo
      api           - API vs Direct comparison
      autonomous    - Autonomous prompt handling
      variety       - Variety gap analysis
      all           - Run all demos in sequence
      help          - Show this help message
    
    Examples:
      elixir examples/demo_runner.exs basic
      elixir examples/demo_runner.exs all
    """)
  end
end

# Run with command line argument
scenario = System.argv() |> List.first() || "help"
DemoRunner.run(scenario)