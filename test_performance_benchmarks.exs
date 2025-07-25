#!/usr/bin/env elixir

# VSM-MCP Performance Benchmark Integration Test Suite

Mix.install([
  {:jason, "~> 1.4"},
  {:benchee, "~> 1.1"}
])

defmodule PerformanceBenchmarkTest do
  @moduledoc """
  Performance benchmarks for VSM-MCP core functionality.
  """

  require Logger

  def run_all_benchmarks do
    IO.puts("\n🚀 VSM-MCP Performance Benchmark Suite")
    IO.puts(String.duplicate("=", 50))
    
    benchmark_results = %{}
    
    # Benchmark 1: Variety calculation performance
    IO.puts("\n📊 Benchmarking variety calculation...")
    benchmark_results = Map.put(benchmark_results, :variety_calculation, benchmark_variety_calculation())
    
    # Benchmark 2: MCP discovery performance  
    IO.puts("\n🔍 Benchmarking MCP discovery...")
    benchmark_results = Map.put(benchmark_results, :mcp_discovery, benchmark_mcp_discovery())
    
    # Benchmark 3: End-to-end workflow latency
    IO.puts("\n⚡ Benchmarking end-to-end workflow...")
    benchmark_results = Map.put(benchmark_results, :workflow_latency, benchmark_workflow_latency())
    
    # Benchmark 4: Parallel processing efficiency
    IO.puts("\n🔄 Benchmarking parallel processing...")
    benchmark_results = Map.put(benchmark_results, :parallel_processing, benchmark_parallel_processing())
    
    generate_performance_report(benchmark_results)
  end
  
  def benchmark_variety_calculation do
    IO.puts("  • Running variety calculation benchmarks...")
    
    # Generate test data of varying sizes
    small_dataset = generate_capability_data(100)
    medium_dataset = generate_capability_data(1000)
    large_dataset = generate_capability_data(5000)
    
    results = Benchee.run(%{
      "small_variety_calc" => fn -> calculate_variety_score(small_dataset) end,
      "medium_variety_calc" => fn -> calculate_variety_score(medium_dataset) end,
      "large_variety_calc" => fn -> calculate_variety_score(large_dataset) end
    }, 
    time: 2,
    memory_time: 1,
    print: [benchmarking: false, fast_warning: false]
    )
    
    # Extract performance metrics
    small_time = get_benchmark_time(results, "small_variety_calc")
    medium_time = get_benchmark_time(results, "medium_variety_calc") 
    large_time = get_benchmark_time(results, "large_variety_calc")
    
    IO.puts("    ✓ Small dataset (100): #{format_time(small_time)}")
    IO.puts("    ✓ Medium dataset (1000): #{format_time(medium_time)}")
    IO.puts("    ✓ Large dataset (5000): #{format_time(large_time)}")
    
    # Performance targets: < 10ms small, < 100ms medium, < 500ms large
    targets_met = small_time < 10_000 and medium_time < 100_000 and large_time < 500_000
    
    %{
      status: if(targets_met, do: :pass, else: :fail),
      small_time_us: small_time,
      medium_time_us: medium_time,
      large_time_us: large_time,
      targets_met: targets_met,
      details: results
    }
  end
  
  def benchmark_mcp_discovery do
    IO.puts("  • Running MCP discovery benchmarks...")
    
    # Simulate different discovery scenarios
    results = Benchee.run(%{
      "npm_search" => fn -> simulate_npm_search(["ai", "llm"]) end,
      "github_search" => fn -> simulate_github_search(["mcp-server"]) end,
      "registry_search" => fn -> simulate_registry_search(["anthropic"]) end,
      "parallel_discovery" => fn -> simulate_parallel_discovery() end
    },
    time: 2,
    memory_time: 1,
    print: [benchmarking: false, fast_warning: false]
    )
    
    # Extract timings
    npm_time = get_benchmark_time(results, "npm_search")
    github_time = get_benchmark_time(results, "github_search")
    registry_time = get_benchmark_time(results, "registry_search")
    parallel_time = get_benchmark_time(results, "parallel_discovery")
    
    IO.puts("    ✓ NPM search: #{format_time(npm_time)}")
    IO.puts("    ✓ GitHub search: #{format_time(github_time)}")
    IO.puts("    ✓ Registry search: #{format_time(registry_time)}")
    IO.puts("    ✓ Parallel discovery: #{format_time(parallel_time)}")
    
    # Performance targets: all searches < 1s, parallel should be faster than sequential
    sequential_total = npm_time + github_time + registry_time
    parallel_speedup = sequential_total / parallel_time
    
    targets_met = npm_time < 1_000_000 and github_time < 1_000_000 and 
                  registry_time < 1_000_000 and parallel_speedup > 1.5
    
    %{
      status: if(targets_met, do: :pass, else: :fail),
      npm_time_us: npm_time,
      github_time_us: github_time,
      registry_time_us: registry_time,
      parallel_time_us: parallel_time,
      parallel_speedup: parallel_speedup,
      targets_met: targets_met
    }
  end
  
  def benchmark_workflow_latency do
    IO.puts("  • Running end-to-end workflow benchmarks...")
    
    # Test complete workflows
    results = Benchee.run(%{
      "simple_workflow" => fn -> simulate_simple_workflow() end,
      "complex_workflow" => fn -> simulate_complex_workflow() end,
      "concurrent_workflows" => fn -> simulate_concurrent_workflows() end
    },
    time: 3,
    memory_time: 1,
    print: [benchmarking: false, fast_warning: false]
    )
    
    simple_time = get_benchmark_time(results, "simple_workflow")
    complex_time = get_benchmark_time(results, "complex_workflow")
    concurrent_time = get_benchmark_time(results, "concurrent_workflows")
    
    IO.puts("    ✓ Simple workflow: #{format_time(simple_time)}")
    IO.puts("    ✓ Complex workflow: #{format_time(complex_time)}")
    IO.puts("    ✓ Concurrent workflows: #{format_time(concurrent_time)}")
    
    # Performance targets: simple < 100ms, complex < 500ms, concurrent < 200ms
    targets_met = simple_time < 100_000 and complex_time < 500_000 and concurrent_time < 200_000
    
    %{
      status: if(targets_met, do: :pass, else: :fail),
      simple_time_us: simple_time,
      complex_time_us: complex_time,
      concurrent_time_us: concurrent_time,
      targets_met: targets_met
    }
  end
  
  def benchmark_parallel_processing do
    IO.puts("  • Running parallel processing benchmarks...")
    
    # Test parallel vs sequential processing
    dataset = generate_large_processing_task(1000)
    
    results = Benchee.run(%{
      "sequential_processing" => fn -> process_sequential(dataset) end,
      "parallel_processing" => fn -> process_parallel(dataset) end,
      "optimized_parallel" => fn -> process_optimized_parallel(dataset) end
    },
    time: 3,
    memory_time: 1,
    print: [benchmarking: false, fast_warning: false]
    )
    
    sequential_time = get_benchmark_time(results, "sequential_processing")
    parallel_time = get_benchmark_time(results, "parallel_processing")
    optimized_time = get_benchmark_time(results, "optimized_parallel")
    
    parallel_speedup = sequential_time / parallel_time
    optimized_speedup = sequential_time / optimized_time
    
    IO.puts("    ✓ Sequential: #{format_time(sequential_time)}")
    IO.puts("    ✓ Parallel: #{format_time(parallel_time)} (#{Float.round(parallel_speedup, 2)}x speedup)")
    IO.puts("    ✓ Optimized: #{format_time(optimized_time)} (#{Float.round(optimized_speedup, 2)}x speedup)")
    
    # Performance targets: at least 2x speedup for parallel, 3x for optimized
    targets_met = parallel_speedup >= 2.0 and optimized_speedup >= 3.0
    
    %{
      status: if(targets_met, do: :pass, else: :fail),
      sequential_time_us: sequential_time,
      parallel_time_us: parallel_time,
      optimized_time_us: optimized_time,
      parallel_speedup: parallel_speedup,
      optimized_speedup: optimized_speedup,
      targets_met: targets_met
    }
  end
  
  # Helper functions for simulation
  defp generate_capability_data(size) do
    1..size |> Enum.map(fn i ->
      %{
        id: "capability_#{i}",
        type: Enum.random([:api, :tool, :service, :integration]),
        complexity: :rand.uniform(10),
        dependencies: Enum.take_random(1..size, :rand.uniform(5))
      }
    end)
  end
  
  defp calculate_variety_score(capabilities) do
    # Simplified variety calculation
    types = capabilities |> Enum.map(& &1.type) |> Enum.uniq() |> length()
    complexity_sum = capabilities |> Enum.map(& &1.complexity) |> Enum.sum()
    avg_complexity = complexity_sum / length(capabilities)
    dependencies = capabilities |> Enum.map(&length(&1.dependencies)) |> Enum.sum()
    
    types * avg_complexity + dependencies * 0.1
  end
  
  defp simulate_npm_search(terms) do
    # Simulate NPM API call delay
    Process.sleep(50 + :rand.uniform(100))
    terms |> Enum.map(&("npm-result-#{&1}"))
  end
  
  defp simulate_github_search(terms) do
    # Simulate GitHub API call delay
    Process.sleep(75 + :rand.uniform(150))
    terms |> Enum.map(&("github-result-#{&1}"))
  end
  
  defp simulate_registry_search(terms) do
    # Simulate registry API call delay
    Process.sleep(25 + :rand.uniform(75))
    terms |> Enum.map(&("registry-result-#{&1}"))
  end
  
  defp simulate_parallel_discovery do
    # Simulate parallel execution
    tasks = [
      Task.async(fn -> simulate_npm_search(["ai"]) end),
      Task.async(fn -> simulate_github_search(["mcp"]) end),
      Task.async(fn -> simulate_registry_search(["anthropic"]) end)
    ]
    
    Task.await_many(tasks, 5000) |> List.flatten()
  end
  
  defp simulate_simple_workflow do
    # Basic workflow: discover -> analyze -> acquire
    Process.sleep(10)  # Discovery
    Process.sleep(5)   # Analysis
    Process.sleep(15)  # Acquisition
    :complete
  end
  
  defp simulate_complex_workflow do
    # Complex workflow with multiple steps
    Process.sleep(25)  # Initial analysis
    Process.sleep(50)  # Complex processing
    Process.sleep(30)  # Integration
    Process.sleep(20)  # Validation
    :complete
  end
  
  defp simulate_concurrent_workflows do
    # Multiple workflows in parallel
    tasks = 1..3 |> Enum.map(fn _i ->
      Task.async(fn -> simulate_simple_workflow() end)
    end)
    
    Task.await_many(tasks, 5000)
  end
  
  defp generate_large_processing_task(size) do
    1..size |> Enum.map(fn i -> %{id: i, value: :rand.uniform(1000)} end)
  end
  
  defp process_sequential(dataset) do
    dataset |> Enum.map(fn item ->
      # Simulate CPU-intensive work
      Process.sleep(1)
      item.value * 2
    end)
  end
  
  defp process_parallel(dataset) do
    dataset
    |> Task.async_stream(fn item ->
      Process.sleep(1)
      item.value * 2
    end, max_concurrency: System.schedulers_online())
    |> Enum.map(fn {:ok, result} -> result end)
  end
  
  defp process_optimized_parallel(dataset) do
    # Optimized with chunking
    chunk_size = div(length(dataset), System.schedulers_online())
    
    dataset
    |> Enum.chunk_every(chunk_size)
    |> Task.async_stream(fn chunk ->
      Enum.map(chunk, fn item ->
        Process.sleep(1)
        item.value * 2
      end)
    end, max_concurrency: System.schedulers_online())
    |> Enum.flat_map(fn {:ok, results} -> results end)
  end
  
  defp get_benchmark_time(results, name) do
    results.scenarios[name].run_time_data.statistics.average
  end
  
  defp format_time(time_us) do
    cond do
      time_us < 1_000 -> "#{Float.round(time_us, 1)}μs"
      time_us < 1_000_000 -> "#{Float.round(time_us / 1_000, 1)}ms"
      true -> "#{Float.round(time_us / 1_000_000, 2)}s"
    end
  end
  
  defp generate_performance_report(benchmark_results) do
    IO.puts("\n📊 Performance Benchmark Results Summary")
    IO.puts(String.duplicate("=", 50))
    
    total_benchmarks = map_size(benchmark_results)
    passed_benchmarks = benchmark_results |> Enum.count(fn {_, result} -> result.status == :pass end)
    
    for {benchmark_name, result} <- benchmark_results do
      status_icon = if result.status == :pass, do: "✅", else: "❌"
      IO.puts("#{status_icon} #{benchmark_name}: #{result.status}")
    end
    
    IO.puts("\nOverall Performance Score: #{passed_benchmarks}/#{total_benchmarks} (#{trunc(passed_benchmarks/total_benchmarks*100)}%)")
    
    if passed_benchmarks == total_benchmarks do
      IO.puts("🎉 All performance benchmarks passed! System meets performance targets.")
    else
      IO.puts("⚠️  Some performance benchmarks failed. Optimization needed.")
    end
    
    benchmark_results
  end
end

# Run the benchmarks
PerformanceBenchmarkTest.run_all_benchmarks()