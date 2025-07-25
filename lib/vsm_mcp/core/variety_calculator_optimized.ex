defmodule VsmMcp.Core.VarietyCalculatorOptimized do
  @moduledoc """
  Optimized Variety Calculator with parallel execution and caching.
  
  Key optimizations:
  - Parallel variety calculations using Task.async_stream
  - ETS-based caching for repeated calculations
  - Connection pooling for external services
  - Non-blocking GenServer calls
  - Batch processing for multiple variety gaps
  """
  use GenServer
  require Logger
  
  alias VsmMcp.Core.MCPDiscoveryOptimized
  # Note: Using fully qualified names instead of aliases for clarity
  
  # ETS table names
  @variety_cache :variety_cache
  @metrics_cache :variety_metrics_cache
  
  # Performance settings
  @parallel_threshold 3
  @cache_ttl_ms 60_000  # 1 minute
  @batch_size 10
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def calculate_variety_gap(system, environment) do
    GenServer.call(__MODULE__, {:calculate_gap, system, environment}, 10_000)
  end
  
  def calculate_variety_gaps_batch(system_env_pairs) do
    GenServer.call(__MODULE__, {:calculate_gaps_batch, system_env_pairs}, 30_000)
  end
  
  def monitor_variety_async do
    GenServer.cast(__MODULE__, :monitor_async)
  end
  
  def get_variety_report do
    GenServer.call(__MODULE__, :report)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    # Create ETS tables for caching
    :ets.new(@variety_cache, [:named_table, :public, :set, {:read_concurrency, true}])
    :ets.new(@metrics_cache, [:named_table, :public, :set, {:write_concurrency, true}])
    
    state = %{
      monitoring_interval: opts[:interval] || 30_000,
      variety_threshold: opts[:threshold] || 0.7,
      history: :queue.new(),
      active_acquisitions: %{},
      metrics: %{
        calculations: 0,
        cache_hits: 0,
        gaps_detected: 0,
        acquisitions_triggered: 0,
        successful_acquisitions: 0,
        parallel_executions: 0
      },
      pool_size: opts[:pool_size] || System.schedulers_online() * 2
    }
    
    # Start periodic monitoring
    Process.send_after(self(), :monitor_variety, state.monitoring_interval)
    
    # Start cache cleanup process
    Process.send_after(self(), :cleanup_cache, @cache_ttl_ms)
    
    Logger.info("Optimized Variety Calculator initialized with threshold: #{state.variety_threshold}")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:calculate_gap, system, environment}, _from, state) do
    # Check cache first
    cache_key = generate_cache_key(system, environment)
    
    case get_from_cache(cache_key) do
      {:ok, cached_result} ->
        new_state = update_metrics(state, :cache_hits)
        {:reply, cached_result, new_state}
      
      :not_found ->
        # Perform parallel calculation
        {result, calculation_time} = :timer.tc(fn ->
          calculate_variety_gap_parallel(system, environment, state)
        end)
        
        # Cache the result
        put_in_cache(cache_key, result, @cache_ttl_ms)
        
        # Update metrics
        :ets.update_counter(@metrics_cache, :total_calculation_time, {2, calculation_time}, {:total_calculation_time, 0})
        
        new_state = state
          |> add_to_history(result)
          |> update_metrics(:calculations)
          |> maybe_trigger_acquisition(result)
        
        {:reply, result, new_state}
    end
  end
  
  @impl true
  def handle_call({:calculate_gaps_batch, system_env_pairs}, _from, state) do
    # Process variety gaps in parallel batches
    results = system_env_pairs
      |> Enum.chunk_every(@batch_size)
      |> Enum.flat_map(fn batch ->
        batch
        |> Task.async_stream(
          fn {system, env} -> 
            calculate_variety_gap_parallel(system, env, state)
          end,
          max_concurrency: state.pool_size,
          timeout: 5_000
        )
        |> Enum.map(fn {:ok, result} -> result end)
      end)
    
    new_state = state
      |> update_metrics(:calculations, length(results))
      |> update_metrics(:parallel_executions)
    
    # Trigger acquisitions for all gaps that need it
    gaps_needing_acquisition = Enum.filter(results, & &1.acquisition_needed)
    new_state = trigger_batch_acquisitions(gaps_needing_acquisition, new_state)
    
    {:reply, {:ok, results}, new_state}
  end
  
  @impl true
  def handle_cast(:monitor_async, state) do
    # Spawn async monitoring task
    Task.start_link(fn ->
      perform_async_monitoring(state)
    end)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_call(:report, _from, state) do
    # Get metrics from ETS
    total_time = case :ets.lookup(@metrics_cache, :total_calculation_time) do
      [{_, time}] -> time
      [] -> 0
    end
    
    avg_time = if state.metrics.calculations > 0 do
      total_time / state.metrics.calculations / 1000  # Convert to ms
    else
      0
    end
    
    report = %{
      current_acquisitions: state.active_acquisitions,
      metrics: Map.put(state.metrics, :avg_calculation_time_ms, avg_time),
      recent_history: :queue.to_list(state.history) |> Enum.take(-10),
      variety_trends: analyze_variety_trends(state.history),
      cache_efficiency: calculate_cache_efficiency(state.metrics),
      parallel_efficiency: calculate_parallel_efficiency(state.metrics)
    }
    
    {:reply, report, state}
  end
  
  @impl true
  def handle_info(:monitor_variety, state) do
    # Use async monitoring
    GenServer.cast(self(), :monitor_async)
    
    # Schedule next monitoring
    Process.send_after(self(), :monitor_variety, state.monitoring_interval)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:cleanup_cache, state) do
    # Clean expired cache entries
    now = System.monotonic_time(:millisecond)
    
    :ets.select_delete(@variety_cache, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    
    # Schedule next cleanup
    Process.send_after(self(), :cleanup_cache, @cache_ttl_ms)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:acquisition_complete, acquisition_id, result}, state) do
    # Handle completed acquisition
    new_state = case result do
      {:ok, capabilities} ->
        Logger.info("Successfully acquired #{length(capabilities)} capabilities")
        
        # Add capabilities to System 1 in parallel
        Task.async_stream(
          capabilities,
          &VsmMcp.Systems.System1.add_capability/1,
          max_concurrency: 4
        )
        |> Stream.run()
        
        state
        |> Map.update!(:active_acquisitions, &Map.delete(&1, acquisition_id))
        |> update_metrics(:successful_acquisitions)
      
      {:error, reason} ->
        Logger.error("Failed to acquire capabilities: #{reason}")
        
        Map.update!(state, :active_acquisitions, &Map.delete(&1, acquisition_id))
    end
    
    {:noreply, new_state}
  end
  
  # Private Functions - Parallel Calculations
  
  defp calculate_variety_gap_parallel(system, environment, state) do
    # Run variety calculations in parallel
    tasks = [
      Task.async(fn -> calculate_system_variety_parallel(system) end),
      Task.async(fn -> calculate_environmental_variety_parallel(environment) end)
    ]
    
    [system_variety, env_variety] = Task.await_many(tasks, 5_000)
    
    # Calculate gap
    gap = calculate_gap(system_variety, env_variety)
    
    # Determine if acquisition is needed
    acquisition_needed = gap.ratio < state.variety_threshold
    
    %{
      system_variety: system_variety,
      environmental_variety: env_variety,
      gap: gap,
      acquisition_needed: acquisition_needed,
      timestamp: DateTime.utc_now()
    }
  end
  
  defp calculate_system_variety_parallel(system) do
    # Parallel calculation of system variety components
    tasks = [
      Task.async(fn -> {:operational, count_operational_variety(system)} end),
      Task.async(fn -> {:coordination, count_coordination_variety()} end),
      Task.async(fn -> {:control, count_control_variety()} end),
      Task.async(fn -> {:intelligence, count_intelligence_variety()} end),
      Task.async(fn -> {:policy, count_policy_variety()} end)
    ]
    
    components = tasks
      |> Task.await_many(3_000)
      |> Map.new()
    
    total = Map.values(components) |> Enum.sum()
    Map.put(components, :total, total)
  end
  
  defp calculate_environmental_variety_parallel(environment) do
    # Parallel calculation of environmental variety components
    tasks = [
      Task.async(fn -> {:complexity, analyze_complexity(environment)} end),
      Task.async(fn -> {:uncertainty, analyze_uncertainty(environment)} end),
      Task.async(fn -> {:rate_of_change, analyze_change_rate(environment)} end),
      Task.async(fn -> {:interdependencies, analyze_interdependencies(environment)} end)
    ]
    
    components = tasks
      |> Task.await_many(3_000)
      |> Map.new()
    
    total = Map.values(components) |> Enum.sum()
    Map.put(components, :total, total)
  end
  
  # Variety counting functions (optimized versions)
  
  defp count_operational_variety(system) do
    capabilities = Map.get(system, :capabilities, [])
    base_variety = length(capabilities)
    
    metrics = Map.get(system, :metrics, %{})
    success_rate = Map.get(metrics, :success_rate, 0)
    
    base_variety * (1 + success_rate)
  end
  
  defp count_coordination_variety do
    # Use cached value if available
    case get_from_cache(:coordination_variety) do
      {:ok, value} -> value
      :not_found ->
        coord_status = VsmMcp.Systems.System2.get_coordination_status()
        patterns = Map.get(coord_status, :patterns, [])
        active_coordinations = Map.get(coord_status, :active_coordinations, 0)
        
        value = length(patterns) + active_coordinations
        put_in_cache(:coordination_variety, value, 5_000)  # Cache for 5 seconds
        value
    end
  end
  
  defp count_control_variety do
    control_metrics = VsmMcp.Systems.System3.get_control_metrics()
    mechanisms = Map.get(control_metrics, :control_mechanisms, [])
    optimization_strategies = Map.get(control_metrics, :optimization_strategies, [])
    
    length(mechanisms) + length(optimization_strategies)
  end
  
  defp count_intelligence_variety do
    intel_report = VsmMcp.Systems.System4.get_intelligence_report()
    sensors = Map.get(intel_report, :active_sensors, 0)
    models = Map.get(intel_report, :prediction_models, 0)
    
    sensors + models
  end
  
  defp count_policy_variety do
    health = VsmMcp.Systems.System5.review_system_health()
    policy_coverage = get_in(health, [:components, :policy_coverage]) || 0
    identity_clarity = get_in(health, [:components, :identity_clarity]) || 0
    
    (policy_coverage + identity_clarity) * 10
  end
  
  # Environmental analysis functions
  
  defp analyze_complexity(environment) do
    factors = Map.get(environment, :factors, [])
    interactions = Map.get(environment, :interactions, [])
    
    length(factors) + length(interactions) * 2
  end
  
  defp analyze_uncertainty(environment) do
    unknowns = Map.get(environment, :unknowns, [])
    volatility = Map.get(environment, :volatility, 0.5)
    
    length(unknowns) * (1 + volatility)
  end
  
  defp analyze_change_rate(environment) do
    changes = Map.get(environment, :recent_changes, [])
    trend = Map.get(environment, :change_trend, 1.0)
    
    length(changes) * trend
  end
  
  defp analyze_interdependencies(environment) do
    dependencies = Map.get(environment, :dependencies, [])
    coupling = Map.get(environment, :coupling_strength, 0.5)
    
    length(dependencies) * (1 + coupling)
  end
  
  # Gap calculation and recommendations
  
  defp calculate_gap(system_variety, env_variety) do
    ratio = if env_variety.total > 0 do
      system_variety.total / env_variety.total
    else
      1.0
    end
    
    %{
      ratio: ratio,
      absolute_gap: env_variety.total - system_variety.total,
      critical_areas: identify_critical_areas_parallel(system_variety, env_variety),
      recommendations: generate_recommendations(ratio)
    }
  end
  
  defp identify_critical_areas_parallel(system_variety, env_variety) do
    checks = [
      {system_variety.operational < env_variety.complexity / 2, "operational_capabilities"},
      {system_variety.intelligence < env_variety.uncertainty, "environmental_sensing"},
      {system_variety.control < env_variety.rate_of_change, "adaptive_control"},
      {system_variety.coordination < env_variety.interdependencies / 2, "coordination_patterns"}
    ]
    
    checks
    |> Enum.filter(fn {condition, _} -> condition end)
    |> Enum.map(fn {_, area} -> area end)
  end
  
  defp generate_recommendations(ratio) do
    cond do
      ratio >= 1.0 ->
        ["System has requisite variety", "Continue monitoring"]
      
      ratio >= 0.8 ->
        ["Minor variety gap detected", "Consider capability enhancement"]
      
      ratio >= 0.6 ->
        ["Significant variety gap", "Acquire new capabilities", "Enhance coordination"]
      
      true ->
        ["Critical variety gap", "Immediate capability acquisition required", "System at risk"]
    end
  end
  
  # Acquisition handling (optimized)
  
  defp maybe_trigger_acquisition(state, result) do
    if result.acquisition_needed do
      trigger_acquisition_async(result.gap, state)
    else
      state
    end
  end
  
  defp trigger_acquisition_async(gap, state) do
    acquisition_id = generate_acquisition_id()
    
    required_capabilities = determine_required_capabilities(gap)
    
    acquisition = %{
      id: acquisition_id,
      gap: gap,
      required_capabilities: required_capabilities,
      started_at: DateTime.utc_now(),
      status: :in_progress
    }
    
    # Spawn async acquisition task
    Task.start_link(fn ->
      result = MCPDiscoveryOptimized.discover_and_acquire_parallel(required_capabilities)
      send(self(), {:acquisition_complete, acquisition_id, result})
    end)
    
    state
    |> Map.update!(:active_acquisitions, &Map.put(&1, acquisition_id, acquisition))
    |> update_metrics(:acquisitions_triggered)
    |> update_metrics(:gaps_detected)
  end
  
  defp trigger_batch_acquisitions(gaps, state) do
    # Group gaps by type for efficient batch processing
    grouped_gaps = Enum.group_by(gaps, fn result ->
      hd(result.gap.critical_areas)
    end)
    
    Enum.reduce(grouped_gaps, state, fn {_type, gap_results}, acc_state ->
      # Combine required capabilities
      all_capabilities = gap_results
        |> Enum.flat_map(fn result -> 
          determine_required_capabilities(result.gap)
        end)
        |> Enum.uniq_by(& &1.type)
      
      trigger_acquisition_async(%{critical_areas: [_type]}, acc_state)
    end)
  end
  
  defp determine_required_capabilities(gap) do
    gap.critical_areas
    |> Enum.map(fn area ->
      case area do
        "operational_capabilities" ->
          %{type: :operational, priority: :high, search_terms: ["process", "transform", "execute"]}
        
        "environmental_sensing" ->
          %{type: :intelligence, priority: :high, search_terms: ["monitor", "analyze", "predict"]}
        
        "adaptive_control" ->
          %{type: :control, priority: :medium, search_terms: ["optimize", "adapt", "regulate"]}
        
        "coordination_patterns" ->
          %{type: :coordination, priority: :high, search_terms: ["coordinate", "sync", "orchestrate"]}
        
        _ ->
          %{type: :general, priority: :low, search_terms: ["enhance", "improve"]}
      end
    end)
  end
  
  # Async monitoring
  
  defp perform_async_monitoring(state) do
    # Get environment scan and system status in parallel
    tasks = [
      Task.async(fn -> VsmMcp.Systems.System4.scan_environment() end),
      Task.async(fn -> VsmMcp.Systems.System1.get_status() end)
    ]
    
    case Task.await_many(tasks, 5_000) do
      [{:ok, env_scan}, system_status] ->
        calculate_variety_gap_parallel(system_status, env_scan, state)
      
      _ ->
        Logger.error("Failed to perform async monitoring")
    end
  end
  
  # Caching functions
  
  defp generate_cache_key(system, environment) do
    :erlang.phash2({system, environment})
  end
  
  defp get_from_cache(key) do
    case :ets.lookup(@variety_cache, key) do
      [{^key, value, expiry}] ->
        if System.monotonic_time(:millisecond) < expiry do
          {:ok, value}
        else
          :ets.delete(@variety_cache, key)
          :not_found
        end
      [] ->
        :not_found
    end
  end
  
  defp put_in_cache(key, value, ttl_ms) do
    expiry = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(@variety_cache, {key, value, expiry})
  end
  
  # History and metrics
  
  defp add_to_history(state, result) do
    new_history = :queue.in(result, state.history)
    
    # Keep only last 100 entries
    trimmed_history = if :queue.len(new_history) > 100 do
      {_, rest} = :queue.out(new_history)
      rest
    else
      new_history
    end
    
    Map.put(state, :history, trimmed_history)
  end
  
  defp analyze_variety_trends(history) do
    history_list = :queue.to_list(history)
    
    if length(history_list) < 2 do
      %{trend: :insufficient_data}
    else
      recent = Enum.take(history_list, -10)
      ratios = Enum.map(recent, & &1.gap.ratio)
      
      avg_ratio = Enum.sum(ratios) / length(ratios)
      trend = calculate_trend(ratios)
      
      %{
        average_ratio: avg_ratio,
        trend: trend,
        trajectory: interpret_trend(trend)
      }
    end
  end
  
  defp calculate_trend(ratios) do
    if length(ratios) < 2 do
      0.0
    else
      first_half = Enum.take(ratios, div(length(ratios), 2))
      second_half = Enum.drop(ratios, div(length(ratios), 2))
      
      avg_first = Enum.sum(first_half) / length(first_half)
      avg_second = Enum.sum(second_half) / length(second_half)
      
      avg_second - avg_first
    end
  end
  
  defp interpret_trend(trend) do
    cond do
      trend > 0.1 -> :improving
      trend < -0.1 -> :degrading
      true -> :stable
    end
  end
  
  defp calculate_cache_efficiency(metrics) do
    total_requests = metrics.calculations + metrics.cache_hits
    
    if total_requests > 0 do
      metrics.cache_hits / total_requests * 100
    else
      0.0
    end
  end
  
  defp calculate_parallel_efficiency(metrics) do
    if metrics.calculations > 0 do
      metrics.parallel_executions / metrics.calculations * 100
    else
      0.0
    end
  end
  
  defp generate_acquisition_id do
    "acq_#{:erlang.unique_integer([:positive])}_#{:erlang.system_time(:millisecond)}"
  end
  
  defp update_metrics(state, metric, count \\ 1) do
    put_in(state.metrics[metric], Map.get(state.metrics, metric, 0) + count)
  end
end