defmodule VsmMcp.Systems.System4 do
  @moduledoc """
  System 4: Intelligence
  
  Monitors the external environment and provides strategic intelligence
  for adaptation and future planning.
  """
  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def scan_environment(scope \\ :all) do
    GenServer.call(__MODULE__, {:scan, scope})
  end

  def get_status do
    GenServer.call(__MODULE__, :status)
  end

  def get_environmental_data do
    GenServer.call(__MODULE__, :get_environmental_data)
  end

  def analyze_environment(scope, parameters) do
    GenServer.call(__MODULE__, {:analyze_environment, scope, parameters})
  end

  def analyze_trends(data_source) do
    GenServer.call(__MODULE__, {:analyze_trends, data_source})
  end

  def predict_future_state(parameters) do
    GenServer.call(__MODULE__, {:predict, parameters})
  end

  def add_intelligence_source(source) do
    GenServer.cast(__MODULE__, {:add_source, source})
  end

  def get_intelligence_report do
    GenServer.call(__MODULE__, :report)
  end

  def register_alert(condition, callback) do
    GenServer.cast(__MODULE__, {:register_alert, condition, callback})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      intelligence_sources: default_sources(),
      environmental_data: %{},
      trend_analysis: %{},
      predictions: [],
      alerts: [],
      scan_interval: 10_000
    }
    
    # Schedule periodic environmental scanning
    Process.send_after(self(), :periodic_scan, state.scan_interval)
    
    Logger.info("System 4 (Intelligence) initialized with #{map_size(state.intelligence_sources)} sources")
    {:ok, state}
  end

  @impl true
  def handle_call({:scan, scope}, _from, state) do
    scan_results = perform_environmental_scan(scope, state.intelligence_sources)
    
    new_environmental_data = Map.merge(state.environmental_data, scan_results)
    new_state = Map.put(state, :environmental_data, new_environmental_data)
    
    # Check alerts
    check_alerts(scan_results, state.alerts)
    
    {:reply, {:ok, scan_results}, new_state}
  end

  @impl true
  def handle_call({:analyze_trends, data_source}, _from, state) do
    relevant_data = Map.get(state.environmental_data, data_source, %{})
    trend_analysis = analyze_data_trends(relevant_data)
    
    new_trend_analysis = Map.put(state.trend_analysis, data_source, trend_analysis)
    new_state = Map.put(state, :trend_analysis, new_trend_analysis)
    
    {:reply, {:ok, trend_analysis}, new_state}
  end

  @impl true
  def handle_call({:predict, parameters}, _from, state) do
    prediction = generate_prediction(parameters, state)
    
    new_predictions = [prediction | state.predictions] |> Enum.take(100)
    new_state = Map.put(state, :predictions, new_predictions)
    
    {:reply, {:ok, prediction}, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    # Extract opportunities and threats from environmental data
    {opportunities, threats} = extract_opportunities_and_threats(state.environmental_data)
    
    status = %{
      active: true,
      intelligence_sources: map_size(state.intelligence_sources),
      environmental_data_points: map_size(state.environmental_data),
      trends_analyzed: map_size(state.trend_analysis),
      predictions_made: length(state.predictions),
      active_alerts: length(state.alerts),
      scan_interval: state.scan_interval,
      last_scan: get_last_scan_time(state.environmental_data),
      data_freshness: calculate_data_freshness(state.environmental_data),
      opportunities: opportunities,
      threats: threats
    }
    
    {:reply, status, state}
  end

  @impl true
  def handle_call(:get_environmental_data, _from, state) do
    {:reply, state.environmental_data, state}
  end

  @impl true
  def handle_call({:analyze_environment, scope, parameters}, _from, state) do
    # Perform comprehensive environmental analysis
    analysis_result = perform_environmental_analysis(scope, parameters, state)
    
    # Update state with analysis insights
    new_state = update_analysis_insights(state, analysis_result)
    
    {:reply, {:ok, analysis_result}, new_state}
  end

  @impl true
  def handle_call(:report, _from, state) do
    report = compile_intelligence_report(state)
    {:reply, report, state}
  end

  @impl true
  def handle_cast({:add_source, source}, state) do
    new_sources = Map.put(state.intelligence_sources, source.id, source)
    Logger.info("Added intelligence source: #{source.id}")
    {:noreply, Map.put(state, :intelligence_sources, new_sources)}
  end

  @impl true
  def handle_cast({:register_alert, condition, callback}, state) do
    alert = %{
      id: generate_id(),
      condition: condition,
      callback: callback,
      created_at: DateTime.utc_now()
    }
    
    new_alerts = [alert | state.alerts]
    {:noreply, Map.put(state, :alerts, new_alerts)}
  end

  @impl true
  def handle_info(:periodic_scan, state) do
    # Perform automatic environmental scan
    scan_results = perform_environmental_scan(:auto, state.intelligence_sources)
    
    new_environmental_data = Map.merge(state.environmental_data, scan_results)
    new_state = Map.put(state, :environmental_data, new_environmental_data)
    
    # Check alerts
    check_alerts(scan_results, state.alerts)
    
    # Schedule next scan
    Process.send_after(self(), :periodic_scan, state.scan_interval)
    
    {:noreply, new_state}
  end

  # Private Functions

  defp perform_environmental_scan(scope, sources) do
    sources
    |> Map.values()
    |> Enum.filter(fn source -> 
      scope == :all or scope == :auto or source.category == scope 
    end)
    |> Enum.map(fn source ->
      data = scan_source(source)
      {source.id, data}
    end)
    |> Map.new()
  end

  defp scan_source(source) do
    # Simulate data collection from various sources
    %{
      timestamp: DateTime.utc_now(),
      metrics: generate_source_metrics(source.type),
      signals: detect_signals(source),
      anomalies: detect_anomalies(source)
    }
  end

  defp generate_source_metrics(type) do
    case type do
      :market ->
        %{
          demand: Enum.random(80..120),
          competition: Enum.random(1..10),
          growth_rate: Enum.random(-5..15) / 100
        }
      
      :technology ->
        %{
          innovation_index: Enum.random(60..100),
          disruption_risk: Enum.random(1..10) / 10,
          adoption_rate: Enum.random(5..30) / 100
        }
      
      :regulatory ->
        %{
          compliance_changes: Enum.random(0..5),
          risk_level: Enum.random(1..5),
          deadline_pressure: Enum.random(1..10)
        }
      
      _ ->
        %{
          generic_metric: Enum.random(1..100)
        }
    end
  end

  defp detect_signals(source) do
    # Simulate signal detection
    if Enum.random(1..10) > 7 do
      [
        %{
          type: :opportunity,
          strength: Enum.random(1..10) / 10,
          description: "Potential opportunity in #{source.category}"
        }
      ]
    else
      []
    end
  end

  defp detect_anomalies(source) do
    # Simulate anomaly detection
    if Enum.random(1..10) > 8 do
      [
        %{
          severity: Enum.random([:low, :medium, :high]),
          metric: "#{source.type}_metric",
          deviation: Enum.random(10..50) / 100
        }
      ]
    else
      []
    end
  end

  defp analyze_data_trends(data) do
    # Simple trend analysis
    data_points = Map.values(data)
    
    if length(data_points) < 2 do
      %{trend: :insufficient_data}
    else
      %{
        trend: calculate_trend_direction(data_points),
        volatility: calculate_volatility(data_points),
        projection: project_future(data_points),
        confidence: Enum.random(60..95) / 100
      }
    end
  end

  defp calculate_trend_direction(_data_points) do
    # Simplified trend calculation
    Enum.random([:rising, :falling, :stable, :volatile])
  end

  defp calculate_volatility(_data_points) do
    Enum.random(1..100) / 100
  end

  defp project_future(_data_points) do
    %{
      short_term: Enum.random([-10, -5, 0, 5, 10, 15]),
      medium_term: Enum.random([-20, -10, 0, 10, 20, 30]),
      confidence_interval: 0.8
    }
  end

  defp generate_prediction(parameters, state) do
    relevant_data = gather_relevant_data(parameters, state)
    
    %{
      id: generate_id(),
      parameters: parameters,
      prediction: make_prediction(parameters, relevant_data),
      confidence: calculate_confidence(relevant_data),
      generated_at: DateTime.utc_now(),
      basis: summarize_data_basis(relevant_data)
    }
  end

  defp gather_relevant_data(parameters, state) do
    %{
      environmental: Map.take(state.environmental_data, parameters[:relevant_sources] || []),
      trends: Map.take(state.trend_analysis, parameters[:trend_sources] || []),
      historical_predictions: Enum.take(state.predictions, 10)
    }
  end

  defp make_prediction(parameters, _data) do
    case parameters[:type] do
      :growth ->
        %{
          expected_value: Enum.random(90..110),
          range: {85, 115},
          timeline: "next_quarter"
        }
      
      :risk ->
        %{
          risk_score: Enum.random(1..10) / 10,
          mitigation_urgency: Enum.random([:low, :medium, :high]),
          impact_areas: ["operations", "finance"]
        }
      
      _ ->
        %{
          generic_prediction: Enum.random(1..100),
          uncertainty: :high
        }
    end
  end

  defp calculate_confidence(data) do
    base_confidence = 0.5
    data_bonus = min(0.4, map_size(data.environmental) * 0.1)
    trend_bonus = if map_size(data.trends) > 0, do: 0.1, else: 0
    
    base_confidence + data_bonus + trend_bonus
  end

  defp summarize_data_basis(data) do
    %{
      sources_used: map_size(data.environmental),
      trends_analyzed: map_size(data.trends),
      historical_context: length(data.historical_predictions)
    }
  end

  defp compile_intelligence_report(state) do
    %{
      summary: %{
        active_sources: map_size(state.intelligence_sources),
        data_points: map_size(state.environmental_data),
        trends_identified: map_size(state.trend_analysis),
        predictions_made: length(state.predictions),
        active_alerts: length(state.alerts)
      },
      latest_signals: extract_latest_signals(state.environmental_data),
      key_trends: extract_key_trends(state.trend_analysis),
      recent_predictions: Enum.take(state.predictions, 5),
      alert_status: check_alert_status(state.alerts)
    }
  end

  defp extract_latest_signals(environmental_data) do
    environmental_data
    |> Map.values()
    |> Enum.flat_map(& &1[:signals] || [])
    |> Enum.take(10)
  end

  defp extract_key_trends(trend_analysis) do
    trend_analysis
    |> Map.to_list()
    |> Enum.map(fn {source, analysis} ->
      %{source: source, trend: analysis[:trend], confidence: analysis[:confidence]}
    end)
    |> Enum.sort_by(& &1.confidence, :desc)
    |> Enum.take(5)
  end

  defp check_alert_status(alerts) do
    %{
      total: length(alerts),
      recent_triggers: 0  # Would check actual trigger history
    }
  end

  defp check_alerts(scan_results, alerts) do
    Enum.each(alerts, fn alert ->
      if evaluate_condition(alert.condition, scan_results) do
        alert.callback.(scan_results)
      end
    end)
  end

  defp evaluate_condition(_condition, _data) do
    # Simplified condition evaluation
    Enum.random([true, false])
  end

  defp default_sources do
    %{
      "market_monitor" => %{
        id: "market_monitor",
        type: :market,
        category: :external,
        priority: :high
      },
      "tech_radar" => %{
        id: "tech_radar",
        type: :technology,
        category: :external,
        priority: :medium
      },
      "regulatory_watch" => %{
        id: "regulatory_watch",
        type: :regulatory,
        category: :external,
        priority: :high
      }
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp get_last_scan_time(environmental_data) do
    if map_size(environmental_data) > 0 do
      environmental_data
      |> Map.values()
      |> Enum.map(& &1[:timestamp])
      |> Enum.filter(&(&1))
      |> Enum.max(DateTime, fn -> nil end)
    else
      nil
    end
  end

  defp calculate_data_freshness(environmental_data) do
    if map_size(environmental_data) == 0 do
      0.0
    else
      fresh_data_count = environmental_data
      |> Map.values()
      |> Enum.count(fn data ->
        timestamp = data[:timestamp]
        timestamp && DateTime.diff(DateTime.utc_now(), timestamp, :hour) < 1
      end)
      
      fresh_data_count / map_size(environmental_data)
    end
  end

  defp perform_environmental_analysis(scope, parameters, state) do
    # Gather relevant data based on scope
    relevant_data = filter_data_by_scope(state.environmental_data, scope)
    
    # Perform multi-dimensional analysis
    %{
      scope: scope,
      parameters: parameters,
      data_coverage: calculate_coverage(relevant_data, state.intelligence_sources),
      patterns_detected: detect_environmental_patterns(relevant_data),
      anomalies: aggregate_anomalies(relevant_data),
      opportunities: identify_opportunities(relevant_data, parameters),
      threats: identify_threats(relevant_data, parameters),
      recommendations: generate_environmental_recommendations(relevant_data, parameters),
      confidence_level: calculate_analysis_confidence(relevant_data),
      timestamp: DateTime.utc_now()
    }
  end

  defp update_analysis_insights(state, analysis_result) do
    insight = %{
      type: :environmental_analysis,
      scope: analysis_result.scope,
      key_findings: extract_key_findings(analysis_result),
      timestamp: analysis_result.timestamp
    }
    
    Map.update(state, :analysis_insights, [insight], fn insights ->
      [insight | Enum.take(insights, 99)]
    end)
  end

  defp filter_data_by_scope(environmental_data, scope) do
    case scope do
      :all -> environmental_data
      :recent -> filter_recent_data(environmental_data)
      scope_name when is_atom(scope_name) ->
        Map.filter(environmental_data, fn {key, _} ->
          String.contains?(to_string(key), to_string(scope_name))
        end)
      _ -> environmental_data
    end
  end

  defp filter_recent_data(environmental_data) do
    Map.filter(environmental_data, fn {_, data} ->
      timestamp = data[:timestamp]
      timestamp && DateTime.diff(DateTime.utc_now(), timestamp, :hour) < 24
    end)
  end

  defp calculate_coverage(relevant_data, intelligence_sources) do
    covered_sources = relevant_data
    |> Map.keys()
    |> MapSet.new()
    
    all_sources = intelligence_sources
    |> Map.keys()
    |> MapSet.new()
    
    if MapSet.size(all_sources) > 0 do
      MapSet.size(MapSet.intersection(covered_sources, all_sources)) / MapSet.size(all_sources)
    else
      0.0
    end
  end

  defp detect_environmental_patterns(data) do
    # Analyze data for patterns
    metrics_over_time = extract_metrics_over_time(data)
    
    patterns = []
    
    patterns = if trending_up?(metrics_over_time) do
      [%{type: :growth, strength: 0.8, metrics: [:demand, :adoption]} | patterns]
    else
      patterns
    end
    
    patterns = if high_volatility?(metrics_over_time) do
      [%{type: :volatility, strength: 0.7, areas: [:market, :technology]} | patterns]
    else
      patterns
    end
    
    patterns = if convergence_detected?(data) do
      [%{type: :convergence, strength: 0.6, domains: [:regulation, :technology]} | patterns]
    else
      patterns
    end
    
    patterns
  end

  defp aggregate_anomalies(data) do
    data
    |> Map.values()
    |> Enum.flat_map(& &1[:anomalies] || [])
    |> Enum.group_by(& &1.severity)
    |> Map.new(fn {severity, anomalies} ->
      {severity, %{count: length(anomalies), examples: Enum.take(anomalies, 3)}}
    end)
  end

  defp identify_opportunities(data, parameters) do
    base_opportunities = data
    |> Map.values()
    |> Enum.flat_map(& &1[:signals] || [])
    |> Enum.filter(& &1.type == :opportunity)
    
    # Filter based on parameters
    filtered = if parameters[:min_strength] do
      Enum.filter(base_opportunities, & &1.strength >= parameters.min_strength)
    else
      base_opportunities
    end
    
    # Rank and return top opportunities
    filtered
    |> Enum.sort_by(& &1.strength, :desc)
    |> Enum.take(5)
  end

  defp identify_threats(data, _parameters) do
    # Identify potential threats from environmental data
    threats = []
    
    # Check for high-severity anomalies
    severe_anomalies = data
    |> Map.values()
    |> Enum.flat_map(& &1[:anomalies] || [])
    |> Enum.filter(& &1.severity == :high)
    
    threats = if length(severe_anomalies) > 0 do
      [%{type: :anomaly_cluster, severity: :high, count: length(severe_anomalies)} | threats]
    else
      threats
    end
    
    # Check for negative trends
    threats = if declining_metrics?(data) do
      [%{type: :declining_performance, severity: :medium, affected_areas: [:market_share]} | threats]
    else
      threats
    end
    
    threats
  end

  defp generate_environmental_recommendations(data, _parameters) do
    recommendations = []
    
    # Based on data coverage
    coverage = map_size(data)
    recommendations = if coverage < 5 do
      ["Expand environmental monitoring to more sources" | recommendations]
    else
      recommendations
    end
    
    # Based on data freshness
    fresh_ratio = calculate_data_freshness(data)
    recommendations = if fresh_ratio < 0.7 do
      ["Increase scan frequency for better real-time awareness" | recommendations]
    else
      recommendations
    end
    
    # Based on detected patterns
    recommendations = if has_high_volatility_patterns?(data) do
      ["Implement adaptive strategies for volatile environment" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end

  defp calculate_analysis_confidence(data) do
    factors = [
      map_size(data) / 10,  # Data volume factor
      calculate_data_freshness(data),  # Freshness factor
      assess_data_quality(data),  # Quality factor
      0.7  # Base confidence
    ]
    
    Enum.sum(factors) / length(factors) |> min(1.0)
  end

  defp extract_key_findings(analysis_result) do
    findings = []
    
    findings = if length(analysis_result.patterns_detected) > 0 do
      ["#{length(analysis_result.patterns_detected)} significant patterns detected" | findings]
    else
      findings
    end
    
    findings = if length(analysis_result.opportunities) > 0 do
      ["#{length(analysis_result.opportunities)} opportunities identified" | findings]
    else
      findings
    end
    
    findings = if length(analysis_result.threats) > 0 do
      ["#{length(analysis_result.threats)} potential threats require attention" | findings]
    else
      findings
    end
    
    findings
  end

  defp extract_metrics_over_time(data) do
    # Simplified extraction - in reality would parse time series
    data
    |> Map.values()
    |> Enum.map(& &1[:metrics])
    |> Enum.filter(&(&1))
  end

  defp trending_up?(_metrics), do: Enum.random([true, false])
  defp high_volatility?(_metrics), do: Enum.random([true, false])
  defp convergence_detected?(_data), do: Enum.random([true, false])
  defp declining_metrics?(_data), do: Enum.random([true, false])
  defp has_high_volatility_patterns?(_data), do: Enum.random([true, false])

  defp assess_data_quality(data) do
    if map_size(data) == 0 do
      0.0
    else
      # Check for completeness of data fields
      complete_entries = Enum.count(data, fn {_, entry} ->
        Map.has_key?(entry, :timestamp) && 
        Map.has_key?(entry, :metrics) &&
        Map.has_key?(entry, :signals)
      end)
      
      complete_entries / map_size(data)
    end
  end
  
  defp extract_opportunities_and_threats(environmental_data) do
    # Extract opportunities and threats from environmental data
    opportunities = []
    threats = []
    
    # Analyze environmental data for opportunities and threats
    Enum.each(environmental_data, fn {_source, data} ->
      case data do
        %{type: :opportunity} -> [data | opportunities]
        %{type: :threat} -> [data | threats]
        _ -> {opportunities, threats}
      end
    end)
    
    # For now, return empty lists as we haven't categorized the data
    {opportunities, threats}
  end
end