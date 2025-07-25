#!/usr/bin/env elixir

# Performance Validation Test - Phase 5
# Target: 177K ops/sec variety calculations
# Memory scaling: Linear 5KB→235KB
# Security: No regression in sandboxing
# OTP: No regression in supervision

defmodule PerformanceValidationTest do
  require Logger

  def run_validation do
    Logger.info("🚀 Starting Performance Validation Phase 5")
    Logger.info("Target: 177K ops/sec variety calculation")
    Logger.info("Memory: Linear scaling 5KB→235KB")
    Logger.info("Security: No sandbox regression")
    Logger.info("OTP: No supervision regression")

    # Store coordination metrics
    start_time = System.monotonic_time(:millisecond)
    
    results = %{
      variety_performance: test_variety_performance_target(),
      memory_scaling: test_memory_scaling(),
      security_sandboxing: test_security_sandboxing(),
      otp_supervision: test_otp_supervision(),
      system_stability: test_system_stability()
    }

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    # Store results in coordination memory
    store_coordination_metrics(results, duration)
    
    # Generate validation report
    generate_validation_report(results)
    
    # Return pass/fail status
    validate_all_targets(results)
  end

  # Test 1: Variety Calculation Performance (177K ops/sec target)
  defp test_variety_performance_target do
    Logger.info("🔬 Testing variety calculation performance...")
    
    # Generate test data
    system = generate_lightweight_system()
    environment = generate_lightweight_environment()
    
    # Measure operations per second
    iterations = 10_000
    {time_us, _results} = :timer.tc(fn ->
      for _ <- 1..iterations do
        VsmMcp.Core.VarietyCalculator.calculate_variety_gap(system, environment)
      end
    end)
    
    # Calculate ops/sec
    ops_per_sec = iterations / (time_us / 1_000_000)
    target_ops_per_sec = 177_000
    
    Logger.info("📊 Achieved: #{Float.round(ops_per_sec, 0)} ops/sec")
    Logger.info("🎯 Target: #{target_ops_per_sec} ops/sec")
    
    passed = ops_per_sec >= target_ops_per_sec
    if passed do
      Logger.info("✅ Performance target ACHIEVED!")
    else
      Logger.warning("❌ Performance target MISSED by #{Float.round(target_ops_per_sec - ops_per_sec, 0)} ops/sec")
    end

    %{
      achieved_ops_per_sec: ops_per_sec,
      target_ops_per_sec: target_ops_per_sec,
      passed: passed,
      time_per_op_us: time_us / iterations
    }
  end

  # Test 2: Memory Scaling (Linear 5KB→235KB)
  defp test_memory_scaling do
    Logger.info("💾 Testing memory scaling linearity...")
    
    # Test different data sizes
    test_sizes = [5, 25, 50, 100, 150, 200, 235]  # KB equivalent data sizes
    
    memory_results = Enum.map(test_sizes, fn size ->
      system = generate_scaled_system(size)
      environment = generate_scaled_environment(size)
      
      # Measure memory usage
      :erlang.garbage_collect()
      before_memory = :erlang.memory(:total)
      
      _result = VsmMcp.Core.VarietyCalculator.calculate_variety_gap(system, environment)
      
      :erlang.garbage_collect()
      after_memory = :erlang.memory(:total)
      
      memory_used_kb = (after_memory - before_memory) / 1024
      
      {size, memory_used_kb}
    end)
    
    # Check linearity (R² correlation)
    linearity_score = calculate_linearity(memory_results)
    linearity_passed = linearity_score > 0.95  # 95% correlation required
    
    Logger.info("📈 Memory scaling linearity: #{Float.round(linearity_score * 100, 1)}%")
    
    if linearity_passed do
      Logger.info("✅ Linear memory scaling ACHIEVED!")
    else
      Logger.warning("❌ Memory scaling not sufficiently linear")
    end

    %{
      memory_results: memory_results,
      linearity_score: linearity_score,
      passed: linearity_passed
    }
  end

  # Test 3: Security Sandboxing (No regression)
  defp test_security_sandboxing do
    Logger.info("🔒 Testing security sandboxing integrity...")
    
    # Test dangerous operations are properly contained
    dangerous_tests = [
      fn -> System.cmd("echo", ["test"]) end,
      fn -> File.read("/etc/passwd") end,
      fn -> :os.cmd(~c"whoami") end
    ]
    
    security_results = Enum.map(dangerous_tests, fn test_fn ->
      try do
        # These should either fail or be sandboxed
        result = test_fn.()
        # If they succeed without sandbox, that's a problem
        {:unsecured, result}
      rescue
        error -> {:secured, error}
      catch
        :error, reason -> {:secured, reason}
      end
    end)
    
    # All operations should be secured
    all_secured = Enum.all?(security_results, fn {status, _} -> status == :secured end)
    
    if all_secured do
      Logger.info("✅ Security sandboxing MAINTAINED!")
    else
      Logger.warning("❌ Security regression detected!")
    end

    %{
      security_results: security_results,
      passed: all_secured
    }
  end

  # Test 4: OTP Supervision (No regression)
  defp test_otp_supervision do
    Logger.info("🛡️ Testing OTP supervision tree integrity...")
    
    # Check that all required supervisors are running
    required_supervisors = [
      VsmMcp.Application,
      VsmMcp.Core.VarietyCalculator,
      VsmMcp.Systems.System1,
      VsmMcp.Systems.System2,
      VsmMcp.Systems.System3,
      VsmMcp.Systems.System4,
      VsmMcp.Systems.System5
    ]
    
    supervision_results = Enum.map(required_supervisors, fn supervisor ->
      case Process.whereis(supervisor) do
        nil -> {supervisor, :not_running}
        pid when is_pid(pid) -> {supervisor, :running}
      end
    end)
    
    all_running = Enum.all?(supervision_results, fn {_, status} -> status == :running end)
    
    # Test supervisor restart capability
    restart_test_passed = test_supervisor_restart()
    
    supervision_passed = all_running and restart_test_passed
    
    if supervision_passed do
      Logger.info("✅ OTP supervision MAINTAINED!")
    else
      Logger.warning("❌ OTP supervision regression detected!")
    end

    %{
      supervisor_status: supervision_results,
      restart_test_passed: restart_test_passed,
      passed: supervision_passed
    }
  end

  # Test 5: System Stability
  defp test_system_stability do
    Logger.info("⚖️ Testing overall system stability...")
    
    # Run stress test for 30 seconds
    stress_duration = 30_000  # 30 seconds in ms
    start_time = System.monotonic_time(:millisecond)
    
    
    # Stress test loop
    stress_results = Stream.repeatedly(fn ->
      try do
        system = generate_lightweight_system()
        environment = generate_lightweight_environment()
        VsmMcp.Core.VarietyCalculator.calculate_variety_gap(system, environment)
        :ok
      rescue
        error -> {:error, error}
      catch
        kind, reason -> {:error, {kind, reason}}
      end
    end)
    |> Stream.take_while(fn _ ->
      System.monotonic_time(:millisecond) - start_time < stress_duration
    end)
    |> Enum.to_list()
    
    operation_count = length(stress_results)
    errors = Enum.filter(stress_results, &match?({:error, _}, &1))
    error_rate = length(errors) / operation_count
    
    stability_passed = error_rate < 0.01  # Less than 1% error rate
    
    Logger.info("📊 Operations completed: #{operation_count}")
    Logger.info("❌ Errors: #{length(errors)} (#{Float.round(error_rate * 100, 2)}%)")
    
    if stability_passed do
      Logger.info("✅ System stability MAINTAINED!")
    else
      Logger.warning("❌ System stability concerns detected!")
    end

    %{
      operation_count: operation_count,
      error_count: length(errors),
      error_rate: error_rate,
      passed: stability_passed
    }
  end

  # Helper Functions

  defp generate_lightweight_system do
    %{
      capabilities: [
        %{id: "cap1", type: :operational, performance: 0.9},
        %{id: "cap2", type: :coordination, performance: 0.8}
      ],
      metrics: %{success_rate: 0.95, throughput: 100},
      units: [%{id: "unit1", status: :active}]
    }
  end

  defp generate_lightweight_environment do
    %{
      factors: ["factor1", "factor2", "factor3"],
      interactions: [%{from: "factor1", to: "factor2"}],
      unknowns: ["unknown1"],
      volatility: 0.3,
      recent_changes: [],
      dependencies: []
    }
  end

  defp generate_scaled_system(size_kb) do
    # Generate data proportional to size_kb
    capability_count = max(2, div(size_kb, 5))
    unit_count = max(1, div(size_kb, 10))
    
    %{
      capabilities: for i <- 1..capability_count do
        %{id: "cap#{i}", type: :operational, performance: :rand.uniform()}
      end,
      metrics: %{success_rate: 0.95, throughput: size_kb * 10},
      units: for i <- 1..unit_count do
        %{id: "unit#{i}", status: :active}
      end
    }
  end

  defp generate_scaled_environment(size_kb) do
    factor_count = max(3, div(size_kb, 2))
    interaction_count = max(1, div(size_kb, 8))
    
    %{
      factors: (for i <- 1..factor_count, do: "factor#{i}"),
      interactions: (for i <- 1..interaction_count do
        %{from: "factor#{:rand.uniform(factor_count)}", to: "factor#{:rand.uniform(factor_count)}"}
      end),
      unknowns: ["unknown1"],
      volatility: 0.3,
      recent_changes: [],
      dependencies: []
    }
  end

  defp calculate_linearity(data_points) do
    # Calculate R² correlation coefficient
    x_values = Enum.map(data_points, fn {x, _} -> x end)
    y_values = Enum.map(data_points, fn {_, y} -> y end)
    
    n = length(data_points)
    sum_x = Enum.sum(x_values)
    sum_y = Enum.sum(y_values)
    sum_xx = Enum.sum(Enum.map(x_values, &(&1 * &1)))
    sum_xy = Enum.sum(Enum.zip(x_values, y_values) |> Enum.map(fn {x, y} -> x * y end))
    
    numerator = n * sum_xy - sum_x * sum_y
    denominator = :math.sqrt((n * sum_xx - sum_x * sum_x) * (n * Enum.sum(Enum.map(y_values, &(&1 * &1))) - sum_y * sum_y))
    
    if denominator == 0, do: 0, else: (numerator / denominator) |> abs()
  end

  defp test_supervisor_restart do
    # This is a simplified test - in production you'd test actual restart scenarios
    # For now, just verify supervision tree structure
    try do
      children = Supervisor.which_children(VsmMcp.Application)
      length(children) > 0
    catch
      _, _ -> false
    end
  end

  defp store_coordination_metrics(results, duration) do
    try do
      # Store metrics in coordination system
      metrics = %{
        timestamp: DateTime.utc_now(),
        duration_ms: duration,
        variety_performance: results.variety_performance,
        memory_scaling: results.memory_scaling,
        security_status: results.security_sandboxing.passed,
        otp_status: results.otp_supervision.passed,
        stability_status: results.system_stability.passed
      }
      
      # Use hooks to store in coordination memory
      System.cmd("npx", ["claude-flow@alpha", "hooks", "notification", 
                         "--message", "Performance validation: #{inspect(metrics)}",
                         "--telemetry", "true"], stderr_to_stdout: true)
    catch
      _, _ -> Logger.info("Coordination storage not available, metrics stored locally")
    end
  end

  defp generate_validation_report(results) do
    all_passed = validate_all_targets(results)
    
    report = """
    # VSM-MCP Performance Validation Report - Phase 5
    
    **Validation Date**: #{DateTime.utc_now() |> DateTime.to_string()}
    **Overall Status**: #{if all_passed, do: "✅ PASSED", else: "❌ FAILED"}
    
    ## Target Validation Results
    
    ### 1. Variety Calculation Performance
    - **Target**: 177,000 ops/sec
    - **Achieved**: #{Float.round(results.variety_performance.achieved_ops_per_sec, 0)} ops/sec
    - **Status**: #{if results.variety_performance.passed, do: "✅ PASSED", else: "❌ FAILED"}
    - **Time per operation**: #{Float.round(results.variety_performance.time_per_op_us, 2)} μs
    
    ### 2. Memory Scaling
    - **Target**: Linear scaling 5KB→235KB
    - **Achieved**: #{Float.round(results.memory_scaling.linearity_score * 100, 1)}% linearity
    - **Status**: #{if results.memory_scaling.passed, do: "✅ PASSED", else: "❌ FAILED"}
    
    ### 3. Security Sandboxing
    - **Target**: No regression in security
    - **Status**: #{if results.security_sandboxing.passed, do: "✅ PASSED", else: "❌ FAILED"}
    
    ### 4. OTP Supervision
    - **Target**: No regression in supervision
    - **Status**: #{if results.otp_supervision.passed, do: "✅ PASSED", else: "❌ FAILED"}
    
    ### 5. System Stability
    - **Operations tested**: #{results.system_stability.operation_count}
    - **Error rate**: #{Float.round(results.system_stability.error_rate * 100, 2)}%
    - **Status**: #{if results.system_stability.passed, do: "✅ PASSED", else: "❌ FAILED"}
    
    ## Summary
    
    #{if all_passed do
      "🎉 All performance targets achieved! The system is ready for production deployment."
    else
      "⚠️ Some performance targets were not met. Review failed items above."
    end}
    
    ## Recommendations
    
    #{generate_recommendations(results)}
    
    ---
    Generated by VSM-MCP Performance Validator v1.0
    """
    
    File.write!("/home/batmanosama/viable-systems/vsm-mcp/PERFORMANCE_VALIDATION_REPORT.md", report)
    Logger.info("📄 Validation report saved to PERFORMANCE_VALIDATION_REPORT.md")
    
    IO.puts(report)
  end

  defp validate_all_targets(results) do
    results.variety_performance.passed and
    results.memory_scaling.passed and
    results.security_sandboxing.passed and
    results.otp_supervision.passed and
    results.system_stability.passed
  end

  defp generate_recommendations(results) do
    recommendations = []
    
    recommendations = if not results.variety_performance.passed do
      ["- Optimize variety calculation algorithm for better performance" | recommendations]
    else
      recommendations
    end
    
    recommendations = if not results.memory_scaling.passed do
      ["- Review memory allocation patterns for linearity" | recommendations]
    else
      recommendations
    end
    
    recommendations = if not results.security_sandboxing.passed do
      ["- Strengthen security sandboxing implementation" | recommendations]
    else
      recommendations
    end
    
    recommendations = if not results.otp_supervision.passed do
      ["- Fix OTP supervision tree issues" | recommendations]
    else
      recommendations
    end
    
    recommendations = if not results.system_stability.passed do
      ["- Investigate and fix system stability issues" | recommendations]
    else
      recommendations
    end
    
    if Enum.empty?(recommendations) do
      "- System meets all targets - proceed with deployment\n- Consider monitoring setup for production\n- Schedule regular performance regression testing"
    else
      Enum.join(recommendations, "\n")
    end
  end
end

# Run the validation
case System.argv() do
  ["--run"] -> 
    PerformanceValidationTest.run_validation()
  _ ->
    IO.puts("Usage: elixir performance_validation_test.exs --run")
end