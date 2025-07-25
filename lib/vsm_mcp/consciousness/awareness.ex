defmodule VsmMcp.ConsciousnessInterface.Awareness do
  @moduledoc """
  Awareness monitoring for the consciousness interface.
  
  Tracks real-time awareness of system state, environmental
  conditions, and internal processes.
  """
  
  use GenServer
  require Logger
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_current_state(server \\ __MODULE__) do
    GenServer.call(server, :get_current_state)
  end
  
  def introspect(server \\ __MODULE__) do
    GenServer.call(server, :introspect)
  end
  
  def notify_change(server \\ __MODULE__, change_type, details) do
    GenServer.cast(server, {:notify_change, change_type, details})
  end
  
  def set_focus(server \\ __MODULE__, focus_area) do
    GenServer.call(server, {:set_focus, focus_area})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      current_awareness: %{
        attention_level: 0.8,
        focus_areas: [:variety_monitoring, :system_health],
        environmental_scan: %{},
        internal_state: %{}
      },
      awareness_history: [],
      attention_metrics: %{
        sustained_attention: 0.75,
        selective_attention: 0.8,
        divided_attention: 0.6
      },
      change_notifications: [],
      focus_stack: []
    }
    
    # Schedule periodic awareness updates
    schedule_awareness_update()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:get_current_state, _from, state) do
    {:reply, state.current_awareness, state}
  end
  
  @impl true
  def handle_call(:introspect, _from, state) do
    introspection = perform_introspection(state)
    
    # Update awareness history
    awareness_entry = %{
      introspection: introspection,
      timestamp: DateTime.utc_now(),
      attention_level: state.current_awareness.attention_level
    }
    
    new_state = Map.update!(state, :awareness_history, &[awareness_entry | Enum.take(&1, 99)])
    
    {:reply, introspection, new_state}
  end
  
  @impl true
  def handle_call({:set_focus, focus_area}, _from, state) do
    new_focus = [focus_area | state.current_awareness.focus_areas] |> Enum.uniq() |> Enum.take(5)
    
    new_awareness = Map.put(state.current_awareness, :focus_areas, new_focus)
    new_state = Map.put(state, :current_awareness, new_awareness)
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_cast({:notify_change, change_type, details}, state) do
    notification = %{
      type: change_type,
      details: details,
      timestamp: DateTime.utc_now(),
      attention_impact: calculate_attention_impact(change_type)
    }
    
    new_state = state
    |> Map.update!(:change_notifications, &[notification | Enum.take(&1, 49)])
    |> adjust_attention_based_on_change(notification)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:update_awareness, state) do
    new_state = update_environmental_scan(state)
    |> update_internal_state()
    |> adjust_attention_levels()
    
    # Schedule next update
    schedule_awareness_update()
    
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp perform_introspection(state) do
    %{
      current_focus: state.current_awareness.focus_areas,
      attention_level: state.current_awareness.attention_level,
      recent_changes: Enum.take(state.change_notifications, 5),
      environmental_awareness: assess_environmental_awareness(state),
      internal_awareness: assess_internal_awareness(state),
      metacognitive_awareness: assess_metacognitive_awareness(state)
    }
  end
  
  defp assess_environmental_awareness(state) do
    %{
      external_conditions: state.current_awareness.environmental_scan,
      change_detection: length(state.change_notifications),
      adaptation_readiness: calculate_adaptation_readiness(state)
    }
  end
  
  defp assess_internal_awareness(state) do
    %{
      system_state: state.current_awareness.internal_state,
      cognitive_load: estimate_cognitive_load(state),
      resource_awareness: assess_resource_awareness()
    }
  end
  
  defp assess_metacognitive_awareness(state) do
    %{
      awareness_of_awareness: state.current_awareness.attention_level,
      self_monitoring: calculate_self_monitoring_level(state),
      meta_attention: state.attention_metrics.selective_attention
    }
  end
  
  defp calculate_attention_impact(change_type) do
    case change_type do
      :critical_system_change -> 0.9
      :variety_gap_detected -> 0.8
      :mcp_server_integrated -> 0.6
      :self_model_updated -> 0.4
      :routine_operation -> 0.2
      _ -> 0.3
    end
  end
  
  defp adjust_attention_based_on_change(state, notification) do
    impact = notification.attention_impact
    current_level = state.current_awareness.attention_level
    
    # Adjust attention level based on change impact
    new_attention = min(current_level + (impact * 0.1), 1.0)
    
    new_awareness = Map.put(state.current_awareness, :attention_level, new_attention)
    Map.put(state, :current_awareness, new_awareness)
  end
  
  defp update_environmental_scan(state) do
    # Simulate environmental scanning
    scan_results = %{
      system_load: :erlang.system_info(:process_count) / 1000.0,
      memory_usage: get_memory_usage(),
      active_processes: length(:erlang.processes()),
      network_activity: :low,  # Simplified
      timestamp: DateTime.utc_now()
    }
    
    new_awareness = Map.put(state.current_awareness, :environmental_scan, scan_results)
    Map.put(state, :current_awareness, new_awareness)
  end
  
  defp update_internal_state(state) do
    # Update internal state awareness
    internal_state = %{
      cognitive_processes: count_active_cognitive_processes(),
      decision_queue: 0,  # Simplified
      learning_active: true,
      consciousness_level: state.current_awareness.attention_level
    }
    
    new_awareness = Map.put(state.current_awareness, :internal_state, internal_state)
    Map.put(state, :current_awareness, new_awareness)
  end
  
  defp adjust_attention_levels(state) do
    # Adjust attention based on recent activity
    recent_activity = length(state.change_notifications)
    
    # Calculate new attention metrics
    new_metrics = %{
      sustained_attention: calculate_sustained_attention(state),
      selective_attention: calculate_selective_attention(state),
      divided_attention: calculate_divided_attention(recent_activity)
    }
    
    Map.put(state, :attention_metrics, new_metrics)
  end
  
  defp calculate_adaptation_readiness(state) do
    # Calculate how ready the system is to adapt to changes
    recent_changes = length(state.change_notifications)
    attention_level = state.current_awareness.attention_level
    
    # More changes and higher attention = higher readiness
    min((recent_changes * 0.1) + attention_level, 1.0)
  end
  
  defp estimate_cognitive_load(state) do
    # Estimate current cognitive load
    process_count = length(:erlang.processes())
    attention_level = state.current_awareness.attention_level
    recent_changes = length(state.change_notifications)
    
    # Normalize to 0-1 scale
    base_load = min(process_count / 1000.0, 0.5)
    attention_load = attention_level * 0.3
    change_load = min(recent_changes * 0.02, 0.2)
    
    base_load + attention_load + change_load
  end
  
  defp assess_resource_awareness do
    # Assess awareness of computational resources
    memory = :erlang.memory()
    %{
      total_memory: memory[:total],
      process_memory: memory[:processes],
      memory_utilization: memory[:processes] / memory[:total],
      cpu_awareness: :moderate  # Simplified
    }
  end
  
  defp calculate_self_monitoring_level(state) do
    # Calculate how well the system monitors itself
    history_depth = length(state.awareness_history)
    change_tracking = length(state.change_notifications)
    
    # Normalize to 0-1 scale
    min((history_depth * 0.01) + (change_tracking * 0.02), 1.0)
  end
  
  defp get_memory_usage do
    memory = :erlang.memory()
    memory[:total] / (1024 * 1024)  # Convert to MB
  end
  
  defp count_active_cognitive_processes do
    # Count processes that might be doing cognitive work
    :erlang.processes()
    |> Enum.count(fn pid ->
      case :erlang.process_info(pid, :current_function) do
        {:current_function, {mod, _fun, _arity}} ->
          mod_name = Atom.to_string(mod)
          String.contains?(mod_name, ["VsmMcp", "Consciousness", "Decision"])
        _ ->
          false
      end
    end)
  end
  
  defp calculate_sustained_attention(state) do
    # Calculate sustained attention based on history
    if length(state.awareness_history) > 0 do
      recent_attention = state.awareness_history
      |> Enum.take(10)
      |> Enum.map(& &1.attention_level)
      |> Enum.sum()
      |> Kernel./(min(length(state.awareness_history), 10))
      
      recent_attention
    else
      0.75  # Default
    end
  end
  
  defp calculate_selective_attention(state) do
    # Calculate selective attention based on focus areas
    focus_count = length(state.current_awareness.focus_areas)
    
    # Fewer focus areas = better selective attention
    max(1.0 - (focus_count * 0.1), 0.3)
  end
  
  defp calculate_divided_attention(recent_activity) do
    # Calculate divided attention based on multitasking
    if recent_activity > 5 do
      max(0.8 - (recent_activity * 0.05), 0.3)
    else
      0.8
    end
  end
  
  defp schedule_awareness_update do
    Process.send_after(self(), :update_awareness, 5_000)  # Every 5 seconds
  end
end