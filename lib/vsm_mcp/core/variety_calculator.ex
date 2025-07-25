defmodule VsmMcp.Core.VarietyCalculator do
  @moduledoc """
  Variety Calculator based on Ashby's Law of Requisite Variety.
  
  Calculates the variety gap between system capabilities and environmental demands,
  then triggers automatic capability acquisition through MCP discovery.
  """
  use GenServer
  require Logger
  
  alias VsmMcp.Core.MCPDiscovery
  # Note: Using fully qualified names instead of aliases for clarity
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def calculate_variety_gap(system, environment) do
    GenServer.call(__MODULE__, {:calculate_gap, system, environment})
  end

  @doc """
  Direct calculation without GenServer for simple use cases
  """
  def calculate_gap(system, environment) do
    environment - system
  end
  
  def monitor_variety do
    GenServer.call(__MODULE__, :monitor)
  end
  
  def get_variety_report do
    GenServer.call(__MODULE__, :report)
  end
  
  @doc """
  Simple variety calculation for DaemonMode
  Returns a ratio between 0.0 and 1.0
  """
  def calculate do
    GenServer.call(__MODULE__, :calculate_simple)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    state = %{
      monitoring_interval: opts[:interval] || 30_000,  # 30 seconds
      variety_threshold: opts[:threshold] || 0.7,
      history: [],
      active_acquisitions: %{},
      metrics: %{
        calculations: 0,
        gaps_detected: 0,
        acquisitions_triggered: 0,
        successful_acquisitions: 0
      }
    }
    
    # Start periodic monitoring
    Process.send_after(self(), :monitor_variety, state.monitoring_interval)
    
    Logger.info("Variety Calculator initialized with threshold: #{state.variety_threshold}")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:calculate_gap, system, environment}, _from, state) do
    # Get current system variety (capabilities)
    system_variety = calculate_system_variety(system)
    
    # Get environmental variety (demands)
    env_variety = calculate_environmental_variety(environment)
    
    # Calculate the gap
    gap = calculate_variety_analysis(system_variety, env_variety)
    
    # Determine if acquisition is needed
    acquisition_needed = gap.ratio < state.variety_threshold
    
    result = %{
      system_variety: system_variety,
      environmental_variety: env_variety,
      gap: gap,
      acquisition_needed: acquisition_needed,
      timestamp: DateTime.utc_now()
    }
    
    # Update history
    new_history = [result | state.history] |> Enum.take(100)
    new_state = state
      |> Map.put(:history, new_history)
      |> update_metrics(:calculations)
    
    # Trigger acquisition if needed
    new_state = if acquisition_needed do
      trigger_acquisition(gap, new_state)
    else
      new_state
    end
    
    {:reply, result, new_state}
  end
  
  @impl true
  def handle_call(:monitor, _from, state) do
    # Get current system state
    system_status = VsmMcp.Systems.System1.get_status()
    environmental_scan = VsmMcp.Systems.System4.scan_environment()
    
    # Perform variety calculation
    result = calculate_variety_gap(system_status, environmental_scan)
    
    {:reply, result, state}
  end
  
  @impl true
  def handle_call(:report, _from, state) do
    report = %{
      current_acquisitions: state.active_acquisitions,
      metrics: state.metrics,
      recent_history: Enum.take(state.history, 10),
      variety_trends: analyze_variety_trends(state.history)
    }
    
    {:reply, report, state}
  end
  
  @impl true
  def handle_call(:calculate_simple, _from, state) do
    # Simple calculation for DaemonMode
    # Returns a ratio between 0.0 and 1.0
    current_capabilities = try do
      VsmMcp.Integration.CapabilityMatcher.get_all_capabilities()
    rescue
      _ -> ["core", "base", "vsm_integration"]
    end
    
    # Base required capabilities
    required = ["core", "base", "vsm_integration", "monitoring", "adaptation"]
    
    # Calculate ratio
    ratio = if length(required) == 0 do
      1.0
    else
      matched = Enum.count(required, fn req -> req in current_capabilities end)
      matched / length(required)
    end
    
    {:reply, ratio, state}
  end
  
  @impl true
  def handle_info(:monitor_variety, state) do
    # Perform automatic monitoring
    {:ok, env_scan} = VsmMcp.Systems.System4.scan_environment()
    system_status = VsmMcp.Systems.System1.get_status()
    
    # Calculate variety gap
    calculate_variety_gap(system_status, env_scan)
    
    # Schedule next monitoring
    Process.send_after(self(), :monitor_variety, state.monitoring_interval)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:acquisition_complete, acquisition_id, result}, state) do
    # Handle completed acquisition
    new_state = case result do
      {:ok, capability} ->
        Logger.info("Successfully acquired capability: #{inspect(capability)}")
        
        # Add capability to System 1
        VsmMcp.Systems.System1.add_capability(capability)
        
        state
        |> Map.update!(:active_acquisitions, &Map.delete(&1, acquisition_id))
        |> update_metrics(:successful_acquisitions)
      
      {:error, reason} ->
        Logger.error("Failed to acquire capability: #{reason}")
        
        Map.update!(state, :active_acquisitions, &Map.delete(&1, acquisition_id))
    end
    
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp calculate_system_variety(system) do
    %{
      operational: count_operational_variety(system),
      coordination: count_coordination_variety(),
      control: count_control_variety(),
      intelligence: count_intelligence_variety(),
      policy: count_policy_variety(),
      total: 0  # Will be calculated
    }
    |> calculate_total_variety()
  end
  
  defp calculate_environmental_variety(environment) do
    %{
      complexity: analyze_complexity(environment),
      uncertainty: analyze_uncertainty(environment),
      rate_of_change: analyze_change_rate(environment),
      interdependencies: analyze_interdependencies(environment),
      total: 0  # Will be calculated
    }
    |> calculate_total_variety()
  end
  
  defp count_operational_variety(system) do
    # Count distinct operational capabilities
    capabilities = Map.get(system, :capabilities, [])
    base_variety = length(capabilities)
    
    # Add metrics-based variety
    metrics = Map.get(system, :metrics, %{})
    success_rate = Map.get(metrics, :success_rate, 0)
    
    base_variety * (1 + success_rate)
  end
  
  defp count_coordination_variety do
    # Get coordination status
    coord_status = VsmMcp.Systems.System2.get_coordination_status()
    
    # Count coordination patterns
    patterns = Map.get(coord_status, :patterns, [])
    active_coordinations = Map.get(coord_status, :active_coordinations, 0)
    
    length(patterns) + active_coordinations
  end
  
  defp count_control_variety do
    # Get control metrics
    control_metrics = VsmMcp.Systems.System3.get_control_metrics()
    
    # Count control mechanisms
    mechanisms = Map.get(control_metrics, :control_mechanisms, [])
    optimization_strategies = Map.get(control_metrics, :optimization_strategies, [])
    
    length(mechanisms) + length(optimization_strategies)
  end
  
  defp count_intelligence_variety do
    # Get intelligence report
    intel_report = VsmMcp.Systems.System4.get_intelligence_report()
    
    # Count intelligence capabilities
    sensors = Map.get(intel_report, :active_sensors, 0)
    models = Map.get(intel_report, :prediction_models, 0)
    
    sensors + models
  end
  
  defp count_policy_variety do
    # Get policy information
    health = VsmMcp.Systems.System5.review_system_health()
    
    # Count policy dimensions
    policy_coverage = get_in(health, [:components, :policy_coverage]) || 0
    identity_clarity = get_in(health, [:components, :identity_clarity]) || 0
    
    (policy_coverage + identity_clarity) * 10  # Scale up for impact
  end
  
  defp analyze_complexity(environment) do
    # Analyze environmental complexity
    factors = Map.get(environment, :factors, [])
    interactions = Map.get(environment, :interactions, [])
    
    length(factors) + length(interactions) * 2
  end
  
  defp analyze_uncertainty(environment) do
    # Analyze environmental uncertainty
    unknowns = Map.get(environment, :unknowns, [])
    volatility = Map.get(environment, :volatility, 0.5)
    
    length(unknowns) * (1 + volatility)
  end
  
  defp analyze_change_rate(environment) do
    # Analyze rate of environmental change
    changes = Map.get(environment, :recent_changes, [])
    trend = Map.get(environment, :change_trend, 1.0)
    
    length(changes) * trend
  end
  
  defp analyze_interdependencies(environment) do
    # Analyze environmental interdependencies
    dependencies = Map.get(environment, :dependencies, [])
    coupling = Map.get(environment, :coupling_strength, 0.5)
    
    length(dependencies) * (1 + coupling)
  end
  
  defp calculate_total_variety(variety_map) do
    total = variety_map
      |> Map.drop([:total])
      |> Map.values()
      |> Enum.sum()
    
    Map.put(variety_map, :total, total)
  end
  
  defp calculate_variety_analysis(system_variety, env_variety) do
    ratio = if env_variety.total > 0 do
      system_variety.total / env_variety.total
    else
      1.0
    end
    
    %{
      ratio: ratio,
      absolute_gap: env_variety.total - system_variety.total,
      critical_areas: identify_critical_areas(system_variety, env_variety),
      recommendations: generate_recommendations(ratio)
    }
  end
  
  defp identify_critical_areas(system_variety, env_variety) do
    # Identify where the biggest gaps are
    areas = []
    
    areas = if system_variety.operational < env_variety.complexity / 2 do
      ["operational_capabilities" | areas]
    else
      areas
    end
    
    areas = if system_variety.intelligence < env_variety.uncertainty do
      ["environmental_sensing" | areas]
    else
      areas
    end
    
    areas = if system_variety.control < env_variety.rate_of_change do
      ["adaptive_control" | areas]
    else
      areas
    end
    
    areas
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
  
  defp trigger_acquisition(gap, state) do
    acquisition_id = generate_acquisition_id()
    
    # Determine what capabilities to acquire
    required_capabilities = determine_required_capabilities(gap)
    
    # Start acquisition process
    acquisition = %{
      id: acquisition_id,
      gap: gap,
      required_capabilities: required_capabilities,
      started_at: DateTime.utc_now(),
      status: :in_progress
    }
    
    # Spawn acquisition task
    Task.start_link(fn ->
      result = MCPDiscovery.discover_and_acquire(required_capabilities)
      send(self(), {:acquisition_complete, acquisition_id, result})
    end)
    
    state
    |> Map.update!(:active_acquisitions, &Map.put(&1, acquisition_id, acquisition))
    |> update_metrics(:acquisitions_triggered)
    |> update_metrics(:gaps_detected)
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
        
        _ ->
          %{type: :general, priority: :low, search_terms: ["enhance", "improve"]}
      end
    end)
  end
  
  defp analyze_variety_trends(history) do
    if length(history) < 2 do
      %{trend: :insufficient_data}
    else
      recent = Enum.take(history, 10)
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
    # Simple trend calculation
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
  
  defp generate_acquisition_id do
    "acq_#{:erlang.unique_integer([:positive])}_#{:erlang.system_time(:millisecond)}"
  end
  
  defp update_metrics(state, metric) do
    update_in(state, [:metrics, metric], &(&1 + 1))
  end
end