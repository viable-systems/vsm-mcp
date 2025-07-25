defmodule VsmMcp.MCP.Protocol.Handler do
  @moduledoc """
  MCP protocol handler that processes JSON-RPC messages and routes them to appropriate handlers.
  """

  alias VsmMcp.MCP.Protocol.{JsonRpc, Messages}
  alias JsonRpc.{Request, Response, Notification, Batch}
  require Logger

  @behaviour GenServer

  defstruct [
    :transport,
    :state,
    :capabilities,
    :handlers,
    :subscriptions,
    :pending_requests,
    :next_id,
    :request_timeout
  ]

  @default_timeout 30_000

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def send_request(handler, method, params) do
    GenServer.call(handler, {:send_request, method, params})
  end

  def send_notification(handler, method, params) do
    GenServer.cast(handler, {:send_notification, method, params})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    # Start the ID generator if not already started
    case Process.whereis(JsonRpc.IdGenerator) do
      nil -> 
        {:ok, _} = JsonRpc.IdGenerator.start_link([])
      _ -> 
        :ok
    end

    state = %__MODULE__{
      transport: opts[:transport],
      state: :uninitialized,
      capabilities: opts[:capabilities] || %{},
      handlers: opts[:handlers] || %{},
      subscriptions: %{},
      pending_requests: %{},
      next_id: 1,
      request_timeout: opts[:timeout] || @default_timeout
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:send_request, method, params}, from, state) do
    # Build request with auto-generated ID
    request = JsonRpc.build_jsonrpc_request(method, params)
    
    case JsonRpc.encode_jsonrpc_message(request) do
      {:ok, json} ->
        # Send the message
        send(state.transport, {:send, json})
        
        # Store pending request with timeout
        request_info = %{
          from: from,
          timestamp: System.monotonic_time(:millisecond),
          method: method,
          timeout: state.request_timeout
        }
        
        new_state = %{state |
          pending_requests: Map.put(state.pending_requests, request.id, request_info)
        }
        
        # Set up timeout
        Process.send_after(self(), {:request_timeout, request.id}, state.request_timeout)
        
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to encode request: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:send_notification, method, params}, state) do
    notification = JsonRpc.build_jsonrpc_notification(method, params)

    case JsonRpc.encode_jsonrpc_message(notification) do
      {:ok, json} ->
        send(state.transport, {:send, json})
        Logger.debug("Sent notification: #{method}")

      {:error, reason} ->
        Logger.error("Failed to encode notification: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:message, json_string}, state) do
    case JsonRpc.parse_jsonrpc_message(json_string) do
      {:ok, %Request{} = request} ->
        handle_request(request, state)

      {:ok, %Response{} = response} ->
        handle_response(response, state)

      {:ok, %Notification{} = notification} ->
        handle_notification(notification, state)

      {:ok, %Batch{messages: messages}} ->
        handle_batch(messages, state)

      {:error, reason} ->
        Logger.error("Failed to parse message: #{inspect(reason)}")
        # Send parse error response if we can extract an ID
        maybe_send_parse_error(json_string, state)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:request_timeout, request_id}, state) do
    case Map.get(state.pending_requests, request_id) do
      nil ->
        # Request already completed
        {:noreply, state}

      %{from: from} ->
        Logger.warn("Request timeout for ID: #{request_id}")
        GenServer.reply(from, {:error, :timeout})
        
        new_state = %{state | 
          pending_requests: Map.delete(state.pending_requests, request_id)
        }
        {:noreply, new_state}
    end
  end

  # Request handling

  defp handle_request(%Request{method: method, params: params, id: id}, state) do
    Logger.debug("Handling request: #{method} (ID: #{id})")

    result =
      case route_request(method, params, state) do
        {:ok, result} ->
          JsonRpc.build_jsonrpc_response(result, id)

        {:error, {code, message, data}} ->
          JsonRpc.build_jsonrpc_error(code, message, id, data)

        {:error, reason} ->
          Logger.error("Request processing error: #{inspect(reason)}")
          JsonRpc.internal_error(id, inspect(reason))
      end

    case JsonRpc.encode_jsonrpc_message(result) do
      {:ok, json} ->
        send(state.transport, {:send, json})
        Logger.debug("Sent response for #{method} (ID: #{id})")

      {:error, reason} ->
        Logger.error("Failed to encode response: #{inspect(reason)}")
        # Try to send internal error as fallback
        fallback = JsonRpc.internal_error(id, "Response encoding failed")
        case JsonRpc.encode_jsonrpc_message(fallback) do
          {:ok, fallback_json} ->
            send(state.transport, {:send, fallback_json})
          {:error, _} ->
            Logger.error("Cannot send any response for request #{id}")
        end
    end

    {:noreply, state}
  end

  defp handle_response(%Response{id: id} = response, state) do
    case JsonRpc.correlate_response(response, state.pending_requests) do
      {:ok, {%{from: from}, remaining_requests}} ->
        result =
          if response.error do
            {:error, response.error}
          else
            {:ok, response.result}
          end

        GenServer.reply(from, result)
        Logger.debug("Correlated response for request ID: #{id}")
        {:noreply, %{state | pending_requests: remaining_requests}}

      {:error, reason} ->
        Logger.warn("Failed to correlate response: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  # Notification handling
  defp handle_notification(%Notification{method: method, params: params}, state) do
    Logger.debug("Handling notification: #{method}")
    new_state = process_notification(method, params, state)
    {:noreply, new_state}
  end

  # Batch handling
  defp handle_batch(messages, state) do
    Logger.debug("Handling batch with #{length(messages)} messages")
    
    responses = 
      Enum.map(messages, fn message ->
        case message do
          %Request{} = request ->
            # Process request and return response (synchronously for batch)
            process_batch_request(request, state)
          
          %Notification{} = notification ->
            # Process notification (no response)
            process_notification(notification.method, notification.params, state)
            nil
        end
      end)
      |> Enum.filter(& &1 != nil)

    # Send batch response if there are any responses
    if length(responses) > 0 do
      batch_response = %Batch{messages: responses}
      case JsonRpc.encode_jsonrpc_message(batch_response) do
        {:ok, json} ->
          send(state.transport, {:send, json})
          Logger.debug("Sent batch response with #{length(responses)} responses")
        {:error, reason} ->
          Logger.error("Failed to encode batch response: #{inspect(reason)}")
      end
    end

    {:noreply, state}
  end

  # Request routing

  defp route_request("initialize", params, state) do
    handle_initialize(params, state)
  end

  defp route_request("tools/list", _params, state) do
    handle_list_tools(state)
  end

  defp route_request("tools/call", params, state) do
    handle_call_tool(params, state)
  end

  defp route_request("resources/list", _params, state) do
    handle_list_resources(state)
  end

  defp route_request("resources/read", params, state) do
    handle_read_resource(params, state)
  end

  defp route_request("resources/subscribe", params, state) do
    handle_subscribe_resource(params, state)
  end

  defp route_request("resources/unsubscribe", params, state) do
    handle_unsubscribe_resource(params, state)
  end

  defp route_request("prompts/list", _params, state) do
    handle_list_prompts(state)
  end

  defp route_request("prompts/get", params, state) do
    handle_get_prompt(params, state)
  end

  defp route_request("completion/complete", params, state) do
    handle_completion(params, state)
  end

  defp route_request("ping", _params, _state) do
    {:ok, %{}}
  end

  defp route_request(method, _params, _state) do
    Logger.warn("Unknown method: #{method}")
    {:error, {-32601, "Method not found", %{method: method}}}
  end

  # Notification processing

  defp process_notification("notifications/cancelled", params, state) do
    Logger.info("Received cancellation: #{inspect(params)}")
    # Handle request cancellation if needed
    case Map.get(params, "requestId") do
      nil -> state
      request_id ->
        # Cancel pending request if exists
        case Map.get(state.pending_requests, request_id) do
          nil -> state
          %{from: from} ->
            GenServer.reply(from, {:error, :cancelled})
            %{state | pending_requests: Map.delete(state.pending_requests, request_id)}
        end
    end
  end

  defp process_notification("notifications/progress", params, state) do
    Logger.debug("Progress update: #{inspect(params)}")
    # Forward progress updates to handlers if needed
    state
  end

  defp process_notification("notifications/resources/updated", params, state) do
    Logger.debug("Resource updated: #{inspect(params)}")
    # Handle resource update notifications
    state
  end

  defp process_notification("notifications/resources/list_changed", _params, state) do
    Logger.debug("Resource list changed")
    # Handle resource list changes
    state
  end

  defp process_notification(method, params, state) do
    Logger.debug("Unhandled notification: #{method} with params: #{inspect(params)}")
    state
  end

  # Helper functions

  defp process_batch_request(%Request{method: method, params: params, id: id}, state) do
    case route_request(method, params, state) do
      {:ok, result} ->
        JsonRpc.build_jsonrpc_response(result, id)

      {:error, {code, message, data}} ->
        JsonRpc.build_jsonrpc_error(code, message, id, data)

      {:error, reason} ->
        Logger.error("Batch request processing error: #{inspect(reason)}")
        JsonRpc.internal_error(id, inspect(reason))
    end
  end

  defp maybe_send_parse_error(json_string, state) do
    # Try to extract ID from malformed JSON for error response
    case Regex.run(~r/"id"\s*:\s*(\d+|"[^"]*")/, json_string) do
      [_, id_str] ->
        id = case Integer.parse(id_str) do
          {int_id, ""} -> int_id
          _ -> String.trim(id_str, "\"")
        end
        error_response = JsonRpc.parse_error(id)
        case JsonRpc.encode_jsonrpc_message(error_response) do
          {:ok, json} -> send(state.transport, {:send, json})
          {:error, _} -> :ok # Can't send anything
        end
      _ ->
        # No ID found, send error without ID
        error_response = JsonRpc.parse_error(nil)
        case JsonRpc.encode_jsonrpc_message(error_response) do
          {:ok, json} -> send(state.transport, {:send, json})
          {:error, _} -> :ok # Can't send anything
        end
    end
  end

  # Handler implementations

  defp handle_initialize(params, state) do
    Logger.info("Initializing MCP connection with params: #{inspect(params)}")

    response = Messages.initialize_response(
      "2024-11-05",  # Protocol version
      state.capabilities,
      %{
        name: "VSM-MCP",
        version: "1.0.0"
      }
    )

    {:ok, response}
  end

  defp handle_list_tools(state) do
    tools =
      state.handlers
      |> Map.get(:tools, %{})
      |> Enum.map(fn {name, handler} ->
        %{
          name: name,
          description: handler.description,
          inputSchema: handler.input_schema
        }
      end)

    {:ok, %{tools: tools}}
  end

  defp handle_call_tool(%{"name" => name, "arguments" => arguments}, state) do
    case Map.get(state.handlers[:tools] || %{}, name) do
      nil ->
        {:error, {Messages.error_code(:tool_not_found), "Tool not found", %{tool: name}}}

      handler ->
        try do
          case handler.execute(arguments) do
            {:ok, result} ->
              {:ok, %{content: [%{type: "text", text: result}]}}

            {:error, reason} ->
              {:error, {-32603, "Tool execution failed", %{reason: inspect(reason)}}}
          end
        rescue
          error ->
            Logger.error("Tool execution exception: #{inspect(error)}")
            {:error, {-32603, "Tool execution exception", %{error: inspect(error)}}}
        end
    end
  end

  defp handle_list_resources(state) do
    resources =
      state.handlers
      |> Map.get(:resources, %{})
      |> Enum.map(fn {uri, handler} ->
        %{
          uri: uri,
          name: handler.name,
          description: handler.description,
          mimeType: handler.mime_type
        }
      end)

    {:ok, %{resources: resources}}
  end

  defp handle_read_resource(%{"uri" => uri}, state) do
    case Map.get(state.handlers[:resources] || %{}, uri) do
      nil ->
        {:error, {Messages.error_code(:resource_not_found), "Resource not found", %{uri: uri}}}

      handler ->
        try do
          case handler.read() do
            {:ok, content} ->
              {:ok, %{
                contents: [
                  %{
                    uri: uri,
                    mimeType: handler.mime_type,
                    text: content
                  }
                ]
              }}

            {:error, reason} ->
              {:error, {-32603, "Resource read failed", %{reason: inspect(reason)}}}
          end
        rescue
          error ->
            Logger.error("Resource read exception: #{inspect(error)}")
            {:error, {-32603, "Resource read exception", %{error: inspect(error)}}}
        end
    end
  end

  defp handle_subscribe_resource(%{"uri" => uri}, state) do
    # Add to subscriptions
    new_state = %{state | subscriptions: Map.put(state.subscriptions, uri, true)}
    {:ok, %{}, new_state}
  end

  defp handle_unsubscribe_resource(%{"uri" => uri}, state) do
    # Remove from subscriptions
    new_state = %{state | subscriptions: Map.delete(state.subscriptions, uri)}
    {:ok, %{}, new_state}
  end

  defp handle_list_prompts(state) do
    prompts =
      state.handlers
      |> Map.get(:prompts, %{})
      |> Enum.map(fn {name, handler} ->
        %{
          name: name,
          description: handler.description,
          arguments: handler.arguments || []
        }
      end)

    {:ok, %{prompts: prompts}}
  end

  defp handle_get_prompt(%{"name" => name, "arguments" => arguments}, state) do
    case Map.get(state.handlers[:prompts] || %{}, name) do
      nil ->
        {:error, {-32602, "Prompt not found", %{prompt: name}}}

      handler ->
        case handler.get(arguments) do
          {:ok, messages} ->
            {:ok, %{messages: messages}}

          {:error, reason} ->
            {:error, {-32603, "Prompt generation failed", %{reason: inspect(reason)}}}
        end
    end
  end

  defp handle_completion(params, state) do
    # TODO: Implement completion handling
    {:ok, %{
      completion: %{
        values: [],
        total: 0,
        hasMore: false
      }
    }}
  end
end