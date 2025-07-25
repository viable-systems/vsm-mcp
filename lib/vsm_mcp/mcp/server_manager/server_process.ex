defmodule VsmMcp.MCP.ServerManager.ServerProcess do
  @moduledoc """
  Represents and manages an individual MCP server process.
  """
  
  require Logger
  
  @type status :: :starting | :running | :stopping | :stopped | :crashed
  @type health_status :: :healthy | :unhealthy | :degraded | :unknown
  
  @type t :: %__MODULE__{
    id: String.t(),
    config: VsmMcp.MCP.ServerManager.ServerConfig.t(),
    pid: pid() | nil,
    port: port() | nil,
    os_pid: pos_integer() | nil,
    status: status(),
    started_at: DateTime.t() | nil,
    stopped_at: DateTime.t() | nil,
    crashed_at: DateTime.t() | nil,
    crash_reason: term() | nil,
    monitor_ref: reference() | nil,
    restart_count: non_neg_integer(),
    health_status: health_status(),
    last_health_check: DateTime.t() | nil,
    consecutive_failures: non_neg_integer(),
    metrics: map()
  }
  
  defstruct [
    :id,
    :config,
    :pid,
    :port,
    :os_pid,
    :status,
    :started_at,
    :stopped_at,
    :crashed_at,
    :crash_reason,
    :monitor_ref,
    :restart_count,
    :health_status,
    :last_health_check,
    :consecutive_failures,
    :metrics
  ]
  
  @doc """
  Start an external MCP server process.
  """
  def start_external(config) do
    # Build command with proper escaping
    cmd = build_command(config)
    
    # Set up port options
    port_opts = [
      :binary,
      :exit_status,
      :use_stdio,
      :hide,
      {:packet, 4},
      {:env, build_env(config)},
      {:cd, config.working_dir || File.cwd!()}
    ]
    
    # Add stderr_to_stdout for better error capture
    port_opts = [:stderr_to_stdout | port_opts]
    
    try do
      port = Port.open({:spawn_executable, cmd}, [{:args, config.args} | port_opts])
      
      # Get OS PID if possible
      os_pid = case :erlang.port_info(port, :os_pid) do
        {:os_pid, pid} -> pid
        _ -> nil
      end
      
      # Start a GenServer to manage the port
      {:ok, pid} = ExternalServerProcess.start_link(
        port: port,
        config: config,
        os_pid: os_pid
      )
      
      {:ok, %{pid: pid, port: port, os_pid: os_pid}}
    catch
      :error, reason ->
        {:error, {:failed_to_start, reason}}
    end
  end
  
  @doc """
  Stop a server process gracefully.
  """
  def stop(process, opts \\ []) do
    timeout = opts[:timeout] || 5_000
    force = opts[:force] || false
    
    cond do
      process.pid && Process.alive?(process.pid) ->
        if force do
          Process.exit(process.pid, :kill)
        else
          try do
            GenServer.stop(process.pid, :shutdown, timeout)
          catch
            :exit, _ -> :ok
          end
        end
        
      process.port ->
        Port.close(process.port)
        
      process.os_pid ->
        # Last resort: kill OS process
        System.cmd("kill", ["-TERM", to_string(process.os_pid)])
        
      true ->
        :ok
    end
  end
  
  @doc """
  Check if process is alive.
  """
  def alive?(process) do
    cond do
      process.pid && Process.alive?(process.pid) -> true
      process.port && port_alive?(process.port) -> true
      process.os_pid && os_process_alive?(process.os_pid) -> true
      true -> false
    end
  end
  
  @doc """
  Get process metrics.
  """
  def get_metrics(process) do
    base_metrics = %{
      uptime: calculate_uptime(process),
      restart_count: process.restart_count,
      health_status: process.health_status,
      status: process.status
    }
    
    # Add runtime metrics if process is alive
    if process.pid && Process.alive?(process.pid) do
      case Process.info(process.pid, [:memory, :message_queue_len, :reductions]) do
        nil ->
          base_metrics
          
        info ->
          Map.merge(base_metrics, %{
            memory: info[:memory],
            message_queue_len: info[:message_queue_len],
            reductions: info[:reductions]
          })
      end
    else
      base_metrics
    end
  end
  
  # Private functions
  
  defp build_command(config) do
    # Handle complex commands (e.g., "npx something")
    case String.split(config.command, " ", parts: 2) do
      [cmd] ->
        System.find_executable(cmd) || config.command
        
      [cmd, _args] ->
        # For commands like "npx package", use shell
        case :os.type() do
          {:unix, _} -> System.find_executable("sh") || "/bin/sh"
          {:win32, _} -> System.find_executable("cmd") || "cmd.exe"
        end
    end
  end
  
  defp build_env(config) do
    config.env
    |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)
  end
  
  defp port_alive?(port) do
    case :erlang.port_info(port) do
      :undefined -> false
      _ -> true
    end
  end
  
  defp os_process_alive?(os_pid) do
    case System.cmd("kill", ["-0", to_string(os_pid)], stderr_to_stdout: true) do
      {"", 0} -> true
      _ -> false
    end
  end
  
  defp calculate_uptime(%{started_at: nil}), do: 0
  defp calculate_uptime(%{started_at: started_at, stopped_at: nil}) do
    DateTime.diff(DateTime.utc_now(), started_at, :second)
  end
  defp calculate_uptime(%{started_at: started_at, stopped_at: stopped_at}) do
    DateTime.diff(stopped_at, started_at, :second)
  end
