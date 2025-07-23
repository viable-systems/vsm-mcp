defmodule VsmMcp.MCP.Transports.Tcp do
  @moduledoc """
  TCP transport for MCP protocol.
  Supports both client and server modes with message framing.
  """

  use GenServer
  require Logger

  defstruct [:handler, :socket, :mode, :buffer, :port, :host]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def listen(transport, port) do
    GenServer.call(transport, {:listen, port})
  end

  def connect(transport, host, port) do
    GenServer.call(transport, {:connect, host, port})
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      handler: opts[:handler],
      mode: opts[:mode] || :client,
      buffer: "",
      port: opts[:port],
      host: opts[:host] || "localhost"
    }

    # Auto-connect if in client mode with host/port
    state =
      if state.mode == :client and state.host and state.port do
        case do_connect(state.host, state.port) do
          {:ok, socket} ->
            %{state | socket: socket}

          {:error, reason} ->
            Logger.error("Failed to connect: #{inspect(reason)}")
            state
        end
      else
        state
      end

    {:ok, state}
  end

  @impl true
  def handle_call({:listen, port}, _from, state) do
    case :gen_tcp.listen(port, [
      :binary,
      packet: :line,
      active: true,
      reuseaddr: true
    ]) do
      {:ok, listen_socket} ->
        # Accept connections in a separate process
        spawn_link(fn -> accept_loop(listen_socket, self()) end)
        {:reply, :ok, %{state | socket: listen_socket, mode: :server, port: port}}

      {:error, reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:connect, host, port}, _from, state) do
    case do_connect(host, port) do
      {:ok, socket} ->
        {:reply, :ok, %{state | socket: socket, host: host, port: port}}

      {:error, reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_info({:send, message}, state) do
    if state.socket do
      # Add newline delimiter
      :gen_tcp.send(state.socket, message <> "\n")
    else
      Logger.warn("Attempted to send message without active socket")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp, socket, data}, state) do
    # Accumulate data in buffer
    buffer = state.buffer <> data

    # Process complete messages (newline delimited)
    {messages, remaining} = extract_messages(buffer)

    # Send each complete message to handler
    Enum.each(messages, fn msg ->
      send(state.handler, {:message, msg})
    end)

    {:noreply, %{state | buffer: remaining}}
  end

  @impl true
  def handle_info({:tcp_closed, socket}, state) do
    Logger.info("TCP connection closed")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:tcp_error, socket, reason}, state) do
    Logger.error("TCP error: #{inspect(reason)}")
    {:stop, reason, state}
  end

  @impl true
  def handle_info({:new_connection, client_socket}, state) do
    # For server mode, handle new client connection
    Logger.info("New client connection accepted")
    
    # You might want to spawn a new handler for each client
    # For now, we'll just update the socket
    {:noreply, %{state | socket: client_socket}}
  end

  # Private functions

  defp do_connect(host, port) do
    host_charlist = String.to_charlist(host)
    
    :gen_tcp.connect(host_charlist, port, [
      :binary,
      packet: :line,
      active: true
    ])
  end

  defp accept_loop(listen_socket, parent) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        send(parent, {:new_connection, client_socket})
        accept_loop(listen_socket, parent)

      {:error, reason} ->
        Logger.error("Accept error: #{inspect(reason)}")
    end
  end

  defp extract_messages(buffer) do
    lines = String.split(buffer, "\n", trim: false)

    case List.pop_at(lines, -1) do
      {incomplete, complete_lines} ->
        messages = Enum.filter(complete_lines, &(&1 != ""))
        {messages, incomplete || ""}
    end
  end
end