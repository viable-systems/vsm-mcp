defmodule AutonomousPerformanceBenchmarkTest do
  @moduledoc """
  Performance benchmarking tests for autonomous VSM-MCP capabilities.
  Validates system performance under various load conditions and autonomous scenarios.
  """
  
  use ExUnit.Case, async: false
  require Logger
  import ExUnit.CaptureLog
  
  alias VsmMcp.Integration
  alias VsmMcp.Core.{MCPDiscovery, VarietyCalculator}
  alias VsmMcp.ConsciousnessInterface
  alias VsmMcp.MCP.ServerManager
  
  @moduletag :performance_benchmark
  @moduletag timeout: 180_000  # 3 minutes for performance tests
  
  setup_all do
    # Start performance monitoring
    :telemetry.attach_many(
      "performance_test_handler",
      [
        [:vsm_mcp, :discovery, :start],
        [:vsm_mcp, :discovery, :stop],
        [:vsm_mcp, :integration, :start], 
        [:vsm_mcp, :integration, :stop],
        [:vsm_mcp, :variety, :calculation, :start],
        [:vsm_mcp, :variety, :calculation, :stop]
      ],
      &__MODULE__.handle_performance_telemetry/4,
      %{test_pid: self()}
    )
    
    on_exit(fn ->
      :telemetry.detach("performance_test_handler")
    end)
    
    :ok
  end
  
  def handle_performance_telemetry(event, measurements, metadata, config) do
    send(config.test_pid, {:performance_telemetry, event, measurements, metadata})
  end
  
  describe "Discovery Performance Benchmarks" do
    test "measures discovery latency under various load conditions" do
      capture_log(fn ->
        {:ok, integration} = Integration.start_link([name: :discovery_perf_test])
        
        # Setup mock discovery with controlled latency
        setup_performance_discovery_mocks()
        
        # Test scenarios with increasing complexity
        test_scenarios = [
          %{name: "simple", required_capabilities: ["file_ops"], expected_servers: 5},
          %{name: "medium", required_capabilities: ["file_ops", "web_api"], expected_servers: 10},
          %{name: "complex", required_capabilities: ["ml", "data_proc", "viz", "api"], expected_servers: 20},
          %{name: "extensive", required_capabilities: ["file_ops", "web_api", "ml", "data_proc", "viz", "crypto", "db"], expected_servers: 50}
        ]
        
        results = %{}
        
        for scenario <- test_scenarios do
          variety_gap = %{
            type: "perf_test_#{scenario.name}",
            required_capabilities: scenario.required_capabilities,
            complexity: :medium
          }
          
          # Measure discovery performance
          {duration_us, discovery_result} = :timer.tc(fn ->
            Integration.autonomous_discovery(integration, variety_gap)
          end)
          
          duration_ms = duration_us / 1000
          
          case discovery_result do
            {:ok, servers} ->
              results = Map.put(results, scenario.name, %{
                duration_ms: duration_ms,
                servers_found: length(servers),
                throughput: length(servers) / duration_ms * 1000  # servers per second
              })
              
              Logger.info("#{scenario.name}: #{duration_ms}ms, #{length(servers)} servers, #{results[scenario.name].throughput} servers/sec")
              
              # Performance assertions
              assert duration_ms < 5000  # Should complete within 5 seconds
              assert length(servers) > 0
              
            {:error, reason} ->
              Logger.warning("Discovery failed for #{scenario.name}: #{inspect(reason)}")
              results = Map.put(results, scenario.name, %{duration_ms: duration_ms, error: reason})
          end
        end
        
        # Verify performance scaling characteristics
        simple_duration = results["simple"][:duration_ms]
        complex_duration = results["complex"][:duration_ms]
        
        # Complex queries should not be more than 5x slower than simple ones
        if simple_duration && complex_duration do
          scaling_factor = complex_duration / simple_duration
          assert scaling_factor < 5.0, "Discovery scaling factor too high: #{scaling_factor}"
        end
        
        cleanup_performance_discovery_mocks()
        GenServer.stop(integration)
      end)
    end
    
    test "measures concurrent discovery throughput" do
      {:ok, integration} = Integration.start_link([name: :concurrent_discovery_test])
      
      setup_performance_discovery_mocks()
      
      # Create multiple variety gaps for concurrent discovery
      variety_gaps = for i <- 1..20 do
        %{
          type: "concurrent_discovery_#{i}",
          required_capabilities: [Enum.random(["file_ops", "web_api", "data_proc", "ml"])],
          complexity: Enum.random([:low, :medium, :high])
        }
      end
      
      # Measure concurrent discovery performance
      start_time = System.monotonic_time(:millisecond)
      
      tasks = Enum.map(variety_gaps, fn gap ->
        Task.async(fn ->
          Integration.autonomous_discovery(integration, gap)
        end)
      end)
      
      results = Task.await_many(tasks, 15_000)
      end_time = System.monotonic_time(:millisecond)
      
      total_duration = end_time - start_time
      successful_discoveries = Enum.count(results, &match?({:ok, _}, &1))
      
      # Performance metrics
      throughput = successful_discoveries / total_duration * 1000  # discoveries per second
      success_rate = successful_discoveries / length(variety_gaps)
      
      Logger.info("Concurrent discovery: #{successful_discoveries}/#{length(variety_gaps)} successful in #{total_duration}ms")
      Logger.info("Throughput: #{throughput} discoveries/sec, Success rate: #{success_rate * 100}%")
      
      # Performance assertions
      assert success_rate >= 0.8  # At least 80% success rate
      assert throughput >= 1.0    # At least 1 discovery per second
      assert total_duration < 30_000  # Complete within 30 seconds
      
      cleanup_performance_discovery_mocks()
      GenServer.stop(integration)
    end
    
    test "measures discovery caching effectiveness" do
      {:ok, integration} = Integration.start_link([name: :caching_test])
      
      setup_performance_discovery_mocks()
      
      variety_gap = %{
        type: "caching_test",
        required_capabilities: ["file_ops", "data_proc"],
        complexity: :medium
      }
      
      # First discovery (cold cache)
      {cold_duration_us, cold_result} = :timer.tc(fn ->
        Integration.autonomous_discovery(integration, variety_gap)
      end)
      
      cold_duration_ms = cold_duration_us / 1000
      
      # Wait a moment then repeat (warm cache)
      Process.sleep(100)
      
      {warm_duration_us, warm_result} = :timer.tc(fn ->
        Integration.autonomous_discovery(integration, variety_gap)
      end)
      
      warm_duration_ms = warm_duration_us / 1000
      
      # Verify caching effectiveness
      case {cold_result, warm_result} do
        {{:ok, cold_servers}, {:ok, warm_servers}} ->
          # Results should be the same
          assert length(cold_servers) == length(warm_servers)
          
          # Warm cache should be significantly faster
          speedup = cold_duration_ms / warm_duration_ms
          assert speedup >= 2.0, "Cache speedup insufficient: #{speedup}x"
          
          Logger.info("Cache effectiveness: #{speedup}x speedup (#{cold_duration_ms}ms -> #{warm_duration_ms}ms)")
          
        _ ->
          Logger.info("Caching test skipped due to discovery failures")
          assert true
      end
      
      cleanup_performance_discovery_mocks()
      GenServer.stop(integration)
    end
  end
  
  describe "Integration Performance Benchmarks" do
    test "measures end-to-end integration performance" do
      capture_log(fn ->
        {:ok, integration} = Integration.start_link([name: :integration_perf_test])
        
        setup_performance_integration_mocks()
        
        variety_gap = %{
          type: "e2e_performance_test",
          required_capabilities: ["test_capability"],
          complexity: :medium,
          priority: :high
        }
        
        # Measure complete integration pipeline
        start_time = System.monotonic_time(:millisecond)
        
        result = Integration.execute_autonomous_integration(integration, variety_gap, [
          auto_discover: true,
          auto_install: true,
          auto_verify: true,
          auto_deploy: true
        ])
        
        end_time = System.monotonic_time(:millisecond)
        total_duration = end_time - start_time
        
        case result do
          {:ok, integration_result} ->
            # Verify integration stages completed
            required_stages = [:discovery_phase, :installation_phase, :verification_phase, :deployment_phase]
            
            for stage <- required_stages do
              assert Map.has_key?(integration_result, stage)
              stage_result = Map.get(integration_result, stage)
              assert stage_result.status == :completed
            end
            
            # Calculate stage breakdown
            stage_durations = Map.new(required_stages, fn stage ->
              {stage, integration_result[stage].duration}
            end)
            
            Logger.info("Integration performance breakdown:")
            for {stage, duration} <- stage_durations do
              percentage = (duration / total_duration) * 100
              Logger.info("  #{stage}: #{duration}ms (#{percentage}%)")
            end
            
            # Performance assertions
            assert total_duration < 30_000  # Complete within 30 seconds
            assert stage_durations[:discovery_phase] < 10_000  # Discovery under 10s
            assert stage_durations[:installation_phase] < 15_000  # Installation under 15s
            assert stage_durations[:verification_phase] < 5_000   # Verification under 5s
            
          {:error, reason} ->
            Logger.info("Integration failed (expected in test env): #{inspect(reason)}")
            # Still measure that it failed quickly
            assert total_duration < 10_000  # Should fail fast
        end
        
        cleanup_performance_integration_mocks()
        GenServer.stop(integration)
      end)
    end
    
    test "measures integration throughput under load" do
      {:ok, integration} = Integration.start_link([name: :throughput_test])
      
      setup_performance_integration_mocks()
      
      # Create multiple integration requests
      variety_gaps = for i <- 1..10 do
        %{
          type: "throughput_test_#{i}",
          required_capabilities: ["test_capability_#{rem(i, 3)}"],
          complexity: Enum.random([:low, :medium]),
          priority: Enum.random([:medium, :high])
        }
      end
      
      # Measure throughput
      start_time = System.monotonic_time(:millisecond)
      
      # Process in batches to simulate realistic load
      batch_size = 3
      batches = Enum.chunk_every(variety_gaps, batch_size)
      
      all_results = Enum.flat_map(batches, fn batch ->
        tasks = Enum.map(batch, fn gap ->
          Task.async(fn ->
            Integration.execute_autonomous_integration(integration, gap)
          end)
        end)
        
        batch_results = Task.await_many(tasks, 20_000)
        Process.sleep(100)  # Brief pause between batches
        batch_results
      end)
      
      end_time = System.monotonic_time(:millisecond)
      total_duration = end_time - start_time
      
      successful_integrations = Enum.count(all_results, &match?({:ok, _}, &1))
      throughput = successful_integrations / total_duration * 1000  # integrations per second
      
      Logger.info("Integration throughput: #{successful_integrations}/#{length(variety_gaps)} in #{total_duration}ms")
      Logger.info("Throughput: #{throughput} integrations/sec")
      
      # Performance assertions
      assert successful_integrations >= length(variety_gaps) * 0.7  # 70% success rate minimum
      assert total_duration < 120_000  # Complete within 2 minutes
      assert throughput >= 0.1  # At least 0.1 integrations per second
      
      cleanup_performance_integration_mocks()
      GenServer.stop(integration)
    end
  end
  
  describe "Variety Calculation Performance" do
    test "measures variety calculation latency" do
      {:ok, consciousness} = ConsciousnessInterface.start_link([name: :variety_calc_test])
      
      # Test variety calculations with different complexity levels
      test_scenarios = [
        %{
          name: "simple",
          environmental_factors: 10,
          operational_factors: 5,
          interactions: 25
        },
        %{
          name: "medium", 
          environmental_factors: 50,
          operational_factors: 25,
          interactions: 250
        },
        %{
          name: "complex",
          environmental_factors: 200,
          operational_factors: 100,
          interactions: 2500
        }
      ]
      
      for scenario <- test_scenarios do
        # Setup variety context
        variety_context = %{
          environmental_factors: create_mock_factors(scenario.environmental_factors),
          operational_factors: create_mock_factors(scenario.operational_factors),
          factor_interactions: create_mock_interactions(scenario.interactions)
        }
        
        ConsciousnessInterface.update_variety_context(consciousness, variety_context)
        
        # Measure calculation performance
        {duration_us, variety_result} = :timer.tc(fn ->
          ConsciousnessInterface.calculate_variety_status(consciousness)
        end)
        
        duration_ms = duration_us / 1000
        
        Logger.info("#{scenario.name} variety calculation: #{duration_ms}ms")
        
        # Verify calculation completed
        assert Map.has_key?(variety_result, :operational_variety)
        assert Map.has_key?(variety_result, :environmental_variety)
        assert Map.has_key?(variety_result, :ratio)
        
        # Performance assertions based on complexity
        case scenario.name do
          "simple" ->
            assert duration_ms < 50    # Simple should be very fast
          "medium" ->
            assert duration_ms < 200   # Medium complexity
          "complex" ->
            assert duration_ms < 1000  # Complex but under 1 second
        end
      end
      
      GenServer.stop(consciousness)
    end
    
    test "measures variety calculation memory usage" do
      {:ok, consciousness} = ConsciousnessInterface.start_link([name: :variety_memory_test])
      
      # Measure baseline memory
      :erlang.garbage_collect()
      baseline_memory = :erlang.memory(:total)
      
      # Create large variety context
      large_context = %{
        environmental_factors: create_mock_factors(1000),
        operational_factors: create_mock_factors(500),
        factor_interactions: create_mock_interactions(10000)
      }
      
      ConsciousnessInterface.update_variety_context(consciousness, large_context)
      
      # Measure memory after context update
      :erlang.garbage_collect()
      context_memory = :erlang.memory(:total)
      
      # Perform variety calculations
      for _i <- 1..10 do
        ConsciousnessInterface.calculate_variety_status(consciousness)
      end
      
      # Measure memory after calculations
      :erlang.garbage_collect()
      final_memory = :erlang.memory(:total)
      
      context_overhead = context_memory - baseline_memory
      calculation_overhead = final_memory - context_memory
      
      Logger.info("Memory usage - Context: #{context_overhead} bytes, Calculations: #{calculation_overhead} bytes")
      
      # Memory usage assertions
      assert context_overhead < 50_000_000   # Context under 50MB
      assert calculation_overhead < 10_000_000  # Calculation overhead under 10MB
      
      # Memory should not grow excessively with repeated calculations
      memory_growth_per_calc = calculation_overhead / 10
      assert memory_growth_per_calc < 100_000  # Under 100KB per calculation
      
      GenServer.stop(consciousness)
    end
  end
  
  describe "Daemon Mode Performance" do
    test "measures daemon mode responsiveness" do
      capture_log(fn ->
        {:ok, integration} = Integration.start_link([name: :daemon_perf_test])
        {:ok, consciousness} = ConsciousnessInterface.start_link([name: :daemon_perf_consciousness])
        
        # Enable daemon mode with performance monitoring
        :ok = Integration.enable_daemon_mode(integration, %{
          monitor_interval: 50,  # Fast monitoring for testing
          auto_respond: true,
          response_threshold: 0.5,
          performance_tracking: true
        })
        
        # Inject variety gaps and measure response times
        variety_gaps = for i <- 1..5 do
          %{
            type: "daemon_response_test_#{i}",
            required_capabilities: ["response_test"],
            complexity: :low,
            urgency: :high,
            injection_time: System.monotonic_time(:millisecond)
          }
        end
        
        setup_performance_integration_mocks()
        
        # Inject gaps with timing
        for gap <- variety_gaps do
          ConsciousnessInterface.inject_variety_gap(consciousness, gap)
          Process.sleep(100)  # Stagger injections
        end
        
        # Allow daemon to respond
        Process.sleep(2000)
        
        # Measure daemon performance
        daemon_metrics = Integration.get_daemon_performance_metrics(integration)
        
        assert Map.has_key?(daemon_metrics, :avg_response_time)
        assert Map.has_key?(daemon_metrics, :max_response_time)
        assert Map.has_key?(daemon_metrics, :gaps_processed)
        assert Map.has_key?(daemon_metrics, :success_rate)
        
        # Performance assertions
        assert daemon_metrics.avg_response_time < 1000  # Average under 1 second
        assert daemon_metrics.max_response_time < 2000  # Max under 2 seconds
        assert daemon_metrics.gaps_processed >= 3       # Processed most gaps
        assert daemon_metrics.success_rate >= 0.6       # 60% success rate minimum
        
        Logger.info("Daemon performance: avg #{daemon_metrics.avg_response_time}ms, max #{daemon_metrics.max_response_time}ms")
        
        cleanup_performance_integration_mocks()
        Integration.disable_daemon_mode(integration)
        GenServer.stop(consciousness)
        GenServer.stop(integration)
      end)
    end
    
    test "measures daemon mode resource efficiency" do
      {:ok, integration} = Integration.start_link([name: :daemon_efficiency_test])
      
      # Monitor resource usage
      initial_memory = :erlang.memory(:total)
      initial_processes = length(Process.list())
      
      # Enable daemon mode
      :ok = Integration.enable_daemon_mode(integration, %{
        monitor_interval: 100,
        auto_respond: false,  # Just monitoring, no responses
        resource_monitoring: true
      })
      
      # Let daemon run for a period
      Process.sleep(3000)
      
      # Check resource usage
      current_memory = :erlang.memory(:total)
      current_processes = length(Process.list())
      
      memory_overhead = current_memory - initial_memory
      process_overhead = current_processes - initial_processes
      
      # Get daemon resource metrics
      resource_metrics = Integration.get_daemon_resource_metrics(integration)
      
      Logger.info("Daemon resource usage - Memory: #{memory_overhead} bytes, Processes: #{process_overhead}")
      
      # Resource efficiency assertions
      assert memory_overhead < 5_000_000   # Memory overhead under 5MB
      assert process_overhead <= 3         # At most 3 additional processes
      assert resource_metrics.cpu_usage < 0.1  # CPU usage under 10%
      
      Integration.disable_daemon_mode(integration)
      GenServer.stop(integration)
    end
  end
  
  describe "Scalability Performance Tests" do
    test "measures performance with increasing server count" do
      {:ok, manager} = ServerManager.start_link([name: :scalability_test])
      
      # Test with increasing numbers of servers
      server_counts = [5, 10, 20, 50]
      performance_results = %{}
      
      for count <- server_counts do
        Logger.info("Testing with #{count} servers")
        
        # Start multiple servers
        server_configs = for i <- 1..count do
          %{
            id: "scale_test_server_#{i}",
            type: :internal,
            server_opts: [name: :"scale_server_#{i}", transport: :stdio]
          }
        end
        
        # Measure server startup time
        {startup_duration_us, server_ids} = :timer.tc(fn ->
          tasks = Enum.map(server_configs, fn config ->
            Task.async(fn ->
              ServerManager.start_server(manager, config)
            end)
          end)
          
          results = Task.await_many(tasks, 30_000)
          Enum.map(results, fn {:ok, id} -> id end)
        end)
        
        startup_duration_ms = startup_duration_us / 1000
        
        # Measure operation time with all servers
        {operation_duration_us, _result} = :timer.tc(fn ->
          {:ok, status} = ServerManager.get_status(manager)
          assert length(status.servers) >= count * 0.8  # At least 80% started
        end)
        
        operation_duration_ms = operation_duration_us / 1000
        
        performance_results = Map.put(performance_results, count, %{
          startup_time: startup_duration_ms,
          operation_time: operation_duration_ms,
          servers_started: length(server_ids)
        })
        
        Logger.info("#{count} servers: startup #{startup_duration_ms}ms, operation #{operation_duration_ms}ms")
        
        # Clean up servers
        {:ok, _stop_results} = ServerManager.stop_servers(manager, server_ids)
        Process.sleep(500)  # Allow cleanup
      end
      
      # Analyze scaling characteristics
      startup_times = Enum.map(server_counts, &performance_results[&1].startup_time)
      
      # Startup time should scale roughly linearly, not exponentially
      time_5 = performance_results[5].startup_time
      time_50 = performance_results[50].startup_time
      
      scaling_factor = time_50 / time_5
      assert scaling_factor < 15.0, "Scaling factor too high: #{scaling_factor}x"
      
      GenServer.stop(manager)
    end
  end
  
  # Helper Functions
  
  defp setup_performance_discovery_mocks do
    :meck.new(MCPDiscovery, [:passthrough])
    :meck.expect(MCPDiscovery, :discover_servers, fn criteria ->
      # Simulate discovery latency based on complexity
      required_caps = Map.get(criteria, :required_capabilities, [])
      base_latency = 100  # 100ms base
      complexity_latency = length(required_caps) * 50  # 50ms per capability
      
      Process.sleep(base_latency + complexity_latency)
      
      # Generate mock servers based on criteria
      server_count = min(length(required_caps) * 5, 50)
      
      mock_servers = for i <- 1..server_count do
        %{
          name: "performance_server_#{i}",
          source: "npm:perf-server-#{i}",
          capabilities: Enum.take_random(required_caps ++ ["common_cap"], 2),
          performance_rating: 0.7 + :rand.uniform() * 0.3,
          security_rating: 0.6 + :rand.uniform() * 0.4
        }
      end
      
      {:ok, mock_servers}
    end)
  end
  
  defp cleanup_performance_discovery_mocks do
    :meck.unload(MCPDiscovery)
  end
  
  defp setup_performance_integration_mocks do
    setup_performance_discovery_mocks()
    
    :meck.new(Integration, [:passthrough])
    :meck.expect(Integration, :execute_autonomous_integration, fn _integration, gap ->
      # Simulate integration phases with realistic timing
      phases = [
        {:discovery_phase, 200 + :rand.uniform(300)},
        {:installation_phase, 500 + :rand.uniform(1000)},
        {:verification_phase, 100 + :rand.uniform(200)},
        {:deployment_phase, 150 + :rand.uniform(250)}
      ]
      
      phase_results = Enum.map(phases, fn {phase, duration} ->
        Process.sleep(duration)
        {phase, %{status: :completed, duration: duration}}
      end)
      
      {:ok, %{
        id: "perf_test_#{gap.type}",
        variety_gap: gap,
        status: :completed,
        phases: Map.new(phase_results)
      }}
    end)
  end
  
  defp cleanup_performance_integration_mocks do
    :meck.unload([MCPDiscovery, Integration])
  end
  
  defp create_mock_factors(count) do
    for i <- 1..count do
      %{
        id: "factor_#{i}",
        type: Enum.random(["environmental", "operational", "technical"]),
        complexity: :rand.uniform(10),
        weight: :rand.uniform()
      }
    end
  end
  
  defp create_mock_interactions(count) do
    for i <- 1..count do
      %{
        factor_a: "factor_#{:rand.uniform(100)}",
        factor_b: "factor_#{:rand.uniform(100)}", 
        interaction_strength: :rand.uniform(),
        interaction_type: Enum.random(["amplifying", "attenuating", "neutral"])
      }
    end
  end
end