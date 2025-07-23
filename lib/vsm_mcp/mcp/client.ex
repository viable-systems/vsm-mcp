defmodule VsmMcp.MCP.Client do
  @moduledoc """
  MCP client for connecting to external MCP servers.
  Handles protocol negotiation, capability discovery, and remote tool/resource access.
  """

  use GenServer
  alias VsmMcp.MCP.Protocol.{Handler, Messages}
  alias VsmMcp.MCP.Transports
  require Logger

  defstruct [
    :name,
    :transport_type,
    :transport,
    :handler,
    :connection_params,
    :state,
    :server_info,
    :server_capabilities,
    :tools,
    :resources,
    :prompts
  ]

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def connect(client) do
    GenServer.call(client, :connect, 30_000)
  end

  def disconnect(client) do
    GenServer.call(client, :disconnect)
  end

  def list_tools(client) do
    GenServer.call(client, :list_tools)
  end

  def call_tool(client, name, arguments) do
    GenServer.call(client, {:call_tool, name, arguments}, 30_000)
  end

  def list_resources(client) do
    GenServer.call(client, :list_resources)
  end

  def read_resource(client, uri) do
    GenServer.call(client, {:read_resource, uri})
  end

  def subscribe_resource(client, uri) do
    GenServer.call(client, {:subscribe_resource, uri})
  end

  def list_prompts(client) do
    GenServer.call(client, :list_prompts)
  end

  def get_prompt(client, name, arguments \\ %{}) do
    GenServer.call(client, {:get_prompt, name, arguments})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      name: opts[:name] || "vsm-mcp-client",
      transport_type: opts[:transport] || :stdio,
      connection_params: opts[:connection] || %{},
      state: :disconnected,
      tools: %{},
      resources: %{},
      prompts: %{}
    }

    # Auto-connect if requested
    state =
      if opts[:auto_connect] do
        case do_connect(state) do
          {:ok, connected_state} ->
            connected_state

          {:error, reason} ->
            Logger.error("Auto-connect failed: #{inspect(reason)}")
            state
        end
      else
        state
      end

    {:ok, state}
  end

  @impl true
  def handle_call(:connect, _from, state) do
    case do_connect(state) do
      {:ok, connected_state} ->
        {:reply, :ok, connected_state}

      {:error, reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:disconnect, _from, state) do
    if state.transport do
      GenServer.stop(state.transport)
    end

    if state.handler do
      GenServer.stop(state.handler)
    end

    {:reply, :ok, %{state | state: :disconnected, transport: nil, handler: nil}}
  end

  @impl true
  def handle_call(:list_tools, _from, %{state: :connected} = state) do
    case Handler.send_request(state.handler, "tools/list", %{}) do
      {:ok, %{"tools" => tools}} ->
        # Cache tools
        tools_map =
          tools
          |> Enum.map(fn tool ->
            {tool["name"], tool}
          end)
          |> Map.new()

        {:reply, {:ok, tools}, %{state | tools: tools_map}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:call_tool, name, arguments}, _from, %{state: :connected} = state) do
    case Handler.send_request(state.handler, "tools/call", %{
      "name" => name,
      "arguments" => arguments
    }) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:list_resources, _from, %{state: :connected} = state) do
    case Handler.send_request(state.handler, "resources/list", %{}) do
      {:ok, %{"resources" => resources}} ->
        # Cache resources
        resources_map =
          resources
          |> Enum.map(fn resource ->
            {resource["uri"], resource}
          end)
          |> Map.new()

        {:reply, {:ok, resources}, %{state | resources: resources_map}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:read_resource, uri}, _from, %{state: :connected} = state) do
    case Handler.send_request(state.handler, "resources/read", %{"uri" => uri}) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:subscribe_resource, uri}, _from, %{state: :connected} = state) do
    case Handler.send_request(state.handler, "resources/subscribe", %{"uri" => uri}) do
      {:ok, _} ->
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:list_prompts, _from, %{state: :connected} = state) do
    case Handler.send_request(state.handler, "prompts/list", %{}) do
      {:ok, %{"prompts" => prompts}} ->
        # Cache prompts
        prompts_map =
          prompts
          |> Enum.map(fn prompt ->
            {prompt["name"], prompt}
          end)
          |> Map.new()

        {:reply, {:ok, prompts}, %{state | prompts: prompts_map}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_prompt, name, arguments}, _from, %{state: :connected} = state) do
    case Handler.send_request(state.handler, "prompts/get", %{
      "name" => name,
      "arguments" => arguments
    }) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(_, _from, %{state: :disconnected} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  @impl true
  def handle_info({:transport_connected}, state) do
    Logger.info("Transport connected, initializing protocol")
    
    # Send initialize request
    case Handler.send_request(state.handler, "initialize", Messages.initialize_request(
      "2024-11-05",
      %{
        tools: %{},
        resources: %{
          subscribe: true,
          unsubscribe: true
        },
        prompts: %{},
        completion: %{}
      },
      %{
        name: state.name,
        version: "1.0.0"
      }
    )[:params]) do
      {:ok, response} ->
        Logger.info("MCP initialized successfully: #{inspect(response)}")
        
        new_state = %{state |
          state: :connected,
          server_info: response["serverInfo"],
          server_capabilities: response["capabilities"]
        }

        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to initialize: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:transport_disconnected}, state) do
    Logger.info("Transport disconnected")
    {:noreply, %{state | state: :disconnected}}
  end

  # Private functions

  defp do_connect(state) do
    # Start handler
    {:ok, handler} = Handler.start_link(
      transport: self(),
      capabilities: %{
        tools: %{},
        resources: %{
          subscribe: true,
          unsubscribe: true
        },
        prompts: %{},
        completion: %{}
      }
    )

    # Start transport based on type
    transport_result =
      case state.transport_type do
        :stdio ->
          Transports.Stdio.start_link(handler: handler)

        :tcp ->
          {:ok, transport} = Transports.Tcp.start_link(
            handler: handler,
            mode: :client,
            host: state.connection_params[:host] || "localhost",
            port: state.connection_params[:port] || 3333
          )

          # Connect to server
          case Transports.Tcp.connect(transport, 
            state.connection_params[:host] || "localhost",
            state.connection_params[:port] || 3333
          ) do
            :ok ->
              {:ok, transport}

            error ->
              GenServer.stop(transport)
              error
          end

        :websocket ->
          {:ok, transport} = Transports.WebSocket.start_link(handler: handler)
          
          url = state.connection_params[:url] || "ws://localhost:3333/mcp"
          
          case Transports.WebSocket.connect(transport, url) do
            :ok ->
              {:ok, transport}

            error ->
              GenServer.stop(transport)
              error
          end
      end

    case transport_result do
      {:ok, transport} ->
        # Notify self when connected
        send(self(), {:transport_connected})

        {:ok, %{state |
          transport: transport,
          handler: handler
        }}

      {:error, reason} ->
        GenServer.stop(handler)
        {:error, reason}
    end
  end
end