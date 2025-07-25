defmodule VsmMcp.Resilience.TelemetryReporter do
  @moduledoc """
  Telemetry reporter for resilience metrics.
  
  Aggregates and reports on circuit breaker states, retry patterns,
  and error rates to enable monitoring and alerting.
  """
  
  use GenServer
  require Logger
  
  @metrics_interval 60_000  # 1 minute
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    # Attach telemetry handlers
    attach_handlers()
    
    # Schedule periodic metrics reporting
    schedule_report()
    
    state = %{
      circuit_breakers: %{},
      retries: %{},
      errors: %{},
      api_calls: %{},
      dlq: %{}
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_info({:telemetry, event, measurements, metadata}, state) do
    state = handle_telemetry_event(event, measurements, metadata, state)
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:report_metrics, state) do
    report_metrics(state)
    schedule_report()
    
    # Reset counters
    state = %{state | 
      retries: %{},
      errors: %{},
      api_calls: %{}
    }
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp attach_handlers do
    events = [
      # Circuit breaker events
      [:vsm_mcp, :circuit_breaker, :state_change],
      [:vsm_mcp, :circuit_breaker, :rejected],
      [:vsm_mcp, :circuit_breaker, :success],
      [:vsm_mcp, :circuit_breaker, :failure],
      
      # Retry events
      [:vsm_mcp, :retry, :attempt],
      [:vsm_mcp, :retry, :success],
      [:vsm_mcp, :retry, :failure],
      
      # API events
      [:vsm_mcp, :llm_api, :request_success],
      [:vsm_mcp, :llm_api, :timeout],
      [:vsm_mcp, :llm_api, :rate_limited],
      [:vsm_mcp, :llm_api, :server_error],
      [:vsm_mcp, :llm_api, :client_error],
      
      # DLQ events
      [:vsm_mcp, :dead_letter_queue, :item_added],
      [:vsm_mcp, :dead_letter_queue, :item_retried]
    ]
    
    Enum.each(events, fn event ->
      :telemetry.attach(
        {__MODULE__, event},
        event,
        &handle_event/4,
        nil
      )
    end)
  end
  
  defp handle_event(event, measurements, metadata, _config) do
    send(self(), {:telemetry, event, measurements, metadata})
  end
  
  defp handle_telemetry_event([:vsm_mcp, :circuit_breaker, :state_change], 
                              _measurements, %{name: name, to: state}, state) do
    put_in(state, [:circuit_breakers, name], %{
      state: state,
      last_change: DateTime.utc_now()
    })
  end
  
  defp handle_telemetry_event([:vsm_mcp, :circuit_breaker, event], 
                              _measurements, %{name: name}, state) do
    update_counter(state, [:circuit_breakers, name, event])
  end
  
  defp handle_telemetry_event([:vsm_mcp, :retry, event], 
                              %{attempt: attempt}, _metadata, state) do
    update_counter(state, [:retries, event, attempt])
  end
  
  defp handle_telemetry_event([:vsm_mcp, :llm_api, event], 
                              measurements, %{provider: provider}, state) do
    state = update_counter(state, [:api_calls, provider, event])
    
    # Track response times
    if duration = measurements[:duration] do
      update_in(state, [:api_calls, provider, :response_times], fn times ->
        [duration | (times || [])] |> Enum.take(100)
      end)
    end
    
    state
  end
  
  defp handle_telemetry_event([:vsm_mcp, :dead_letter_queue, event], 
                              _measurements, metadata, state) do
    update_counter(state, [:dlq, event])
  end
  
  defp handle_telemetry_event(_, _, _, state), do: state
  
  defp update_counter(state, path) do
    update_in(state, path, fn count -> (count || 0) + 1 end)
  end
  
  defp report_metrics(state) do
    Logger.info("""
    Resilience Metrics Report:
    
    Circuit Breakers:
    #{format_circuit_breakers(state.circuit_breakers)}
    
    API Calls:
    #{format_api_calls(state.api_calls)}
    
    Retries:
    #{format_retries(state.retries)}
    
    Dead Letter Queue:
    #{format_dlq(state.dlq)}
    """)
    
    # Emit aggregated metrics for monitoring systems
    emit_aggregated_metrics(state)
  end
  
  defp format_circuit_breakers(breakers) do
    breakers
    |> Enum.map(fn {name, info} ->
      "  #{name}: #{info[:state] || "unknown"} (rejected: #{info[:rejected] || 0})"
    end)
    |> Enum.join("\n")
  end
  
  defp format_api_calls(calls) do
    calls
    |> Enum.map(fn {provider, stats} ->
      total = Enum.reduce(stats, 0, fn
        {k, v}, acc when is_integer(v) and k != :response_times -> acc + v
        _, acc -> acc
      end)
      
      avg_response_time = case stats[:response_times] do
        nil -> "N/A"
        [] -> "N/A"
        times -> "#{Enum.sum(times) / length(times)}ms"
      end
      
      """
        #{provider}:
          Total: #{total}
          Success: #{stats[:request_success] || 0}
          Timeouts: #{stats[:timeout] || 0}
          Rate Limited: #{stats[:rate_limited] || 0}
          Server Errors: #{stats[:server_error] || 0}
          Avg Response Time: #{avg_response_time}
      """
    end)
    |> Enum.join("\n")
  end
  
  defp format_retries(retries) do
    retries
    |> Enum.map(fn {event, attempts} ->
      "  #{event}: #{inspect(attempts)}"
    end)
    |> Enum.join("\n")
  end
  
  defp format_dlq(dlq) do
    "  Items added: #{dlq[:item_added] || 0}, Items retried: #{dlq[:item_retried] || 0}"
  end
  
  defp emit_aggregated_metrics(state) do
    # Calculate error rate
    total_calls = get_in(state, [:api_calls])
    |> Enum.reduce(0, fn {_provider, stats}, acc ->
      acc + (stats[:request_success] || 0) + 
            (stats[:timeout] || 0) + 
            (stats[:server_error] || 0) +
            (stats[:client_error] || 0)
    end)
    
    error_calls = get_in(state, [:api_calls])
    |> Enum.reduce(0, fn {_provider, stats}, acc ->
      acc + (stats[:timeout] || 0) + 
            (stats[:server_error] || 0) +
            (stats[:client_error] || 0)
    end)
    
    error_rate = if total_calls > 0, do: error_calls / total_calls * 100, else: 0
    
    :telemetry.execute(
      [:vsm_mcp, :resilience, :metrics],
      %{
        error_rate: error_rate,
        total_calls: total_calls,
        circuit_breakers_open: count_open_breakers(state.circuit_breakers),
        dlq_size: state.dlq[:item_added] || 0
      },
      %{}
    )
  end
  
  defp count_open_breakers(breakers) do
    Enum.count(breakers, fn {_name, info} -> info[:state] == :open end)
  end
  
  defp schedule_report do
    Process.send_after(self(), :report_metrics, @metrics_interval)
  end
end