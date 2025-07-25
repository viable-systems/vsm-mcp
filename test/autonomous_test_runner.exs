#!/usr/bin/env elixir

defmodule AutonomousTestRunner do
  @moduledoc """
  Comprehensive test runner for autonomous VSM-MCP capabilities.
  Orchestrates all autonomous tests and provides detailed reporting.
  """
  
  require Logger
  
  @test_suites [
    %{
      name: "Autonomous Capability Validation",
      module: AutonomousCapabilityValidationTest,
      file: "test/autonomous_capability_validation_test.exs",
      priority: :critical,
      estimated_duration: 120_000  # 2 minutes
    },
    %{
      name: "Performance Benchmarks",
      module: AutonomousPerformanceBenchmarkTest,
      file: "test/autonomous_performance_benchmark_test.exs",
      priority: :high,
      estimated_duration: 180_000  # 3 minutes
    },
    %{
      name: "API and WebSocket Integration",
      module: AutonomousApiWebsocketTest,
      file: "test/autonomous_api_websocket_test.exs",
      priority: :high,
      estimated_duration: 90_000   # 1.5 minutes
    },
    %{
      name: "Scenario Integration Testing",
      module: AutonomousScenarioIntegrationTest,
      file: "test/autonomous_scenario_integration_test.exs",
      priority: :medium,
      estimated_duration: 300_000  # 5 minutes
    },
    %{
      name: "Existing Integration Tests",
      module: AutonomousIntegrationExecutionTest,
      file: "test/autonomous_integration_execution_test.exs",
      priority: :medium,
      estimated_duration: 90_000
    },
    %{
      name: "Real MCP Integration",
      module: RealMCPIntegrationTest,
      file: "test/real_mcp_integration_test.exs",
      priority: :low,
      estimated_duration: 120_000
    },
    %{
      name: "Comprehensive MCP Integration",
      module: MCPIntegrationComprehensiveTest,
      file: "test/mcp_integration_comprehensive_test.exs",
      priority: :medium,
      estimated_duration: 60_000
    }
  ]
  
  def main(args \\ []) do
    Logger.configure(level: :info)
    
    options = parse_args(args)
    
    IO.puts("=== VSM-MCP Autonomous Capability Test Suite ===")
    IO.puts("Testing autonomous discovery, integration, and validation capabilities")
    IO.puts("")
    
    # Initialize test environment
    setup_test_environment()
    
    # Run tests based on options
    results = case options do
      %{suite: suite_name} ->
        run_specific_suite(suite_name)
      %{priority: priority} ->
        run_priority_suites(priority)
      %{quick: true} ->
        run_quick_tests()
      %{comprehensive: true} ->
        run_comprehensive_tests()
      _ ->
        run_default_tests()
    end
    
    # Generate comprehensive report
    generate_test_report(results)
    
    # Cleanup test environment
    cleanup_test_environment()
    
    # Exit with appropriate code
    exit_code = if Enum.all?(results, &(&1.status == :passed)), do: 0, else: 1
    System.halt(exit_code)
  end
  
  defp parse_args(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        suite: :string,
        priority: :string,
        quick: :boolean,
        comprehensive: :boolean,
        parallel: :boolean,
        verbose: :boolean,
        output: :string,
        timeout: :integer
      ],
      aliases: [
        s: :suite,
        p: :priority,
        q: :quick,
        c: :comprehensive,
        v: :verbose,
        o: :output,
        t: :timeout
      ]
    )
    
    Enum.into(options, %{})
  end
  
  defp setup_test_environment do
    IO.puts("🔧 Setting up autonomous test environment...")
    
    # Ensure all required applications are started
    required_apps = [:vsm_mcp, :httpoison, :jason, :meck, :websocket_client]
    
    for app <- required_apps do
      case Application.ensure_all_started(app) do
        {:ok, _} -> :ok
        {:error, {app, reason}} -> 
          IO.puts("⚠️  Warning: Failed to start #{app}: #{inspect(reason)}")
      end
    end
    
    # Set test environment variables
    System.put_env("MIX_ENV", "test")
    System.put_env("AUTONOMOUS_TEST_MODE", "true")
    
    # Create test directories
    test_dirs = [
      "tmp/autonomous_test",
      "tmp/test_installations",
      "tmp/test_artifacts"
    ]
    
    for dir <- test_dirs do
      File.mkdir_p!(dir)
    end
    
    IO.puts("✅ Test environment ready")
  end
  
  defp cleanup_test_environment do
    IO.puts("🧹 Cleaning up test environment...")
    
    # Remove test directories
    test_dirs = [
      "tmp/autonomous_test",
      "tmp/test_installations", 
      "tmp/test_artifacts"
    ]
    
    for dir <- test_dirs do
      if File.exists?(dir) do
        File.rm_rf!(dir)
      end
    end
    
    # Clean up any test processes
    cleanup_test_processes()
    
    IO.puts("✅ Cleanup complete")
  end
  
  defp cleanup_test_processes do
    # Find and terminate any test-related processes
    test_process_patterns = [
      ~r/test.*integration/,
      ~r/autonomous.*test/,
      ~r/test.*server/
    ]
    
    for process <- Process.list() do
      try do
        case Process.info(process, :registered_name) do
          {:registered_name, name} when is_atom(name) ->
            name_str = Atom.to_string(name)
            if Enum.any?(test_process_patterns, &Regex.match?(&1, name_str)) do
              Process.exit(process, :normal)
            end
          _ ->
            :ok
        end
      catch
        _ -> :ok
      end
    end
  end
  
  defp run_specific_suite(suite_name) do
    IO.puts("🎯 Running specific test suite: #{suite_name}")
    
    suite = Enum.find(@test_suites, &(&1.name == suite_name))
    
    if suite do
      [run_test_suite(suite)]
    else
      IO.puts("❌ Test suite '#{suite_name}' not found")
      available_suites = Enum.map(@test_suites, & &1.name)
      IO.puts("Available suites: #{Enum.join(available_suites, ", ")}")
      []
    end
  end
  
  defp run_priority_suites(priority) do
    priority_atom = String.to_atom(priority)
    IO.puts("🔥 Running #{priority} priority test suites")
    
    @test_suites
    |> Enum.filter(&(&1.priority == priority_atom))
    |> Enum.map(&run_test_suite/1)
  end
  
  defp run_quick_tests do
    IO.puts("⚡ Running quick autonomous capability tests")
    
    # Run only critical and high priority tests with shorter timeouts
    @test_suites
    |> Enum.filter(&(&1.priority in [:critical, :high]))
    |> Enum.take(3)  # Limit to first 3 for speed
    |> Enum.map(&run_test_suite(&1, timeout: 30_000))  # 30 second timeout
  end
  
  defp run_comprehensive_tests do
    IO.puts("🔍 Running comprehensive autonomous capability test suite")
    
    # Run all tests with extended timeouts
    @test_suites
    |> Enum.map(&run_test_suite(&1, timeout: &1.estimated_duration * 2))
  end
  
  defp run_default_tests do
    IO.puts("🚀 Running default autonomous capability tests")
    
    # Run critical and high priority tests
    @test_suites
    |> Enum.filter(&(&1.priority in [:critical, :high]))
    |> Enum.map(&run_test_suite/1)
  end
  
  defp run_test_suite(suite, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, suite.estimated_duration)
    
    IO.puts("")
    IO.puts("=" <> String.duplicate("=", String.length(suite.name) + 20))
    IO.puts("🧪 Running: #{suite.name}")
    IO.puts("📁 File: #{suite.file}")
    IO.puts("⏱️  Estimated duration: #{suite.estimated_duration / 1000}s")
    IO.puts("🔥 Priority: #{suite.priority}")
    IO.puts("=" <> String.duplicate("=", String.length(suite.name) + 20))
    
    start_time = System.monotonic_time(:millisecond)
    
    result = try do
      # Check if test file exists
      if File.exists?(suite.file) do
        # Run the test using ExUnit
        run_exunit_test(suite.file, timeout)
      else
        IO.puts("⚠️  Test file not found: #{suite.file}")
        %{status: :skipped, reason: "File not found", duration: 0}
      end
    catch
      kind, error ->
        IO.puts("❌ Test suite crashed: #{inspect(error)}")
        %{status: :error, reason: {kind, error}, duration: 0}
    end
    
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    result_with_metadata = Map.merge(result, %{
      suite: suite.name,
      file: suite.file,
      priority: suite.priority,
      duration: duration,
      estimated_duration: suite.estimated_duration
    })
    
    print_suite_result(result_with_metadata)
    
    result_with_metadata
  end
  
  defp run_exunit_test(test_file, timeout) do
    # Use System.cmd to run the test file
    case System.cmd("mix", ["test", test_file, "--timeout", to_string(timeout)], 
                    stderr_to_stdout: true, timeout: timeout + 10_000) do
      {output, 0} ->
        # Parse ExUnit output for results
        parse_exunit_output(output)
        
      {output, exit_code} ->
        IO.puts("Test failed with exit code #{exit_code}")
        IO.puts(output)
        %{
          status: :failed,
          reason: "Exit code #{exit_code}",
          output: output,
          tests_run: 0,
          failures: 1
        }
    end
  end
  
  defp parse_exunit_output(output) do
    # Basic parsing of ExUnit output
    lines = String.split(output, "\n")
    
    # Look for summary line like "5 tests, 0 failures"
    summary_line = Enum.find(lines, &String.contains?(&1, "test"))
    
    if summary_line do
      # Extract test counts
      tests_run = extract_number(summary_line, ~r/(\d+) tests?/)
      failures = extract_number(summary_line, ~r/(\d+) failures?/)
      
      status = if failures == 0, do: :passed, else: :failed
      
      %{
        status: status,
        tests_run: tests_run,
        failures: failures,
        output: output
      }
    else
      %{
        status: :unknown,
        reason: "Could not parse output",
        output: output,
        tests_run: 0,
        failures: 0
      }
    end
  end
  
  defp extract_number(string, regex) do
    case Regex.run(regex, string) do
      [_, number] -> String.to_integer(number)
      _ -> 0
    end
  end
  
  defp print_suite_result(result) do
    status_emoji = case result.status do
      :passed -> "✅"
      :failed -> "❌"
      :error -> "💥"
      :skipped -> "⏭️"
      _ -> "❓"
    end
    
    duration_str = "#{result.duration}ms"
    if result.estimated_duration > 0 do
      percentage = (result.duration / result.estimated_duration * 100) |> round()
      duration_str = "#{duration_str} (#{percentage}% of estimated)"
    end
    
    IO.puts("")
    IO.puts("#{status_emoji} #{result.suite}")
    IO.puts("   Duration: #{duration_str}")
    IO.puts("   Priority: #{result.priority}")
    
    case result.status do
      :passed ->
        IO.puts("   Tests: #{result.tests_run} run, #{result.failures} failures")
      :failed ->
        IO.puts("   Tests: #{result.tests_run} run, #{result.failures} failures")
        IO.puts("   Reason: #{result.reason}")
      :error ->
        IO.puts("   Error: #{inspect(result.reason)}")
      :skipped ->
        IO.puts("   Reason: #{result.reason}")
    end
    
    IO.puts("")
  end
  
  defp generate_test_report(results) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("📊 AUTONOMOUS CAPABILITY TEST REPORT")
    IO.puts(String.duplicate("=", 80))
    
    # Summary statistics
    total_suites = length(results)
    passed_suites = Enum.count(results, &(&1.status == :passed))
    failed_suites = Enum.count(results, &(&1.status == :failed))
    error_suites = Enum.count(results, &(&1.status == :error))
    skipped_suites = Enum.count(results, &(&1.status == :skipped))
    
    total_tests = Enum.sum(Enum.map(results, &Map.get(&1, :tests_run, 0)))
    total_failures = Enum.sum(Enum.map(results, &Map.get(&1, :failures, 0)))
    total_duration = Enum.sum(Enum.map(results, & &1.duration))
    
    IO.puts("")
    IO.puts("📈 SUMMARY:")
    IO.puts("   Total Test Suites: #{total_suites}")
    IO.puts("   ✅ Passed: #{passed_suites}")
    IO.puts("   ❌ Failed: #{failed_suites}")
    IO.puts("   💥 Errors: #{error_suites}")
    IO.puts("   ⏭️  Skipped: #{skipped_suites}")
    IO.puts("")
    IO.puts("   Total Tests: #{total_tests}")
    IO.puts("   Total Failures: #{total_failures}")
    IO.puts("   Success Rate: #{success_rate(total_tests, total_failures)}%")
    IO.puts("   Total Duration: #{duration_string(total_duration)}")
    
    # Priority breakdown
    IO.puts("")
    IO.puts("🔥 PRIORITY BREAKDOWN:")
    
    for priority <- [:critical, :high, :medium, :low] do
      priority_results = Enum.filter(results, &(&1.priority == priority))
      if length(priority_results) > 0 do
        priority_passed = Enum.count(priority_results, &(&1.status == :passed))
        priority_total = length(priority_results)
        IO.puts("   #{priority |> Atom.to_string() |> String.capitalize()}: #{priority_passed}/#{priority_total} passed")
      end
    end
    
    # Performance analysis
    IO.puts("")
    IO.puts("⚡ PERFORMANCE ANALYSIS:")
    
    for result <- results do
      if result.estimated_duration > 0 do
        performance_ratio = result.duration / result.estimated_duration
        performance_indicator = cond do
          performance_ratio <= 0.8 -> "🚀 Fast"
          performance_ratio <= 1.2 -> "✅ Normal"
          performance_ratio <= 1.5 -> "⚠️  Slow"
          true -> "🐌 Very Slow"
        end
        
        IO.puts("   #{result.suite}: #{performance_indicator} (#{round(performance_ratio * 100)}%)")
      end
    end
    
    # Failed tests details
    failed_results = Enum.filter(results, &(&1.status in [:failed, :error]))
    if length(failed_results) > 0 do
      IO.puts("")
      IO.puts("❌ FAILED TESTS:")
      
      for result <- failed_results do
        IO.puts("   #{result.suite}:")
        IO.puts("     Status: #{result.status}")
        IO.puts("     Reason: #{Map.get(result, :reason, "Unknown")}")
        if Map.has_key?(result, :failures) and result.failures > 0 do
          IO.puts("     Failures: #{result.failures}/#{result.tests_run}")
        end
      end
    end
    
    # Recommendations
    IO.puts("")
    IO.puts("💡 RECOMMENDATIONS:")
    
    if failed_suites > 0 do
      IO.puts("   • Review and fix #{failed_suites} failed test suite(s)")
    end
    
    if error_suites > 0 do
      IO.puts("   • Investigate #{error_suites} test suite error(s)")
    end
    
    slow_tests = Enum.filter(results, fn result ->
      result.estimated_duration > 0 and result.duration > result.estimated_duration * 1.5
    end)
    
    if length(slow_tests) > 0 do
      IO.puts("   • Optimize #{length(slow_tests)} slow-running test suite(s)")
    end
    
    if total_failures > 0 do
      failure_rate = total_failures / total_tests * 100
      if failure_rate > 10 do
        IO.puts("   • High failure rate (#{round(failure_rate)}%) - review test stability")
      end
    end
    
    # Overall assessment
    IO.puts("")
    IO.puts("🎯 OVERALL ASSESSMENT:")
    
    overall_score = calculate_overall_score(results)
    assessment = case overall_score do
      score when score >= 90 -> "🌟 Excellent - Autonomous capabilities are working great!"
      score when score >= 75 -> "✅ Good - Most autonomous capabilities are functional"
      score when score >= 60 -> "⚠️  Acceptable - Some autonomous capabilities need attention"
      score when score >= 40 -> "❌ Poor - Significant autonomous capability issues"
      _ -> "💥 Critical - Major autonomous capability failures"
    end
    
    IO.puts("   Score: #{overall_score}/100")
    IO.puts("   Assessment: #{assessment}")
    
    IO.puts("")
    IO.puts(String.duplicate("=", 80))
    
    # Save report to file
    save_test_report(results, overall_score)
  end
  
  defp success_rate(total_tests, total_failures) when total_tests > 0 do
    ((total_tests - total_failures) / total_tests * 100) |> round()
  end
  
  defp success_rate(_, _), do: 0
  
  defp duration_string(duration_ms) do
    cond do
      duration_ms < 1000 -> "#{duration_ms}ms"
      duration_ms < 60_000 -> "#{Float.round(duration_ms / 1000, 1)}s"
      true -> "#{Float.round(duration_ms / 60_000, 1)}m"
    end
  end
  
  defp calculate_overall_score(results) do
    if length(results) == 0, do: 0
    
    # Weight by priority
    priority_weights = %{critical: 4, high: 3, medium: 2, low: 1}
    
    total_weight = Enum.sum(Enum.map(results, &priority_weights[&1.priority]))
    
    weighted_score = Enum.sum(Enum.map(results, fn result ->
      base_score = case result.status do
        :passed -> 100
        :failed -> if Map.get(result, :failures, 1) == 0, do: 50, else: 20
        :error -> 10
        :skipped -> 30
        _ -> 0
      end
      
      base_score * priority_weights[result.priority]
    end))
    
    if total_weight > 0, do: round(weighted_score / total_weight), else: 0
  end
  
  defp save_test_report(results, overall_score) do
    report_data = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      overall_score: overall_score,
      summary: %{
        total_suites: length(results),
        passed: Enum.count(results, &(&1.status == :passed)),
        failed: Enum.count(results, &(&1.status == :failed)),
        errors: Enum.count(results, &(&1.status == :error)),
        skipped: Enum.count(results, &(&1.status == :skipped))
      },
      results: results
    }
    
    report_file = "tmp/autonomous_test_report_#{DateTime.utc_now() |> DateTime.to_unix()}.json"
    File.write!(report_file, Jason.encode!(report_data, pretty: true))
    
    IO.puts("📄 Detailed report saved to: #{report_file}")
  end
end

# Run if called directly
if System.argv() != [] or __ENV__.file == Path.absname("test/autonomous_test_runner.exs") do
  AutonomousTestRunner.main(System.argv())
end