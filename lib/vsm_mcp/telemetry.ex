defmodule VsmMcp.Telemetry do
  @moduledoc """
  Telemetry and metrics collection for VSM-MCP system.
  
  Tracks performance, capability acquisition, and system health metrics.
  """
  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def record_metric(metric, value, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:record_metric, metric, value, metadata})
  end

  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  def get_system_health do
    GenServer.call(__MODULE__, :system_health)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      metrics: %{},
      start_time: DateTime.utc_now(),
      events: []
    }
    
    Logger.info("VSM-MCP Telemetry system initialized")
    {:ok, state}
  end

  @impl true
  def handle_cast({:record_metric, metric, value, metadata}, state) do
    timestamp = DateTime.utc_now()
    
    event = %{
      metric: metric,
      value: value,
      metadata: metadata,
      timestamp: timestamp
    }
    
    new_metrics = Map.update(state.metrics, metric, [event], &[event | &1])
    new_events = [event | Enum.take(state.events, 99)]  # Keep last 100 events
    
    Logger.debug("Telemetry recorded: #{metric} = #{inspect(value)}")
    
    {:noreply, %{state | metrics: new_metrics, events: new_events}}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl true
  def handle_call(:system_health, _from, state) do
    uptime = DateTime.diff(DateTime.utc_now(), state.start_time, :second)
    
    health = %{
      uptime_seconds: uptime,
      total_events: length(state.events),
      metrics_tracked: map_size(state.metrics),
      last_event: List.first(state.events),
      system_status: :healthy
    }
    
    {:reply, health, state}
  end

  # Helper functions for common metrics

  def record_operation_start(operation_id, operation_type) do
    record_metric(:operation_start, operation_id, %{type: operation_type})
  end

  def record_operation_complete(operation_id, duration_ms, result) do
    record_metric(:operation_complete, duration_ms, %{
      operation_id: operation_id,
      result: result
    })
  end

  def record_capability_acquisition(capability, method, success) do
    record_metric(:capability_acquisition, success, %{
      capability: capability,
      method: method
    })
  end

  def record_mcp_server_interaction(server_name, action, result) do
    record_metric(:mcp_interaction, result, %{
      server: server_name,
      action: action
    })
  end

  def record_llm_request(provider, tokens_used, response_time_ms) do
    record_metric(:llm_request, tokens_used, %{
      provider: provider,
      response_time_ms: response_time_ms
    })
  end

  # Legacy compatibility function
  def vm_measurements do
    # Execute telemetry events for VM metrics
    :telemetry.execute([:vm, :memory], %{total: :erlang.memory(:total)}, %{})
    :telemetry.execute([:vm, :system_info], %{process_count: :erlang.system_info(:process_count)}, %{})
  end
end