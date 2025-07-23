defmodule VsmMcp.MCP.Transports.Stdio do
  @moduledoc """
  Standard I/O transport for MCP protocol.
  Reads from stdin and writes to stdout with proper framing.
  """

  use GenServer
  require Logger

  defstruct [:handler, :buffer]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      handler: opts[:handler],
      buffer: ""
    }

    # Start reading from stdin
    {:ok, _} = Task.start_link(fn -> read_loop(self()) end)

    {:ok, state}
  end

  @impl true
  def handle_info({:send, message}, state) do
    # Write to stdout with newline delimiter
    IO.puts(message)
    {:noreply, state}
  end

  @impl true
  def handle_info({:stdin, data}, state) do
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
  def handle_info({:stdin_closed}, state) do
    Logger.info("STDIN closed, shutting down")
    {:stop, :normal, state}
  end

  # Private functions

  defp read_loop(parent) do
    case IO.read(:stdio, :line) do
      :eof ->
        send(parent, {:stdin_closed})

      {:error, reason} ->
        Logger.error("Error reading from stdin: #{inspect(reason)}")
        send(parent, {:stdin_closed})

      data ->
        send(parent, {:stdin, data})
        read_loop(parent)
    end
  end

  defp extract_messages(buffer) do
    lines = String.split(buffer, "\n", trim: false)

    case List.pop_at(lines, -1) do
      {incomplete, complete_lines} ->
        # Filter out empty lines but keep the messages
        messages = Enum.filter(complete_lines, &(&1 != ""))
        {messages, incomplete || ""}
    end
  end
end