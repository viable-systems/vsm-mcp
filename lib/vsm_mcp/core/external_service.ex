defmodule VsmMcp.Core.ExternalService do
  @moduledoc """
  Base module for external service integration with full resilience.
  
  Provides a standard interface for integrating external services with:
  - Circuit breakers
  - Retry logic
  - Rate limiting
  - Connection pooling
  - Comprehensive error handling
  - Telemetry and monitoring
  """
  
  defmacro __using__(opts) do
    quote do
      use GenServer
      require Logger
      
      alias VsmMcp.Integration.HTTPClient
      alias VsmMcp.Resilience.{CircuitBreaker, Retry, DeadLetterQueue}
      
      @service_name unquote(opts[:service_name]) || __MODULE__
      @base_url unquote(opts[:base_url]) || ""
      @default_timeout unquote(opts[:timeout]) || 30_000
      
      # Client API
      
      def start_link(config \\ []) do
        GenServer.start_link(__MODULE__, config, name: __MODULE__)
      end
      
      def call(operation, params, opts \\ []) do
        timeout = opts[:timeout] || @default_timeout
        GenServer.call(__MODULE__, {:call, operation, params, opts}, timeout)
      end
      
      def health_check do
        GenServer.call(__MODULE__, :health_check)
      end
      
      # Callbacks to be implemented by using module
      
      @callback build_request(operation :: atom(), params :: map()) :: 
        {:ok, method :: atom(), path :: String.t(), body :: any(), headers :: keyword()} |
        {:error, reason :: any()}
      
      @callback handle_response(operation :: atom(), response :: map()) ::
        {:ok, result :: any()} | {:error, reason :: any()}
      
      @callback validate_params(operation :: atom(), params :: map()) ::
        :ok | {:error, validation_errors :: list()}
      
      # Server implementation
      
      @impl true
      def init(config) do
        # Merge with default configuration
        config = Keyword.merge(default_config(), config)
        
        # Initialize HTTP client
        http_config = [
          name: :"#{@service_name}_http_client",
          base_url: config[:base_url] || @base_url,
          pool_config: config[:pool_config] || %{},
          timeout_config: config[:timeout_config] || %{},
          rate_limit: config[:rate_limit] || %{},
          circuit_breaker_config: config[:circuit_breaker_config] || %{},
          retry_config: config[:retry_config] || %{},
          default_headers: config[:default_headers] || []
        ]
        
        {:ok, _client} = HTTPClient.start_link(http_config)
        
        state = %{
          service_name: @service_name,
          http_client: http_config[:name],
          config: config,
          stats: %{
            total_calls: 0,
            successful_calls: 0,
            failed_calls: 0,
            validation_errors: 0
          }
        }
        
        Logger.info("External service #{@service_name} initialized")
        
        {:ok, state}
      end
      
      @impl true
      def handle_call({:call, operation, params, opts}, _from, state) do
        start_time = System.monotonic_time(:millisecond)
        
        # Validate parameters
        case validate_params(operation, params) do
          :ok ->
            result = execute_operation(operation, params, opts, state)
            duration = System.monotonic_time(:millisecond) - start_time
            
            state = update_stats(state, result, duration)
            
            {:reply, result, state}
          
          {:error, validation_errors} = error ->
            state = update_in(state, [:stats, :validation_errors], &(&1 + 1))
            emit_telemetry(:validation_error, %{
              operation: operation,
              errors: validation_errors
            }, state)
            
            {:reply, error, state}
        end
      end
      
      @impl true
      def handle_call(:health_check, _from, state) do
        health_info = %{
          service: @service_name,
          status: :ok,
          http_client: HTTPClient.stats(state.http_client),
          stats: state.stats
        }
        
        {:reply, health_info, state}
      end
      
      # Private helper functions
      
      defp execute_operation(operation, params, opts, state) do
        with {:ok, method, path, body, headers} <- build_request(operation, params),
             {:ok, response} <- make_http_request(method, path, body, headers, opts, state),
             {:ok, result} <- handle_response(operation, response) do
          
          emit_telemetry(:success, %{
            operation: operation,
            duration: opts[:duration]
          }, state)
          
          {:ok, result}
        else
          {:error, reason} = error ->
            emit_telemetry(:failure, %{
              operation: operation,
              reason: reason
            }, state)
            
            error
        end
      end
      
      defp make_http_request(method, path, body, headers, opts, state) do
        HTTPClient.request(
          state.http_client,
          method,
          path,
          encode_body(body),
          headers,
          opts
        )
      end
      
      defp encode_body(body) when is_binary(body), do: body
      defp encode_body(body), do: Jason.encode!(body)
      
      defp update_stats(state, result, duration) do
        state = update_in(state, [:stats, :total_calls], &(&1 + 1))
        
        case result do
          {:ok, _} ->
            update_in(state, [:stats, :successful_calls], &(&1 + 1))
          
          {:error, _} ->
            update_in(state, [:stats, :failed_calls], &(&1 + 1))
        end
      end
      
      defp emit_telemetry(event, measurements, state) do
        :telemetry.execute(
          [:vsm_mcp, :external_service, event],
          Map.put(measurements, :service, @service_name),
          %{state: state}
        )
      end
      
      defp default_config do
        [
          pool_config: %{
            size: 10,
            max_overflow: 5
          },
          timeout_config: %{
            connect_timeout: 5_000,
            recv_timeout: 30_000,
            request_timeout: 35_000
          },
          rate_limit: %{
            max_requests: 100,
            window_ms: 60_000
          },
          circuit_breaker_config: %{
            failure_threshold: 5,
            timeout: 60_000
          },
          retry_config: %{
            max_retries: 3,
            initial_delay: 1_000,
            max_delay: 15_000,
            backoff_factor: 2
          }
        ]
      end
      
      # Allow using modules to override these functions
      defoverridable [
        init: 1,
        default_config: 0,
        handle_call: 3
      ]
    end
  end
end