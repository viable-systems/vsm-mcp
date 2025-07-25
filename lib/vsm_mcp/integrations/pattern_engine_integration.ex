defmodule VsmMcp.Integrations.PatternEngineIntegration do
  @moduledoc """
  Integration with VSM Pattern Engine for System 3.
  
  Provides pattern recognition, anomaly detection, and predictive analytics
  capabilities to enhance System 3's control and optimization functions.
  """
  use GenServer
  require Logger
  
  alias VsmMcp.Systems.System3
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def analyze_patterns(data, pattern_type \\ :general) do
    GenServer.call(__MODULE__, {:analyze_patterns, data, pattern_type})
  end
  
  def detect_anomalies(data, threshold \\ 0.95) do
    GenServer.call(__MODULE__, {:detect_anomalies, data, threshold})
  end
  
  def predict_trends(historical_data, horizon \\ 10) do
    GenServer.call(__MODULE__, {:predict_trends, historical_data, horizon})
  end
  
  def train_model(training_data, model_type) do
    GenServer.call(__MODULE__, {:train_model, training_data, model_type}, 60_000)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    state = %{
      pattern_engine: connect_to_pattern_engine(),
      models: %{},
      pattern_cache: %{},
      anomaly_threshold: opts[:anomaly_threshold] || 0.95,
      metrics: %{
        patterns_analyzed: 0,
        anomalies_detected: 0,
        predictions_made: 0,
        models_trained: 0
      }
    }
    
    # Schedule periodic pattern analysis
    Process.send_after(self(), :analyze_system_patterns, 30_000)
    
    Logger.info("Pattern Engine Integration initialized")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:analyze_patterns, data, pattern_type}, _from, state) do
    result = perform_pattern_analysis(data, pattern_type, state)
    
    new_state = state
      |> cache_patterns(result)
      |> update_metrics(:patterns_analyzed)
    
    {:reply, result, new_state}
  end
  
  @impl true
  def handle_call({:detect_anomalies, data, threshold}, _from, state) do
    anomalies = detect_anomalies_in_data(data, threshold, state)
    
    # Alert System 3 if critical anomalies found
    if Enum.any?(anomalies, & &1.severity == :critical) do
      VsmMcp.Systems.System3.handle_anomaly_alert(anomalies)
    end
    
    new_state = update_metrics(state, :anomalies_detected, length(anomalies))
    {:reply, {:ok, anomalies}, new_state}
  end
  
  @impl true
  def handle_call({:predict_trends, historical_data, horizon}, _from, state) do
    predictions = generate_predictions(historical_data, horizon, state)
    
    new_state = update_metrics(state, :predictions_made)
    {:reply, {:ok, predictions}, new_state}
  end
  
  @impl true
  def handle_call({:train_model, training_data, model_type}, _from, state) do
    {:ok, model} = train_pattern_model(training_data, model_type, state)
    
    new_state = state
      |> Map.update!(:models, &Map.put(&1, model_type, model))
      |> update_metrics(:models_trained)
    
    {:reply, {:ok, model}, new_state}
  end
  
  @impl true
  def handle_call(:get_report, _from, state) do
    report = %{
      metrics: state.metrics,
      active_models: Map.keys(state.models),
      cached_patterns: map_size(state.pattern_cache),
      status: :operational
    }
    
    {:reply, report, state}
  end
  
  @impl true
  def handle_info(:analyze_system_patterns, state) do
    # Gather system metrics
    metrics = gather_system_metrics()
    
    # Analyze for patterns
    patterns = perform_pattern_analysis(metrics, :system_health, state)
    
    # Check for concerning patterns
    if patterns.risk_level > 0.7 do
      VsmMcp.Integrations.EventBusIntegration.emit_system_alert(
        :pattern_engine,
        %{
          type: :pattern_risk,
          severity: :high,
          patterns: patterns,
          recommendation: patterns.recommendations
        }
      )
    end
    
    # Schedule next analysis
    Process.send_after(self(), :analyze_system_patterns, 30_000)
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp connect_to_pattern_engine do
    # Connect to VSM Pattern Engine if available
    if Code.ensure_loaded?(VsmPatternEngine) do
      # Initialize connection
      {:ok, :connected}
    else
      Logger.warning("VSM Pattern Engine not available - using fallback")
      {:ok, :fallback}
    end
  end
  
  defp perform_pattern_analysis(data, pattern_type, state) do
    case state.pattern_engine do
      {:ok, :connected} ->
        # Use actual pattern engine if available
        if Code.ensure_loaded?(VsmPatternEngine) do
          VsmPatternEngine.analyze(data, pattern_type)
        else
          fallback_pattern_analysis(data, pattern_type)
        end
      
      {:ok, :fallback} ->
        # Use simplified pattern analysis
        fallback_pattern_analysis(data, pattern_type)
    end
  end
  
  defp fallback_pattern_analysis(data, pattern_type) do
    # Simplified pattern analysis
    %{
      pattern_type: pattern_type,
      patterns_found: extract_simple_patterns(data),
      confidence: 0.75,
      risk_level: calculate_risk_level(data),
      recommendations: generate_recommendations(pattern_type, data),
      timestamp: DateTime.utc_now()
    }
  end
  
  defp extract_simple_patterns(data) when is_list(data) do
    # Find repeating sequences
    data
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.frequencies()
    |> Enum.filter(fn {_, count} -> count > 1 end)
    |> Enum.map(fn {pattern, count} ->
      %{
        pattern: pattern,
        frequency: count,
        type: classify_pattern(pattern)
      }
    end)
  end
  
  defp extract_simple_patterns(data) when is_map(data) do
    # Extract patterns from map data
    data
    |> Map.values()
    |> extract_simple_patterns()
  end
  
  defp classify_pattern(pattern) do
    cond do
      increasing?(pattern) -> :increasing_trend
      decreasing?(pattern) -> :decreasing_trend
      cyclic?(pattern) -> :cyclic
      true -> :irregular
    end
  end
  
  defp increasing?([a, b, c]), do: a < b and b < c
  defp decreasing?([a, b, c]), do: a > b and b > c
  defp cyclic?([a, b, c]), do: a == c and a != b
  
  defp calculate_risk_level(data) do
    # Simple risk calculation based on variance
    values = extract_numeric_values(data)
    
    if length(values) > 0 do
      mean = Enum.sum(values) / length(values)
      variance = Enum.sum(Enum.map(values, fn x -> :math.pow(x - mean, 2) end)) / length(values)
      std_dev = :math.sqrt(variance)
      
      # Normalize to 0-1 range
      min(std_dev / mean, 1.0)
    else
      0.5
    end
  end
  
  defp extract_numeric_values(data) when is_list(data) do
    Enum.filter(data, &is_number/1)
  end
  
  defp extract_numeric_values(data) when is_map(data) do
    data
    |> Map.values()
    |> Enum.filter(&is_number/1)
  end
  
  defp generate_recommendations(pattern_type, _data) do
    case pattern_type do
      :system_health ->
        ["Monitor resource utilization", "Review recent changes", "Check system logs"]
      
      :performance ->
        ["Optimize bottlenecks", "Scale resources if needed", "Review caching strategies"]
      
      :anomaly ->
        ["Investigate unusual patterns", "Check for security issues", "Review access logs"]
      
      _ ->
        ["Continue monitoring", "Collect more data", "Review thresholds"]
    end
  end
  
  defp detect_anomalies_in_data(data, threshold, _state) do
    # Simple anomaly detection using statistical methods
    values = extract_numeric_values(data)
    
    if length(values) > 3 do
      mean = Enum.sum(values) / length(values)
      std_dev = calculate_std_dev(values, mean)
      
      values
      |> Enum.with_index()
      |> Enum.filter(fn {value, _} ->
        abs(value - mean) > threshold * std_dev
      end)
      |> Enum.map(fn {value, index} ->
        %{
          index: index,
          value: value,
          deviation: (value - mean) / std_dev,
          severity: classify_anomaly_severity((value - mean) / std_dev),
          timestamp: DateTime.utc_now()
        }
      end)
    else
      []
    end
  end
  
  defp calculate_std_dev(values, mean) do
    variance = Enum.sum(Enum.map(values, fn x -> :math.pow(x - mean, 2) end)) / length(values)
    :math.sqrt(variance)
  end
  
  defp classify_anomaly_severity(deviation) do
    abs_dev = abs(deviation)
    
    cond do
      abs_dev > 4 -> :critical
      abs_dev > 3 -> :high
      abs_dev > 2 -> :medium
      true -> :low
    end
  end
  
  defp generate_predictions(historical_data, horizon, _state) do
    # Simple linear prediction
    values = extract_numeric_values(historical_data)
    
    if length(values) >= 2 do
      # Calculate trend
      trend = calculate_trend(values)
      last_value = List.last(values)
      
      # Generate predictions
      1..horizon
      |> Enum.map(fn i ->
        %{
          period: i,
          predicted_value: last_value + (trend * i),
          confidence: max(0.3, 1.0 - (i * 0.05)),  # Confidence decreases with horizon
          method: :linear_trend
        }
      end)
    else
      []
    end
  end
  
  defp calculate_trend(values) do
    n = length(values)
    indices = 0..(n-1) |> Enum.to_list()
    
    # Simple linear regression
    x_mean = Enum.sum(indices) / n
    y_mean = Enum.sum(values) / n
    
    numerator = Enum.zip(indices, values)
      |> Enum.map(fn {x, y} -> (x - x_mean) * (y - y_mean) end)
      |> Enum.sum()
    
    denominator = indices
      |> Enum.map(fn x -> :math.pow(x - x_mean, 2) end)
      |> Enum.sum()
    
    if denominator > 0, do: numerator / denominator, else: 0
  end
  
  defp train_pattern_model(training_data, model_type, _state) do
    # Simplified model training
    model = %{
      type: model_type,
      trained_at: DateTime.utc_now(),
      training_size: length(training_data),
      parameters: extract_model_parameters(training_data, model_type)
    }
    
    {:ok, model}
  end
  
  defp extract_model_parameters(training_data, model_type) do
    case model_type do
      :classification ->
        %{
          classes: extract_classes(training_data),
          features: extract_features(training_data)
        }
      
      :regression ->
        %{
          coefficients: calculate_regression_coefficients(training_data),
          r_squared: 0.0  # Placeholder
        }
      
      :clustering ->
        %{
          clusters: 3,  # Default
          centroids: []  # Placeholder
        }
      
      _ ->
        %{}
    end
  end
  
  defp extract_classes(training_data) do
    training_data
    |> Enum.map(& &1[:class])
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end
  
  defp extract_features(training_data) do
    case List.first(training_data) do
      nil -> []
      first -> Map.keys(first) -- [:class, :label, :target]
    end
  end
  
  defp calculate_regression_coefficients(_training_data) do
    # Placeholder for regression coefficients
    %{intercept: 0.0, slope: 1.0}
  end
  
  defp gather_system_metrics do
    %{
      system1: VsmMcp.Systems.System1.get_status().metrics,
      system2: VsmMcp.Systems.System2.get_coordination_status(),
      system3: VsmMcp.Systems.System3.get_control_metrics(),
      system4: VsmMcp.Systems.System4.get_intelligence_report(),
      system5: VsmMcp.Systems.System5.review_system_health(),
      timestamp: DateTime.utc_now()
    }
  end
  
  defp cache_patterns(state, patterns) do
    cache_key = :erlang.phash2(patterns)
    Map.update!(state, :pattern_cache, &Map.put(&1, cache_key, patterns))
  end
  
  defp update_metrics(state, metric, count \\ 1) do
    update_in(state, [:metrics, metric], &(&1 + count))
  end
  
  @doc """
  Get pattern analysis report for System 3.
  """
  def get_pattern_report do
    GenServer.call(__MODULE__, :get_report)
  end
end