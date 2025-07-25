defmodule VsmMcp.Integration.HTTPClient do
  @moduledoc """
  Enhanced HTTP client with resilience features for external service integration.
  
  Features:
  - Connection pooling
  - Timeout configurations
  - Rate limiting
  - Circuit breaker integration
  - Retry logic with exponential backoff
  - Telemetry integration
  """
  
  require Logger
  alias VsmMcp.Resilience.{CircuitBreaker, Retry}
  
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
  
  @default_rate_limit %{
    max_requests: 100,
    window_ms: 60_000  # 1 minute
  }
  
  defmodule State do
    defstruct [
      :name,
      :base_url,
      :pool_config,
      :timeout_config,
      :rate_limit,
      :circuit_breaker,
      :retry_config,
      :default_headers,
      rate_limit_state: %{}
    ]
  end
  
  use GenServer
  
  # Client API
  
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Make a GET request.
  """
  def get(client, path, headers \\ [], opts \\ []) do
    request(client, :get, path, "", headers, opts)
  end
  
  @doc """
  Make a POST request.
  """
  def post(client, path, body, headers \\ [], opts \\ []) do
    request(client, :post, path, body, headers, opts)
  end
  
  @doc """
  Make a PUT request.
  """
  def put(client, path, body, headers \\ [], opts \\ []) do
    request(client, :put, path, body, headers, opts)
  end
  
  @doc """
  Make a DELETE request.
  """
  def delete(client, path, headers \\ [], opts \\ []) do
    request(client, :delete, path, "", headers, opts)
  end
  
  @doc """
  Make a generic HTTP request.
  """
  def request(client, method, path, body, headers \\ [], opts \\ []) do
    GenServer.call(client, {:request, method, path, body, headers, opts}, 
                   opts[:timeout] || 60_000)
  end
  
  @doc """
  Get client statistics.
  """
  def stats(client) do
    GenServer.call(client, :stats)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    state = %State{
      name: Keyword.fetch!(opts, :name),
      base_url: Keyword.fetch!(opts, :base_url),
      pool_config: Map.merge(@default_pool_config, Keyword.get(opts, :pool_config, %{})),
      timeout_config: Map.merge(@default_timeout_config, Keyword.get(opts, :timeout_config, %{})),
      rate_limit: Map.merge(@default_rate_limit, Keyword.get(opts, :rate_limit, %{})),
      retry_config: Keyword.get(opts, :retry_config, %{}),
      default_headers: Keyword.get(opts, :default_headers, [])
    }
    
    # Initialize connection pool
    {:ok, _pool} = init_pool(state)
    
    # Initialize circuit breaker
    breaker_name = :"#{state.name}_circuit_breaker"
    {:ok, _} = VsmMcp.Resilience.Supervisor.start_circuit_breaker(
      breaker_name,
      Keyword.get(opts, :circuit_breaker_config, %{})
    )
    
    state = %{state | circuit_breaker: breaker_name}
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:request, method, path, body, headers, opts}, from, state) do
    # Check rate limit
    case check_rate_limit(state) do
      {:ok, new_state} ->
        # Execute request asynchronously
        Task.start(fn ->
          result = execute_request(method, path, body, headers, opts, state)
          GenServer.reply(from, result)
        end)
        
        {:noreply, new_state}
      
      {:error, :rate_limited} = error ->
        emit_telemetry(:rate_limited, %{client: state.name})
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      circuit_breaker: CircuitBreaker.get_stats(state.circuit_breaker),
      rate_limit: %{
        current_requests: map_size(state.rate_limit_state),
        max_requests: state.rate_limit.max_requests,
        window_ms: state.rate_limit.window_ms
      },
      pool: get_pool_stats(state)
    }
    
    {:reply, stats, state}
  end
  
  # Private Functions
  
  defp execute_request(method, path, body, headers, opts, state) do
    url = build_url(state.base_url, path)
    headers = merge_headers(state.default_headers, headers)
    
    # Execute through circuit breaker
    CircuitBreaker.call(state.circuit_breaker, fn ->
      # Execute with retry logic
      Retry.with_retry(
        fn -> do_http_request(method, url, body, headers, opts, state) end,
        Map.to_list(state.retry_config)
      )
    end)
  end
  
  defp do_http_request(method, url, body, headers, opts, state) do
    http_opts = build_http_opts(opts, state)
    
    start_time = System.monotonic_time(:millisecond)
    
    result = :poolboy.transaction(
      pool_name(state.name),
      fn worker ->
        GenServer.call(worker, 
          {:request, method, url, headers, body, http_opts},
          state.timeout_config.request_timeout
        )
      end,
      state.timeout_config.request_timeout + 1000
    )
    
    duration = System.monotonic_time(:millisecond) - start_time
    
    handle_response(result, state.name, duration)
  end
  
  defp handle_response({:ok, %{status_code: status} = response}, client_name, duration) 
       when status in 200..299 do
    emit_telemetry(:request_success, %{
      client: client_name,
      duration: duration,
      status: status
    })
    
    {:ok, response}
  end
  
  defp handle_response({:ok, %{status_code: 429} = response}, client_name, _duration) do
    emit_telemetry(:rate_limited_upstream, %{client: client_name})
    {:error, {:rate_limited, response}}
  end
  
  defp handle_response({:ok, %{status_code: status} = response}, client_name, _duration) 
       when status in 500..599 do
    emit_telemetry(:server_error, %{client: client_name, status: status})
    {:error, {:server_error, response}}
  end
  
  defp handle_response({:ok, response}, client_name, _duration) do
    emit_telemetry(:client_error, %{
      client: client_name, 
      status: response.status_code
    })
    {:error, {:client_error, response}}
  end
  
  defp handle_response({:error, %{reason: :timeout}}, client_name, duration) do
    emit_telemetry(:timeout, %{client: client_name, duration: duration})
    {:error, :timeout}
  end
  
  defp handle_response({:error, reason}, client_name, _duration) do
    emit_telemetry(:connection_error, %{client: client_name, reason: reason})
    {:error, reason}
  end
  
  defp check_rate_limit(state) do
    now = System.monotonic_time(:millisecond)
    window_start = now - state.rate_limit.window_ms
    
    # Clean expired entries
    active_requests = state.rate_limit_state
    |> Enum.filter(fn {_id, timestamp} -> timestamp > window_start end)
    |> Map.new()
    
    if map_size(active_requests) < state.rate_limit.max_requests do
      request_id = :erlang.unique_integer()
      new_requests = Map.put(active_requests, request_id, now)
      
      {:ok, %{state | rate_limit_state: new_requests}}
    else
      {:error, :rate_limited}
    end
  end
  
  defp build_url(base_url, path) do
    base_url = String.trim_trailing(base_url, "/")
    path = String.trim_leading(path, "/")
    "#{base_url}/#{path}"
  end
  
  defp merge_headers(default_headers, headers) do
    Keyword.merge(default_headers, headers)
  end
  
  defp build_http_opts(opts, state) do
    timeout_config = Map.merge(state.timeout_config, Map.new(opts[:timeouts] || []))
    
    [
      timeout: timeout_config.request_timeout,
      recv_timeout: timeout_config.recv_timeout,
      connect_timeout: timeout_config.connect_timeout,
      ssl: opts[:ssl] || [verify: :verify_peer, cacerts: :public_key.cacerts_get()],
      follow_redirect: opts[:follow_redirect] || false,
      max_redirect: opts[:max_redirect] || 5
    ]
  end
  
  defp init_pool(state) do
    pool_config = [
      {:name, {:local, pool_name(state.name)}},
      {:worker_module, VsmMcp.LLM.HTTPWorker},
      {:size, state.pool_config.size},
      {:max_overflow, state.pool_config.max_overflow},
      {:strategy, state.pool_config.strategy}
    ]
    
    :poolboy.start_link(pool_config)
  end
  
  defp pool_name(client_name), do: :"#{client_name}_http_pool"
  
  defp get_pool_stats(state) do
    pool = pool_name(state.name)
    status = :poolboy.status(pool)
    
    %{
      size: Keyword.get(status, :pool_size, 0),
      available: length(Keyword.get(status, :available_workers, [])),
      overflow: Keyword.get(status, :overflow, 0),
      in_use: Keyword.get(status, :pool_size, 0) - 
              length(Keyword.get(status, :available_workers, []))
    }
  end
  
  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:vsm_mcp, :http_client, event],
      measurements,
      %{}
    )
  end
end