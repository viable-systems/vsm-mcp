defmodule VsmMcp.MCP.Transports.WebSocket do
  @moduledoc """
  WebSocket transport for MCP protocol.
  Uses Cowboy for WebSocket server implementation.
  """

  use GenServer
  require Logger

  defstruct [:handler, :mode, :connection, :host, :port, :path]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def listen(transport, port, path \\ "/mcp") do
    GenServer.call(transport, {:listen, port, path})
  end

  def connect(transport, url) do
    GenServer.call(transport, {:connect, url})
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      handler: opts[:handler],
      mode: opts[:mode] || :client,
      host: opts[:host],
      port: opts[:port],
      path: opts[:path] || "/mcp"
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:listen, port, path}, _from, state) do
    # Start Cowboy WebSocket server
    dispatch = :cowboy_router.compile([
      {:_, [
        {path, VsmMcp.MCP.Transports.WebSocket.Handler, %{parent: self(), handler: state.handler}}
      ]}
    ])

    case :cowboy.start_clear(:mcp_websocket, [{:port, port}], %{env: %{dispatch: dispatch}}) do
      {:ok, _} ->
        Logger.info("WebSocket server listening on port #{port} at path #{path}")
        {:reply, :ok, %{state | mode: :server, port: port, path: path}}

      {:error, reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:connect, url}, _from, state) do
    case connect_websocket(url) do
      {:ok, connection} ->
        {:reply, :ok, %{state | connection: connection}}

      {:error, reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_info({:send, message}, state) do
    if state.connection do
      # Send via WebSocket
      send_websocket(state.connection, message)
    else
      Logger.warn("Attempted to send message without active WebSocket connection")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:websocket_message, message}, state) do
    # Forward to handler
    send(state.handler, {:message, message})
    {:noreply, state}
  end

  @impl true
  def handle_info({:websocket_closed}, state) do
    Logger.info("WebSocket connection closed")
    {:noreply, %{state | connection: nil}}
  end

  # Private functions

  defp connect_websocket(url) do
    # Parse URL
    uri = URI.parse(url)
    host = uri.host || "localhost"
    port = uri.port || 80
    path = uri.path || "/"

    # Use Gun for WebSocket client
    case :gun.open(String.to_charlist(host), port) do
      {:ok, conn_pid} ->
        # Upgrade to WebSocket
        stream_ref = :gun.ws_upgrade(conn_pid, path)
        
        receive do
          {:gun_upgrade, ^conn_pid, ^stream_ref, ["websocket"], _headers} ->
            {:ok, conn_pid}

          {:gun_error, ^conn_pid, ^stream_ref, reason} ->
            :gun.close(conn_pid)
            {:error, reason}
        after
          5000 ->
            :gun.close(conn_pid)
            {:error, :timeout}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp send_websocket(conn_pid, message) do
    :gun.ws_send(conn_pid, {:text, message})
  end
end

defmodule VsmMcp.MCP.Transports.WebSocket.Handler do
  @moduledoc """
  Cowboy WebSocket handler for MCP protocol.
  """

  @behaviour :cowboy_websocket

  require Logger

  @impl true
  def init(req, state) do
    {:cowboy_websocket, req, state}
  end

  @impl true
  def websocket_init(state) do
    Logger.info("WebSocket connection established")
    {:ok, state}
  end

  @impl true
  def websocket_handle({:text, message}, state) do
    # Forward message to parent process
    send(state.parent, {:websocket_message, message})
    {:ok, state}
  end

  @impl true
  def websocket_handle(_frame, state) do
    {:ok, state}
  end

  @impl true
  def websocket_info({:send, message}, state) do
    {:reply, {:text, message}, state}
  end

  @impl true
  def websocket_info(_info, state) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, _req, _state) do
    :ok
  end
end