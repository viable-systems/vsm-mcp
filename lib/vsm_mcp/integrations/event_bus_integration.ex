defmodule VsmMcp.Integrations.EventBusIntegration do
  @moduledoc """
  Integration module for VSM Event Bus.
  
  Provides event-driven communication between VSM systems and external components.
  """
  use GenServer
  require Logger
  
  @pubsub VsmMcp.PubSub
  
  # Event topics
  @system1_topic "vsm:system1:operations"
  @system2_topic "vsm:system2:coordination"
  @system3_topic "vsm:system3:control"
  @system4_topic "vsm:system4:intelligence"
  @system5_topic "vsm:system5:policy"
  @variety_topic "vsm:variety:gap"
  @consciousness_topic "vsm:consciousness:insight"
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def publish_event(system, event_type, payload) do
    topic = get_topic(system)
    event = build_event(system, event_type, payload)
    
    Phoenix.PubSub.broadcast(@pubsub, topic, event)
  end
  
  def subscribe(system) do
    topic = get_topic(system)
    Phoenix.PubSub.subscribe(@pubsub, topic)
  end
  
  def subscribe_all do
    all_topics()
    |> Enum.each(&Phoenix.PubSub.subscribe(@pubsub, &1))
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    state = %{
      subscriptions: opts[:subscriptions] || [:all],
      event_handlers: register_handlers(),
      metrics: %{
        events_published: 0,
        events_received: 0,
        events_processed: 0
      }
    }
    
    # Subscribe to configured topics
    setup_subscriptions(state.subscriptions)
    
    Logger.info("Event Bus Integration initialized")
    {:ok, state}
  end
  
  @impl true
  def handle_info({:vsm_event, event}, state) do
    # Process incoming events
    new_state = process_event(event, state)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(event, state) when is_map(event) do
    # Handle Phoenix.PubSub events
    if Map.has_key?(event, :system) and Map.has_key?(event, :type) do
      new_state = process_event(event, state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  # Private Functions
  
  defp get_topic(:system1), do: @system1_topic
  defp get_topic(:system2), do: @system2_topic
  defp get_topic(:system3), do: @system3_topic
  defp get_topic(:system4), do: @system4_topic
  defp get_topic(:system5), do: @system5_topic
  defp get_topic(:variety), do: @variety_topic
  defp get_topic(:consciousness), do: @consciousness_topic
  defp get_topic(_), do: "vsm:general"
  
  defp all_topics do
    [
      @system1_topic,
      @system2_topic,
      @system3_topic,
      @system4_topic,
      @system5_topic,
      @variety_topic,
      @consciousness_topic
    ]
  end
  
  defp build_event(system, event_type, payload) do
    %{
      system: system,
      type: event_type,
      payload: payload,
      timestamp: DateTime.utc_now(),
      id: generate_event_id()
    }
  end
  
  defp generate_event_id do
    "evt_#{:erlang.unique_integer([:positive])}_#{:erlang.system_time(:millisecond)}"
  end
  
  defp setup_subscriptions([:all]) do
    subscribe_all()
  end
  
  defp setup_subscriptions(systems) do
    systems
    |> Enum.each(&subscribe/1)
  end
  
  defp register_handlers do
    %{
      variety_gap_detected: &handle_variety_gap/2,
      consciousness_insight: &handle_consciousness_insight/2,
      system_alert: &handle_system_alert/2,
      coordination_request: &handle_coordination_request/2,
      policy_update: &handle_policy_update/2
    }
  end
  
  defp process_event(event, state) do
    Logger.debug("Processing event: #{event.type} from #{event.system}")
    
    # Update metrics
    new_state = Map.update_in(state, [:metrics, :events_received], &(&1 + 1))
    
    # Find and execute handler
    handler = Map.get(state.event_handlers, event.type)
    
    if handler do
      case handler.(event, new_state) do
        {:ok, updated_state} ->
          Map.update_in(updated_state, [:metrics, :events_processed], &(&1 + 1))
        
        {:error, reason} ->
          Logger.error("Event handler failed: #{reason}")
          new_state
      end
    else
      Logger.debug("No handler for event type: #{event.type}")
      new_state
    end
  end
  
  defp handle_variety_gap(event, state) do
    Logger.info("Variety gap detected: #{inspect(event.payload)}")
    
    # Trigger automatic capability acquisition
    if event.payload.acquisition_needed do
      Task.start(fn ->
        VsmMcp.Core.VarietyCalculator.calculate_variety_gap(
          event.payload.system,
          event.payload.environment
        )
      end)
    end
    
    {:ok, state}
  end
  
  defp handle_consciousness_insight(event, state) do
    Logger.info("Consciousness insight: #{inspect(event.payload)}")
    
    # Store insight for future use
    insight = event.payload
    
    # Notify relevant systems
    case insight.type do
      :strategic ->
        VsmMcp.Systems.System5.update_mission(insight.recommendation)
      
      :operational ->
        VsmMcp.Systems.System3.optimize_resources(%{insight: insight})
      
      _ ->
        :ok
    end
    
    {:ok, state}
  end
  
  defp handle_system_alert(event, state) do
    Logger.warning("System alert from #{event.system}: #{inspect(event.payload)}")
    
    # Route alerts to appropriate handlers
    alert = event.payload
    
    case alert.severity do
      :critical ->
        # Immediate action required
        VsmMcp.Systems.System5.validate_decision(
          %{type: :emergency, alert: alert},
          %{source: event.system}
        )
      
      :high ->
        # Notify System 3 for control action
        VsmMcp.Systems.System3.handle_alert(alert)
      
      _ ->
        # Log for monitoring
        :ok
    end
    
    {:ok, state}
  end
  
  defp handle_coordination_request(event, state) do
    Logger.info("Coordination request: #{inspect(event.payload)}")
    
    # Forward to System 2
    request = event.payload
    VsmMcp.Systems.System2.coordinate(request.units, request.task)
    
    {:ok, state}
  end
  
  defp handle_policy_update(event, state) do
    Logger.info("Policy update: #{inspect(event.payload)}")
    
    # Broadcast policy changes to all systems
    policy = event.payload
    
    # Notify all systems of policy change
    all_topics()
    |> Enum.each(fn topic ->
      Phoenix.PubSub.broadcast(
        @pubsub,
        topic,
        build_event(:system5, :policy_broadcast, policy)
      )
    end)
    
    {:ok, state}
  end
  
  @doc """
  Emit a variety gap event when detected.
  """
  def emit_variety_gap(gap_info) do
    publish_event(:variety, :variety_gap_detected, gap_info)
  end
  
  @doc """
  Emit a consciousness insight event.
  """
  def emit_consciousness_insight(insight) do
    publish_event(:consciousness, :consciousness_insight, insight)
  end
  
  @doc """
  Emit a system alert event.
  """
  def emit_system_alert(system, alert) do
    publish_event(system, :system_alert, alert)
  end
end