end

defmodule VsmMcp.MCP.ServerManager.ExternalServerProcess do
  @moduledoc """
  GenServer that manages an external MCP server process via Port.
  """
  
  use GenServer
  require Logger
  
  defstruct [:port, :config, :os_pid, :buffer, :callbacks]
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def send_message(pid, message) do
    GenServer.call(pid, {:send_message, message})
  end
  
  def register_callback(pid, callback) do
    GenServer.cast(pid, {:register_callback, callback})
  end
  
  @impl true
  def init(opts) do
    state = %__MODULE__{
      port: opts[:port],
      config: opts[:config],
      os_pid: opts[:os_pid],
      buffer: "",
      callbacks: []
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:send_message, message}, _from, state) do
    data = Jason.encode!(message)
    Port.command(state.port, data)
    {:reply, :ok, state}
  end
  
  @impl true
  def handle_cast({:register_callback, callback}, state) do
    {:noreply, %{state | callbacks: [callback | state.callbacks]}}
  end
  
  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    # Handle incoming data from the port
    {messages, new_buffer} = decode_messages(state.buffer <> data)
    
    # Process each complete message
    Enum.each(messages, fn msg ->
      Logger.debug("Received from MCP server: #{inspect(msg)}")
      
      # Notify callbacks
      Enum.each(state.callbacks, fn callback ->
        callback.(msg)
      end)
    end)
    
    {:noreply, %{state | buffer: new_buffer}}
  end
  
  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.info("MCP server exited with status: #{status}")
    {:stop, {:server_exited, status}, state}
  end
  
  @impl true
  def handle_info({:EXIT, port, reason}, %{port: port} = state) do
    Logger.error("MCP server port died: #{inspect(reason)}")
    {:stop, {:port_died, reason}, state}
  end
  
  @impl true
  def terminate(reason, state) do
    Logger.info("Terminating external server process: #{inspect(reason)}")
    
    if state.port && port_alive?(state.port) do
      Port.close(state.port)
    end
    
    :ok
  end
  
  # Private functions
  
  defp decode_messages(data) do
    # Try to decode JSON-RPC messages separated by newlines
    lines = String.split(data, "\n", trim: true)
    
    {messages, incomplete} = Enum.reduce(lines, {[], ""}, fn line, {msgs, buffer} ->
      case Jason.decode(buffer <> line) do
        {:ok, msg} ->
          {[msg | msgs], ""}
          
        {:error, _} ->
          # Incomplete message, keep buffering
          {msgs, buffer <> line}
      end
    end)
    
    {Enum.reverse(messages), incomplete}
  end
  
  defp port_alive?(port) do
    case :erlang.port_info(port) do
      :undefined -> false
      _ -> true
    end
  end
end