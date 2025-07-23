defmodule VsmMcp.MCP.Protocol.Handler do
  @moduledoc """
  MCP protocol handler that processes JSON-RPC messages and routes them to appropriate handlers.
  """

  alias VsmMcp.MCP.Protocol.{JsonRpc, Messages}
  require Logger

  @behaviour GenServer

  defstruct [
    :transport,
    :state,
    :capabilities,
    :handlers,
    :subscriptions,
    :pending_requests,
    :next_id
  ]

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
    state = %__MODULE__{
      transport: opts[:transport],
      state: :uninitialized,
      capabilities: opts[:capabilities] || %{},
      handlers: opts[:handlers] || %{},
      subscriptions: %{},
      pending_requests: %{},
      next_id: 1
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:send_request, method, params}, from, state) do
    id = state.next_id
    request = JsonRpc.request(method, params, id)

    case JsonRpc.encode(request) do
      {:ok, json} ->
        send(state.transport, {:send, json})
        
        new_state = %{state |
          pending_requests: Map.put(state.pending_requests, id, from),
          next_id: id + 1
        }
        
        {:noreply, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:send_notification, method, params}, state) do
    notification = JsonRpc.notification(method, params)

    case JsonRpc.encode(notification) do
      {:ok, json} ->
        send(state.transport, {:send, json})

      {:error, reason} ->
        Logger.error("Failed to encode notification: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:message, json_string}, state) do
    case JsonRpc.parse(json_string) do
      {:ok, %JsonRpc{} = request} ->
        handle_request(request, state)

      {:ok, %JsonRpc.Response{} = response} ->
        handle_response(response, state)

      {:error, reason} ->
        Logger.error("Failed to parse message: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  # Request handling

  defp handle_request(%JsonRpc{method: method, params: params, id: id} = request, state) do
    Logger.debug("Handling request: #{method}")

    result =
      case route_request(method, params, state) do
        {:ok, result} ->
          JsonRpc.success_response(result, id)

        {:error, {code, message, data}} ->
          JsonRpc.error_response(code, message, id, data)

        {:error, reason} ->
          JsonRpc.internal_error(id, inspect(reason))
      end

    case JsonRpc.encode(result) do
      {:ok, json} ->
        send(state.transport, {:send, json})

      {:error, reason} ->
        Logger.error("Failed to encode response: #{inspect(reason)}")
    end

    # Handle notifications (no ID means notification)
    state =
      if is_nil(id) do
        handle_notification(method, params, state)
      else
        state
      end

    {:noreply, state}
  end

  defp handle_response(%JsonRpc.Response{id: id} = response, state) do
    case Map.pop(state.pending_requests, id) do
      {nil, _} ->
        Logger.warn("Received response for unknown request ID: #{id}")
        {:noreply, state}

      {from, pending_requests} ->
        result =
          if response.error do
            {:error, response.error}
          else
            {:ok, response.result}
          end

        GenServer.reply(from, result)
        {:noreply, %{state | pending_requests: pending_requests}}
    end
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
    {:error, {JsonRpc.method_not_found(method), "Method not found", %{method: method}}}
  end

  # Notification handling

  defp handle_notification("notifications/cancelled", params, state) do
    Logger.info("Received cancellation: #{inspect(params)}")
    state
  end

  defp handle_notification("notifications/progress", params, state) do
    Logger.debug("Progress update: #{inspect(params)}")
    state
  end

  defp handle_notification(method, params, state) do
    Logger.debug("Unhandled notification: #{method} with params: #{inspect(params)}")
    state
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
        case handler.execute(arguments) do
          {:ok, result} ->
            {:ok, %{content: [%{type: "text", text: result}]}}

          {:error, reason} ->
            {:error, {-32603, "Tool execution failed", %{reason: inspect(reason)}}}
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