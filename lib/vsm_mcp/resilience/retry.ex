defmodule VsmMcp.Resilience.Retry do
  @moduledoc """
  Retry logic with exponential backoff and dead letter queue support.
  
  Features:
  - Exponential backoff with jitter
  - Maximum retry limits
  - Dead letter queue for permanent failures
  - Configurable retry strategies
  - Telemetry integration
  """
  
  require Logger
  
  @default_config %{
    max_retries: 3,
    initial_delay: 1000,
    max_delay: 30_000,
    backoff_factor: 2,
    jitter: true,
    retry_on: :all,
    telemetry_prefix: [:vsm_mcp, :retry]
  }
  
  @doc """
  Execute a function with retry logic.
  
  Options:
  - max_retries: Maximum number of retry attempts (default: 3)
  - initial_delay: Initial delay in milliseconds (default: 1000)
  - max_delay: Maximum delay between retries (default: 30_000)
  - backoff_factor: Exponential backoff factor (default: 2)
  - jitter: Add randomness to delays (default: true)
  - retry_on: List of error types to retry on, or :all (default: :all)
  - on_retry: Function to call on each retry with (attempt, error, delay)
  - on_failure: Function to call on permanent failure with (error, attempts)
  """
  def with_retry(fun, opts \\ []) do
    config = Map.merge(@default_config, Map.new(opts))
    do_retry(fun, config, 0, nil)
  end
  
  @doc """
  Execute with retry and send to dead letter queue on permanent failure.
  """
  def with_retry_and_dlq(fun, dlq, opts \\ []) do
    on_failure = fn error, attempts ->
      send_to_dlq(dlq, {fun, error, attempts})
    end
    
    with_retry(fun, Keyword.put(opts, :on_failure, on_failure))
  end
  
  @doc """
  Calculate the next delay with exponential backoff.
  """
  def calculate_delay(attempt, config) do
    base_delay = min(
      config.initial_delay * :math.pow(config.backoff_factor, attempt),
      config.max_delay
    ) |> round()
    
    if config.jitter do
      add_jitter(base_delay)
    else
      base_delay
    end
  end
  
  # Private Functions
  
  defp do_retry(fun, config, attempt, last_error) do
    emit_telemetry(:attempt, %{attempt: attempt}, config)
    
    case safe_execute(fun) do
      {:ok, result} ->
        if attempt > 0 do
          emit_telemetry(:success, %{attempts: attempt + 1}, config)
        end
        {:ok, result}
      
      {:error, reason} = error ->
        if should_retry?(reason, attempt, config) do
          delay = calculate_delay(attempt, config)
          
          Logger.debug("Retry attempt #{attempt + 1}/#{config.max_retries} after #{delay}ms delay")
          
          emit_telemetry(:retry, %{
            attempt: attempt + 1,
            delay: delay,
            error: reason
          }, config)
          
          if config[:on_retry] do
            config.on_retry.(attempt + 1, reason, delay)
          end
          
          Process.sleep(delay)
          do_retry(fun, config, attempt + 1, reason)
        else
          handle_permanent_failure(reason, attempt + 1, config)
          error
        end
    end
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
  
  defp should_retry?(reason, attempt, config) do
    attempt < config.max_retries and retry_on_error?(reason, config.retry_on)
  end
  
  defp retry_on_error?(_reason, :all), do: true
  defp retry_on_error?({type, _}, types) when is_list(types), do: type in types
  defp retry_on_error?(reason, types) when is_list(types), do: reason in types
  defp retry_on_error?(_, _), do: false
  
  defp add_jitter(delay) do
    # Add ±25% jitter
    jitter_range = delay * 0.25
    delay + round(:rand.uniform() * 2 * jitter_range - jitter_range)
  end
  
  defp handle_permanent_failure(error, attempts, config) do
    Logger.error("Permanent failure after #{attempts} attempts: #{inspect(error)}")
    
    emit_telemetry(:failure, %{
      attempts: attempts,
      error: error
    }, config)
    
    if config[:on_failure] do
      config.on_failure.(error, attempts)
    end
  end
  
  defp send_to_dlq(dlq, item) do
    GenServer.cast(dlq, {:add, item})
  end
  
  defp emit_telemetry(event, measurements, config) do
    :telemetry.execute(
      config.telemetry_prefix ++ [event],
      measurements,
      %{config: config}
    )
  end
end