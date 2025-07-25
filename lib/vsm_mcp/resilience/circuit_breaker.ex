defmodule VsmMcp.Resilience.CircuitBreaker do
  @moduledoc """
  Circuit breaker implementation for fault tolerance in external service calls.
  
  Prevents cascading failures by temporarily blocking calls to failing services.
  
  States:
  - :closed - Normal operation, requests pass through
  - :open - Service is failing, requests are blocked
  - :half_open - Testing if service has recovered
  
  Configuration:
  - failure_threshold: Number of failures before opening circuit (default: 5)
  - success_threshold: Number of successes in half_open before closing (default: 3)
  - timeout: Duration to stay open before trying half_open (default: 60_000ms)
  - error_types: List of error types that trigger the circuit (default: all)
  """
  
  use GenServer
  require Logger
  
  @default_config %{
    failure_threshold: 5,
    success_threshold: 3,
    timeout: 60_000,
    error_types: :all,
    telemetry_prefix: [:vsm_mcp, :circuit_breaker]
  }
  
  # Client API
  
  @doc """
  Start a circuit breaker for a specific service.
  """
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    config = Keyword.get(opts, :config, %{})
    GenServer.start_link(__MODULE__, {name, config}, name: name)
  end
  
  @doc """
  Execute a function through the circuit breaker.
  
  Returns {:ok, result} if successful, {:error, :circuit_open} if circuit is open,
  or {:error, reason} if the function fails.
  """
  def call(breaker, fun, timeout \\ 5000) do
    GenServer.call(breaker, {:execute, fun}, timeout)
  end
  
  @doc """
  Get the current state of the circuit breaker.
  """
  def get_state(breaker) do
    GenServer.call(breaker, :get_state)
  end
  
  @doc """
  Reset the circuit breaker to closed state.
  """
  def reset(breaker) do
    GenServer.call(breaker, :reset)
  end
  
  @doc """
  Get statistics about the circuit breaker.
  """
  def get_stats(breaker) do
    GenServer.call(breaker, :get_stats)
  end
  
  # Server Callbacks
  
  @impl true
  def init({name, config}) do
    config = Map.merge(@default_config, config)
    
    state = %{
      name: name,
      config: config,
      state: :closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil,
      stats: %{
        total_calls: 0,
        successful_calls: 0,
        failed_calls: 0,
        rejected_calls: 0,
        state_transitions: []
      }
    }
    
    emit_telemetry(:initialized, %{}, state)
    {:ok, state}
  end
  
  @impl true
  def handle_call({:execute, fun}, _from, state) do
    state = increment_stat(state, :total_calls)
    
    case state.state do
      :closed ->
        execute_closed(fun, state)
      
      :open ->
        if should_attempt_reset?(state) do
          transition_to_half_open(state)
          |> execute_half_open(fun)
        else
          state = increment_stat(state, :rejected_calls)
          emit_telemetry(:rejected, %{reason: :circuit_open}, state)
          {:reply, {:error, :circuit_open}, state}
        end
      
      :half_open ->
        execute_half_open(fun, state)
    end
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.state, state}
  end
  
  @impl true
  def handle_call(:reset, _from, state) do
    new_state = transition_to_closed(state, :manual_reset)
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = Map.merge(state.stats, %{
      current_state: state.state,
      failure_count: state.failure_count,
      success_count: state.success_count,
      last_failure_time: state.last_failure_time
    })
    {:reply, stats, state}
  end
  
  # Private Functions
  
  defp execute_closed(fun, state) do
    case safe_execute(fun) do
      {:ok, result} ->
        state = state
        |> Map.put(:failure_count, 0)
        |> increment_stat(:successful_calls)
        
        emit_telemetry(:success, %{state: :closed}, state)
        {:reply, {:ok, result}, state}
      
      {:error, reason} = error ->
        state = handle_failure(state, reason, :closed)
        {:reply, error, state}
    end
  end
  
  defp execute_half_open(fun, state) do
    case safe_execute(fun) do
      {:ok, result} ->
        state = state
        |> Map.update!(:success_count, &(&1 + 1))
        |> increment_stat(:successful_calls)
        
        state = if state.success_count >= state.config.success_threshold do
          transition_to_closed(state, :threshold_met)
        else
          state
        end
        
        emit_telemetry(:success, %{state: :half_open}, state)
        {:reply, {:ok, result}, state}
      
      {:error, reason} = error ->
        state = state
        |> Map.put(:success_count, 0)
        |> transition_to_open(:half_open_failure)
        |> handle_failure(reason, :half_open)
        
        {:reply, error, state}
    end
  end
  
  defp handle_failure(state, reason, from_state) do
    state = state
    |> Map.update!(:failure_count, &(&1 + 1))
    |> Map.put(:last_failure_time, System.system_time(:millisecond))
    |> increment_stat(:failed_calls)
    
    if should_trip?(state, reason) do
      transition_to_open(state, :threshold_exceeded)
    else
      state
    end
    |> tap(fn s -> 
      emit_telemetry(:failure, %{
        reason: reason,
        from_state: from_state,
        failure_count: s.failure_count
      }, s)
    end)
  end
  
  defp safe_execute(fun) do
    try do
      result = fun.()
      {:ok, result}
    rescue
      error ->
        {:error, {error.__struct__, Exception.message(error)}}
    catch
      kind, reason ->
        {:error, {kind, reason}}
    end
  end
  
  defp should_trip?(state, reason) do
    error_matches?(state.config.error_types, reason) and
      state.failure_count >= state.config.failure_threshold
  end
  
  defp error_matches?(:all, _), do: true
  defp error_matches?(types, {type, _}) when is_list(types), do: type in types
  defp error_matches?(types, reason) when is_list(types), do: reason in types
  defp error_matches?(_, _), do: false
  
  defp should_attempt_reset?(state) do
    case state.last_failure_time do
      nil -> true
      time ->
        current_time = System.system_time(:millisecond)
        current_time - time >= state.config.timeout
    end
  end
  
  defp transition_to_open(state, reason) do
    Logger.warn("Circuit breaker #{state.name} opening: #{reason}")
    
    state
    |> Map.put(:state, :open)
    |> Map.put(:failure_count, 0)
    |> add_state_transition(:open, reason)
    |> tap(fn s -> emit_telemetry(:state_change, %{to: :open, reason: reason}, s) end)
  end
  
  defp transition_to_half_open(state) do
    Logger.info("Circuit breaker #{state.name} transitioning to half-open")
    
    state
    |> Map.put(:state, :half_open)
    |> Map.put(:success_count, 0)
    |> add_state_transition(:half_open, :timeout_expired)
    |> tap(fn s -> emit_telemetry(:state_change, %{to: :half_open, reason: :timeout_expired}, s) end)
  end
  
  defp transition_to_closed(state, reason) do
    Logger.info("Circuit breaker #{state.name} closing: #{reason}")
    
    state
    |> Map.put(:state, :closed)
    |> Map.put(:failure_count, 0)
    |> Map.put(:success_count, 0)
    |> Map.put(:last_failure_time, nil)
    |> add_state_transition(:closed, reason)
    |> tap(fn s -> emit_telemetry(:state_change, %{to: :closed, reason: reason}, s) end)
  end
  
  defp add_state_transition(state, new_state, reason) do
    transition = %{
      from: state.state,
      to: new_state,
      reason: reason,
      timestamp: System.system_time(:millisecond)
    }
    
    Map.update!(state, :stats, fn stats ->
      Map.update!(stats, :state_transitions, fn transitions ->
        [transition | transitions] |> Enum.take(100)  # Keep last 100 transitions
      end)
    end)
  end
  
  defp increment_stat(state, stat) do
    Map.update!(state, :stats, fn stats ->
      Map.update!(stats, stat, &(&1 + 1))
    end)
  end
  
  defp emit_telemetry(event, measurements, state) do
    :telemetry.execute(
      state.config.telemetry_prefix ++ [event],
      measurements,
      %{
        name: state.name,
        state: state.state,
        config: state.config
      }
    )
  end
end