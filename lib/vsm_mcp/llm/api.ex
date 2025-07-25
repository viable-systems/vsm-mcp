defmodule VsmMcp.LLM.API do
  @moduledoc """
  Enhanced LLM API client with resilience features.
  
  Features:
  - Circuit breakers for each LLM provider
  - Automatic retry with exponential backoff
  - Dead letter queue for failed requests
  - Connection pooling
  - Rate limiting
  - Comprehensive telemetry
  """
  
  require Logger
  alias VsmMcp.Resilience.{CircuitBreaker, Retry, DeadLetterQueue}
  alias HTTPoison.{AsyncResponse, AsyncStatus, AsyncHeaders, AsyncChunk, AsyncEnd}
  
  @default_pool_config %{
    size: 10,
    max_overflow: 5,
    strategy: :fifo
  }
  
  @default_timeout_config %{
    connect_timeout: 5_000,
    recv_timeout: 30_000,
    request_timeout: 35_000
  }
  
  @default_retry_config %{
    max_retries: 3,
    initial_delay: 1_000,
    max_delay: 15_000,
    backoff_factor: 2,
    retry_on: [:timeout, :closed, :connection_refused]
  }
  
  # Client API
  
  @doc """
  Initialize the API client with resilience features.
  """
  def init(provider, config) do
    # Start circuit breaker for this provider
    breaker_name = breaker_name(provider)
    {:ok, _} = CircuitBreaker.start_link(
      name: breaker_name,
      config: %{
        failure_threshold: config[:circuit_breaker_threshold] || 5,
        timeout: config[:circuit_breaker_timeout] || 60_000,
        error_types: [:timeout, :connection_refused, :service_unavailable]
      }
    )
    
    # Initialize connection pool
    pool_config = Map.merge(@default_pool_config, config[:pool] || %{})
    init_pool(provider, pool_config)
    
    # Start DLQ if configured
    if config[:enable_dlq] do
      {:ok, _} = DeadLetterQueue.start_link(name: dlq_name(provider))
    end
    
    :ok
  end
  
  @doc """
  Make an API request with full resilience features.
  """
  def request(provider, endpoint, body, opts \\ []) do
    breaker = breaker_name(provider)
    
    # Execute through circuit breaker
    CircuitBreaker.call(breaker, fn ->
      # Execute with retry logic
      Retry.with_retry_and_dlq(
        fn -> do_request(provider, endpoint, body, opts) end,
        dlq_name(provider),
        Keyword.merge(@default_retry_config, opts[:retry] || [])
      )
    end)
  end
  
  @doc """
  Make a streaming request with resilience.
  """
  def stream_request(provider, endpoint, body, callback, opts \\ []) do
    breaker = breaker_name(provider)
    
    CircuitBreaker.call(breaker, fn ->
      Retry.with_retry(
        fn -> do_stream_request(provider, endpoint, body, callback, opts) end,
        Keyword.merge(@default_retry_config, opts[:retry] || [])
      )
    end)
  end
  
  @doc """
  Get health status of a provider's API.
  """
  def health_check(provider) do
    breaker = breaker_name(provider)
    breaker_state = CircuitBreaker.get_state(breaker)
    breaker_stats = CircuitBreaker.get_stats(breaker)
    
    pool_stats = get_pool_stats(provider)
    
    %{
      circuit_breaker: %{
        state: breaker_state,
        stats: breaker_stats
      },
      connection_pool: pool_stats,
      dlq: get_dlq_stats(provider)
    }
  end
  
  # Private Functions
  
  defp do_request(provider, endpoint, body, opts) do
    url = build_url(provider, endpoint)
    headers = build_headers(provider, opts)
    http_opts = build_http_opts(opts)
    
    start_time = System.monotonic_time(:millisecond)
    
    result = :poolboy.transaction(
      pool_name(provider),
      fn worker ->
        GenServer.call(worker, {:request, :post, url, headers, body, http_opts})
      end,
      opts[:timeout] || @default_timeout_config.request_timeout
    )
    
    duration = System.monotonic_time(:millisecond) - start_time
    
    case result do
      {:ok, %{status_code: status, body: resp_body}} when status in 200..299 ->
        emit_telemetry(:request_success, %{
          provider: provider,
          duration: duration,
          status: status
        })
        
        parse_response(provider, resp_body)
      
      {:ok, %{status_code: 429, headers: headers}} ->
        # Rate limited - extract retry after
        retry_after = extract_retry_after(headers)
        emit_telemetry(:rate_limited, %{
          provider: provider,
          retry_after: retry_after
        })
        
        {:error, {:rate_limited, retry_after}}
      
      {:ok, %{status_code: status, body: body}} when status in 500..599 ->
        emit_telemetry(:server_error, %{
          provider: provider,
          status: status
        })
        
        {:error, {:service_unavailable, status, body}}
      
      {:ok, %{status_code: status, body: body}} ->
        emit_telemetry(:client_error, %{
          provider: provider,
          status: status
        })
        
        {:error, {:api_error, status, body}}
      
      {:error, %{reason: :timeout}} ->
        emit_telemetry(:timeout, %{
          provider: provider,
          duration: duration
        })
        
        {:error, :timeout}
      
      {:error, %{reason: reason}} ->
        emit_telemetry(:connection_error, %{
          provider: provider,
          reason: reason
        })
        
        {:error, reason}
    end
  end
  
  defp do_stream_request(provider, endpoint, body, callback, opts) do
    url = build_url(provider, endpoint)
    headers = build_headers(provider, opts) ++ [{"Accept", "text/event-stream"}]
    http_opts = build_http_opts(opts) ++ [stream_to: self()]
    
    case HTTPoison.post(url, body, headers, http_opts) do
      {:ok, %AsyncResponse{id: ref}} ->
        handle_stream(ref, callback, "")
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp handle_stream(ref, callback, buffer) do
    receive do
      %AsyncStatus{id: ^ref, code: status} when status in 200..299 ->
        handle_stream(ref, callback, buffer)
      
      %AsyncStatus{id: ^ref, code: status} ->
        {:error, {:api_error, status}}
      
      %AsyncHeaders{id: ^ref} ->
        handle_stream(ref, callback, buffer)
      
      %AsyncChunk{id: ^ref, chunk: chunk} ->
        {events, new_buffer} = parse_sse(buffer <> chunk)
        Enum.each(events, callback)
        handle_stream(ref, callback, new_buffer)
      
      %AsyncEnd{id: ^ref} ->
        :ok
    after
      60_000 ->
        {:error, :stream_timeout}
    end
  end
  
  defp parse_sse(data) do
    lines = String.split(data, "\n")
    
    {events, remaining} = parse_sse_lines(lines, [], [])
    
    {Enum.reverse(events), Enum.join(remaining, "\n")}
  end
  
  defp parse_sse_lines([], events, buffer), do: {events, buffer}
  
  defp parse_sse_lines([line | rest], events, buffer) do
    if String.starts_with?(line, "data: ") do
      data = String.replace_prefix(line, "data: ", "")
      
      case Jason.decode(data) do
        {:ok, json} ->
          parse_sse_lines(rest, [json | events], [])
        {:error, _} ->
          parse_sse_lines(rest, events, [line | buffer])
      end
    else
      parse_sse_lines(rest, events, [line | buffer])
    end
  end
  
  defp build_url(:openai, endpoint), do: "https://api.openai.com/v1#{endpoint}"
  defp build_url(:anthropic, endpoint), do: "https://api.anthropic.com/v1#{endpoint}"
  defp build_url({:custom, base_url}, endpoint), do: "#{base_url}#{endpoint}"
  
  defp build_headers(:openai, opts) do
    [
      {"Authorization", "Bearer #{opts[:api_key]}"},
      {"Content-Type", "application/json"}
    ]
  end
  
  defp build_headers(:anthropic, opts) do
    [
      {"x-api-key", opts[:api_key]},
      {"anthropic-version", "2023-06-01"},
      {"Content-Type", "application/json"}
    ]
  end
  
  defp build_http_opts(opts) do
    timeout_config = Map.merge(@default_timeout_config, opts[:timeouts] || %{})
    
    [
      timeout: timeout_config.request_timeout,
      recv_timeout: timeout_config.recv_timeout,
      ssl: [verify: :verify_peer, cacerts: :public_key.cacerts_get()],
      pool: pool_name(opts[:provider])
    ]
  end
  
  defp parse_response(:openai, body) do
    case Jason.decode(body) do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
        {:ok, content}
      {:ok, %{"error" => error}} ->
        {:error, {:api_error, error}}
      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end
  
  defp parse_response(:anthropic, body) do
    case Jason.decode(body) do
      {:ok, %{"content" => [%{"text" => text} | _]}} ->
        {:ok, text}
      {:ok, %{"error" => error}} ->
        {:error, {:api_error, error}}
      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end
  
  defp extract_retry_after(headers) do
    case List.keyfind(headers, "retry-after", 0) do
      {_, value} -> String.to_integer(value)
      nil -> 60  # Default to 60 seconds
    end
  end
  
  defp breaker_name(provider), do: :"circuit_breaker_#{provider}"
  defp pool_name(provider), do: :"http_pool_#{provider}"
  defp dlq_name(provider), do: :"dlq_#{provider}"
  
  defp init_pool(provider, config) do
    pool_config = [
      {:name, {:local, pool_name(provider)}},
      {:worker_module, VsmMcp.LLM.HTTPWorker},
      {:size, config.size},
      {:max_overflow, config.max_overflow}
    ]
    
    {:ok, _} = :poolboy.start_link(pool_config)
  end
  
  defp get_pool_stats(provider) do
    pool = pool_name(provider)
    
    %{
      size: :poolboy.status(pool) |> Keyword.get(:pool_size),
      available: :poolboy.status(pool) |> Keyword.get(:available_workers),
      overflow: :poolboy.status(pool) |> Keyword.get(:overflow)
    }
  end
  
  defp get_dlq_stats(provider) do
    case Process.whereis(dlq_name(provider)) do
      nil -> nil
      _pid -> DeadLetterQueue.stats(dlq_name(provider))
    end
  end
  
  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:vsm_mcp, :llm_api, event],
      measurements,
      %{}
    )
  end
end