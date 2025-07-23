defmodule VsmMcp.ConsciousnessInterface.Awareness do
  @moduledoc """
  Awareness Module - Real-time monitoring of internal states
  
  This module provides continuous awareness of:
  - System resource utilization
  - Process states and health
  - Performance anomalies
  - Emergent patterns
  - Internal conflicts or contradictions
  - Attention allocation
  
  True awareness through active monitoring, not passive logging.
  """
  
  use GenServer
  require Logger
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def get_current_state(pid) do
    GenServer.call(pid, :current_state)
  end
  
  def introspect(pid) do
    GenServer.call(pid, :introspect)
  end
  
  def notify_change(pid, change_type, details) do
    GenServer.cast(pid, {:notify_change, change_type, details})
  end
  
  def focus_attention(pid, target) do
    GenServer.call(pid, {:focus_attention, target})
  end
  
  def get_attention_distribution(pid) do
    GenServer.call(pid, :attention_distribution)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      # Core awareness components
      resource_awareness: initialize_resource_monitoring(),
      process_awareness: initialize_process_monitoring(),
      pattern_awareness: initialize_pattern_detection(),
      anomaly_awareness: initialize_anomaly_detection(),
      
      # Attention mechanism
      attention: %{
        focus: nil,
        distribution: %{},
        priority_queue: :queue.new(),
        attention_span: 5000  # milliseconds
      },
      
      # State tracking
      internal_state: %{
        coherence: 1.0,
        stability: 1.0,
        load: 0.0,
        stress: 0.0
      },
      
      # Historical awareness
      state_history: [],
      significant_events: [],
      
      # Meta-awareness
      awareness_level: 0.7,
      blind_spots: []
    }
    
    # Start monitoring processes
    {:ok, _} = Task.start_link(fn -> monitor_resources(self()) end)
    {:ok, _} = Task.start_link(fn -> monitor_patterns(self()) end)
    
    # Schedule periodic introspection
    Process.send_after(self(), :periodic_introspection, 10_000)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:current_state, _from, state) do
    current = compile_current_awareness(state)
    {:reply, current, state}
  end
  
  @impl true
  def handle_call(:introspect, _from, state) do
    introspection = perform_deep_introspection(state)
    
    # Update awareness level based on introspection
    new_awareness_level = calculate_awareness_level(introspection)
    new_state = Map.put(state, :awareness_level, new_awareness_level)
    
    {:reply, introspection, new_state}
  end
  
  @impl true
  def handle_call({:focus_attention, target}, _from, state) do
    # Shift attention focus
    new_attention = shift_attention_focus(state.attention, target)
    new_state = Map.put(state, :attention, new_attention)
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:attention_distribution, _from, state) do
    distribution = calculate_attention_distribution(state.attention)
    {:reply, distribution, state}
  end
  
  @impl true
  def handle_cast({:notify_change, change_type, details}, state) do
    # Process change notification
    new_state = process_change_notification(state, change_type, details)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:resource_update, resource_data}, state) do
    # Update resource awareness
    new_resource_awareness = update_resource_awareness(
      state.resource_awareness,
      resource_data
    )
    
    # Check for resource stress
    stress_level = calculate_resource_stress(new_resource_awareness)
    
    new_internal_state = Map.put(state.internal_state, :stress, stress_level)
    
    new_state = state
    |> Map.put(:resource_awareness, new_resource_awareness)
    |> Map.put(:internal_state, new_internal_state)
    |> check_for_anomalies(resource_data)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:pattern_detected, pattern}, state) do
    # Process detected pattern
    new_state = process_detected_pattern(state, pattern)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:periodic_introspection, state) do
    # Perform periodic self-check
    introspection = perform_quick_introspection(state)
    
    # Update state history
    history_entry = %{
      snapshot: introspection,
      timestamp: DateTime.utc_now()
    }
    
    new_history = [history_entry | state.state_history] |> Enum.take(100)
    
    # Detect significant changes
    new_state = state
    |> Map.put(:state_history, new_history)
    |> detect_significant_changes(introspection)
    
    # Schedule next introspection
    Process.send_after(self(), :periodic_introspection, 10_000)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:attention_timeout, target}, state) do
    # Handle attention timeout
    new_attention = release_attention_focus(state.attention, target)
    new_state = Map.put(state, :attention, new_attention)
    
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp initialize_resource_monitoring do
    %{
      memory: %{
        total: get_total_memory(),
        used: 0,
        available: 0,
        pressure: 0.0
      },
      cpu: %{
        usage: 0.0,
        load_average: [0.0, 0.0, 0.0],
        process_count: 0
      },
      io: %{
        disk_usage: 0.0,
        network_usage: 0.0,
        pending_operations: 0
      },
      processes: %{
        total: 0,
        active: 0,
        waiting: 0,
        monitored: []
      }
    }
  end
  
  defp initialize_process_monitoring do
    %{
      vsm_systems: %{
        system1: :unknown,
        system2: :unknown,
        system3: :unknown,
        system4: :unknown,
        system5: :unknown
      },
      consciousness_components: %{
        meta_cognition: :unknown,
        self_model: :unknown,
        decision_tracing: :unknown,
        learning: :unknown,
        meta_reasoning: :unknown
      },
      health_indicators: %{
        response_times: [],
        error_rates: %{},
        throughput: []
      }
    }
  end
  
  defp initialize_pattern_detection do
    %{
      behavioral_patterns: %{},
      temporal_patterns: %{},
      interaction_patterns: %{},
      emergent_patterns: [],
      pattern_strength: %{}
    }
  end
  
  defp initialize_anomaly_detection do
    %{
      thresholds: %{
        memory_usage: 0.8,
        cpu_usage: 0.9,
        response_time: 1000,  # ms
        error_rate: 0.05
      },
      anomaly_history: [],
      current_anomalies: [],
      anomaly_patterns: %{}
    }
  end
  
  defp monitor_resources(awareness_pid) do
    # Continuous resource monitoring loop
    resource_data = collect_resource_data()
    send(awareness_pid, {:resource_update, resource_data})
    
    Process.sleep(1000)
    monitor_resources(awareness_pid)
  end
  
  defp monitor_patterns(awareness_pid) do
    # Pattern detection loop
    Process.sleep(5000)
    
    # This would analyze system behavior for patterns
    # For now, simplified simulation
    if :rand.uniform() < 0.1 do
      pattern = %{
        type: Enum.random([:behavioral, :temporal, :interaction]),
        description: "Pattern detected in system behavior",
        strength: :rand.uniform()
      }
      send(awareness_pid, {:pattern_detected, pattern})
    end
    
    monitor_patterns(awareness_pid)
  end
  
  defp collect_resource_data do
    memory_info = :erlang.memory()
    
    %{
      memory: %{
        total: memory_info[:total],
        used: memory_info[:processes] + memory_info[:system],
        ets: memory_info[:ets],
        binary: memory_info[:binary]
      },
      processes: %{
        count: :erlang.system_info(:process_count),
        limit: :erlang.system_info(:process_limit)
      },
      schedulers: %{
        online: :erlang.system_info(:schedulers_online),
        active: :erlang.statistics(:scheduler_wall_time)
      },
      timestamp: System.monotonic_time(:millisecond)
    }
  end
  
  defp compile_current_awareness(state) do
    %{
      # Resource state
      resources: summarize_resource_state(state.resource_awareness),
      
      # Process health
      processes: summarize_process_health(state.process_awareness),
      
      # Detected patterns
      active_patterns: get_active_patterns(state.pattern_awareness),
      
      # Current anomalies
      anomalies: state.anomaly_awareness.current_anomalies,
      
      # Internal state
      internal_state: state.internal_state,
      
      # Attention focus
      attention_focus: state.attention.focus,
      
      # Overall awareness
      awareness_level: state.awareness_level,
      
      # Blind spots
      known_blind_spots: state.blind_spots
    }
  end
  
  defp perform_deep_introspection(state) do
    %{
      # System coherence
      coherence: analyze_system_coherence(state),
      
      # Internal conflicts
      conflicts: detect_internal_conflicts(state),
      
      # Resource utilization patterns
      resource_patterns: analyze_resource_patterns(state),
      
      # Process coordination
      coordination_quality: assess_coordination_quality(state),
      
      # Emergent behaviors
      emergent_behaviors: identify_emergent_behaviors(state),
      
      # Attention effectiveness
      attention_analysis: analyze_attention_effectiveness(state),
      
      # Self-assessment
      self_assessment: perform_self_assessment(state)
    }
  end
  
  defp perform_quick_introspection(state) do
    %{
      resource_pressure: calculate_resource_pressure(state.resource_awareness),
      process_health: calculate_overall_process_health(state.process_awareness),
      anomaly_count: length(state.anomaly_awareness.current_anomalies),
      coherence: state.internal_state.coherence,
      attention_scattered: is_attention_scattered?(state.attention)
    }
  end
  
  defp shift_attention_focus(attention, target) do
    # Cancel previous attention timeout
    if attention.focus do
      Process.cancel_timer(attention.focus.timer_ref)
    end
    
    # Set new focus with timeout
    timer_ref = Process.send_after(self(), {:attention_timeout, target}, attention.attention_span)
    
    new_focus = %{
      target: target,
      started_at: DateTime.utc_now(),
      timer_ref: timer_ref
    }
    
    # Update attention distribution
    new_distribution = Map.update(attention.distribution, target, 1, &(&1 + 1))
    
    attention
    |> Map.put(:focus, new_focus)
    |> Map.put(:distribution, new_distribution)
  end
  
  defp release_attention_focus(attention, target) do
    if attention.focus && attention.focus.target == target do
      Map.put(attention, :focus, nil)
    else
      attention
    end
  end
  
  defp calculate_attention_distribution(attention) do
    total = attention.distribution
    |> Map.values()
    |> Enum.sum()
    
    if total > 0 do
      Map.new(attention.distribution, fn {target, count} ->
        {target, count / total}
      end)
    else
      %{}
    end
  end
  
  defp process_change_notification(state, change_type, details) do
    # Update relevant awareness based on change
    case change_type do
      :self_model_updated ->
        update_blind_spots(state, details)
        
      :decision_made ->
        track_decision_impact(state, details)
        
      :learning_occurred ->
        update_pattern_awareness(state, details)
        
      _ ->
        state
    end
  end
  
  defp update_resource_awareness(resource_awareness, resource_data) do
    %{resource_awareness |
      memory: %{
        total: resource_data.memory.total,
        used: resource_data.memory.used,
        available: resource_data.memory.total - resource_data.memory.used,
        pressure: resource_data.memory.used / resource_data.memory.total
      },
      processes: %{
        total: resource_data.processes.count,
        active: estimate_active_processes(resource_data),
        waiting: estimate_waiting_processes(resource_data),
        monitored: []
      }
    }
  end
  
  defp calculate_resource_stress(resource_awareness) do
    factors = [
      resource_awareness.memory.pressure,
      min(resource_awareness.cpu.usage, 1.0),
      calculate_process_pressure(resource_awareness.processes)
    ]
    
    Enum.sum(factors) / length(factors)
  end
  
  defp check_for_anomalies(state, resource_data) do
    anomalies = detect_resource_anomalies(
      resource_data,
      state.anomaly_awareness.thresholds
    )
    
    if Enum.any?(anomalies) do
      new_anomaly_awareness = update_anomaly_awareness(
        state.anomaly_awareness,
        anomalies
      )
      
      # Record significant event if severe anomaly
      new_state = if Enum.any?(anomalies, & &1.severity == :high) do
        record_significant_event(state, :severe_anomaly, anomalies)
      else
        state
      end
      
      Map.put(new_state, :anomaly_awareness, new_anomaly_awareness)
    else
      state
    end
  end
  
  defp process_detected_pattern(state, pattern) do
    # Update pattern awareness
    new_pattern_awareness = add_detected_pattern(state.pattern_awareness, pattern)
    
    # Check if pattern is significant
    new_state = if pattern.strength > 0.7 do
      record_significant_event(state, :strong_pattern, pattern)
    else
      state
    end
    
    Map.put(new_state, :pattern_awareness, new_pattern_awareness)
  end
  
  defp detect_significant_changes(state, introspection) do
    if length(state.state_history) > 1 do
      previous = hd(state.state_history).snapshot
      
      changes = compare_snapshots(previous, introspection)
      
      if changes.magnitude > 0.3 do
        record_significant_event(state, :state_change, changes)
      else
        state
      end
    else
      state
    end
  end
  
  defp record_significant_event(state, event_type, details) do
    event = %{
      type: event_type,
      details: details,
      timestamp: DateTime.utc_now(),
      awareness_level: state.awareness_level
    }
    
    Map.update!(state, :significant_events, &[event | &1])
  end
  
  defp calculate_awareness_level(introspection) do
    factors = [
      introspection.coherence.score,
      1.0 - (length(introspection.conflicts) / 10),
      introspection.coordination_quality,
      introspection.attention_analysis.effectiveness
    ]
    
    Enum.sum(factors) / length(factors)
  end
  
  # Analysis functions
  
  defp analyze_system_coherence(state) do
    %{
      score: state.internal_state.coherence,
      inconsistencies: detect_inconsistencies(state),
      alignment: check_component_alignment(state),
      integration_quality: assess_integration_quality(state)
    }
  end
  
  defp detect_internal_conflicts(state) do
    conflicts = []
    
    # Check for resource conflicts
    conflicts = if state.resource_awareness.memory.pressure > 0.8 &&
                   state.attention.focus != :resource_management do
      [%{type: :resource_attention_mismatch, severity: :medium} | conflicts]
    else
      conflicts
    end
    
    # Check for goal conflicts
    conflicts = if length(state.anomaly_awareness.current_anomalies) > 3 &&
                   state.internal_state.stability > 0.8 do
      [%{type: :stability_anomaly_contradiction, severity: :high} | conflicts]
    else
      conflicts
    end
    
    conflicts
  end
  
  defp analyze_resource_patterns(state) do
    %{
      usage_trend: calculate_usage_trend(state.state_history),
      allocation_efficiency: calculate_allocation_efficiency(state),
      bottlenecks: identify_resource_bottlenecks(state)
    }
  end
  
  defp assess_coordination_quality(state) do
    # Assess how well components are coordinating
    if all_systems_known?(state.process_awareness.vsm_systems) do
      0.8  # Good coordination if all systems are known
    else
      0.5  # Reduced coordination with unknown systems
    end
  end
  
  defp identify_emergent_behaviors(state) do
    state.pattern_awareness.emergent_patterns
    |> Enum.filter(& &1.confirmed)
    |> Enum.map(& &1.description)
  end
  
  defp analyze_attention_effectiveness(state) do
    %{
      focus_duration: calculate_average_focus_duration(state),
      switch_frequency: calculate_attention_switches(state),
      coverage: calculate_attention_coverage(state),
      effectiveness: calculate_attention_effectiveness_score(state)
    }
  end
  
  defp perform_self_assessment(state) do
    %{
      strengths: [
        "Continuous resource monitoring",
        "Pattern detection capabilities",
        "Anomaly awareness"
      ],
      weaknesses: identify_awareness_weaknesses(state),
      improvement_areas: suggest_awareness_improvements(state)
    }
  end
  
  # Helper functions
  
  defp get_total_memory do
    :erlang.memory(:total)
  end
  
  defp estimate_active_processes(resource_data) do
    # Estimate based on scheduler activity
    round(resource_data.processes.count * 0.3)
  end
  
  defp estimate_waiting_processes(resource_data) do
    # Estimate waiting processes
    round(resource_data.processes.count * 0.1)
  end
  
  defp calculate_process_pressure(processes) do
    if processes.total > 0 do
      processes.active / processes.total
    else
      0.0
    end
  end
  
  defp summarize_resource_state(resource_awareness) do
    %{
      memory_pressure: resource_awareness.memory.pressure,
      cpu_load: resource_awareness.cpu.usage,
      process_count: resource_awareness.processes.total,
      overall_load: calculate_overall_load(resource_awareness)
    }
  end
  
  defp summarize_process_health(process_awareness) do
    %{
      vsm_systems: process_awareness.vsm_systems,
      consciousness_health: assess_consciousness_health(process_awareness),
      recent_errors: Map.get(process_awareness.health_indicators.error_rates, :recent, 0)
    }
  end
  
  defp get_active_patterns(pattern_awareness) do
    pattern_awareness.pattern_strength
    |> Enum.filter(fn {_, strength} -> strength > 0.5 end)
    |> Enum.map(&elem(&1, 0))
  end
  
  defp detect_resource_anomalies(resource_data, thresholds) do
    anomalies = []
    
    memory_usage = resource_data.memory.used / resource_data.memory.total
    anomalies = if memory_usage > thresholds.memory_usage do
      [%{type: :high_memory_usage, value: memory_usage, severity: :medium} | anomalies]
    else
      anomalies
    end
    
    anomalies
  end
  
  defp update_anomaly_awareness(anomaly_awareness, new_anomalies) do
    %{anomaly_awareness |
      current_anomalies: new_anomalies,
      anomaly_history: (new_anomalies ++ anomaly_awareness.anomaly_history) |> Enum.take(100)
    }
  end
  
  defp add_detected_pattern(pattern_awareness, pattern) do
    pattern_key = {pattern.type, pattern.description}
    
    new_strength = Map.update(
      pattern_awareness.pattern_strength,
      pattern_key,
      pattern.strength,
      &((&1 + pattern.strength) / 2)
    )
    
    %{pattern_awareness | pattern_strength: new_strength}
  end
  
  defp compare_snapshots(previous, current) do
    %{
      magnitude: abs(current.resource_pressure - previous.resource_pressure) +
                 abs(current.coherence - previous.coherence),
      details: %{
        resource_change: current.resource_pressure - previous.resource_pressure,
        coherence_change: current.coherence - previous.coherence,
        anomaly_change: current.anomaly_count - previous.anomaly_count
      }
    }
  end
  
  defp detect_inconsistencies(state) do
    # Detect logical inconsistencies in state
    []
  end
  
  defp check_component_alignment(state) do
    # Check if components are aligned
    all_systems_known?(state.process_awareness.vsm_systems)
  end
  
  defp assess_integration_quality(state) do
    # Assess how well integrated the consciousness components are
    known_components = state.process_awareness.consciousness_components
    |> Map.values()
    |> Enum.count(& &1 != :unknown)
    
    known_components / map_size(state.process_awareness.consciousness_components)
  end
  
  defp all_systems_known?(vsm_systems) do
    Enum.all?(Map.values(vsm_systems), & &1 != :unknown)
  end
  
  defp calculate_usage_trend(history) do
    if length(history) < 2 do
      :stable
    else
      recent = Enum.take(history, 5)
      pressures = Enum.map(recent, & &1.snapshot.resource_pressure)
      
      if increasing_trend?(pressures), do: :increasing, else: :stable
    end
  end
  
  defp increasing_trend?(values) do
    if length(values) < 2 do
      false
    else
      [first | rest] = Enum.reverse(values)
      last = List.last(values)
      last > first * 1.1
    end
  end
  
  defp calculate_allocation_efficiency(state) do
    # Calculate how efficiently resources are allocated
    0.7  # Placeholder
  end
  
  defp identify_resource_bottlenecks(state) do
    bottlenecks = []
    
    bottlenecks = if state.resource_awareness.memory.pressure > 0.7 do
      [:memory | bottlenecks]
    else
      bottlenecks
    end
    
    bottlenecks
  end
  
  defp calculate_average_focus_duration(state) do
    # Calculate average attention focus duration
    5000  # Default attention span
  end
  
  defp calculate_attention_switches(state) do
    # Calculate how often attention switches
    Map.values(state.attention.distribution) |> Enum.sum()
  end
  
  defp calculate_attention_coverage(state) do
    # Calculate what percentage of important areas get attention
    covered = MapSet.size(MapSet.new(Map.keys(state.attention.distribution)))
    important_areas = 10  # Number of important areas to monitor
    
    min(covered / important_areas, 1.0)
  end
  
  defp calculate_attention_effectiveness_score(state) do
    # Score attention effectiveness
    coverage = calculate_attention_coverage(state)
    scatter = if is_attention_scattered?(state.attention), do: 0.5, else: 1.0
    
    (coverage + scatter) / 2
  end
  
  defp is_attention_scattered?(attention) do
    # Check if attention is too scattered
    unique_targets = MapSet.size(MapSet.new(Map.keys(attention.distribution)))
    unique_targets > 5
  end
  
  defp calculate_overall_load(resource_awareness) do
    (resource_awareness.memory.pressure + resource_awareness.cpu.usage) / 2
  end
  
  defp assess_consciousness_health(process_awareness) do
    known_components = process_awareness.consciousness_components
    |> Map.values()
    |> Enum.count(& &1 == :active)
    
    if known_components >= 4, do: :healthy, else: :degraded
  end
  
  defp update_blind_spots(state, details) do
    # Update known blind spots based on self-model updates
    state
  end
  
  defp track_decision_impact(state, details) do
    # Track impact of decisions on system state
    state
  end
  
  defp update_pattern_awareness(state, details) do
    # Update patterns based on learning
    state
  end
  
  defp identify_awareness_weaknesses(state) do
    weaknesses = []
    
    weaknesses = if length(state.blind_spots) > 3 do
      ["Multiple blind spots detected" | weaknesses]
    else
      weaknesses
    end
    
    weaknesses = if state.awareness_level < 0.5 do
      ["Low overall awareness level" | weaknesses]
    else
      weaknesses
    end
    
    weaknesses
  end
  
  defp suggest_awareness_improvements(state) do
    improvements = []
    
    improvements = if is_attention_scattered?(state.attention) do
      ["Focus attention on fewer critical areas" | improvements]
    else
      improvements
    end
    
    improvements = if state.resource_awareness.memory.pressure > 0.7 do
      ["Implement memory optimization strategies" | improvements]
    else
      improvements
    end
    
    improvements
  end
  
  defp calculate_resource_pressure(resource_awareness) do
    resource_awareness.memory.pressure
  end
  
  defp calculate_overall_process_health(process_awareness) do
    # Simple health calculation
    case assess_consciousness_health(process_awareness) do
      :healthy -> 1.0
      :degraded -> 0.6
      _ -> 0.3
    end
  end
end