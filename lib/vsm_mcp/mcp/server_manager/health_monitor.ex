defmodule VsmMcp.MCP.ServerManager.HealthMonitor do
  @moduledoc """
  Health monitoring for MCP servers with various check strategies.
  """
  
  use GenServer
  require Logger
  
  defstruct [
    :manager,
    :servers,
    :check_interval,
    :check_timers
  ]
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def register_server(monitor, server_id, pid) do
    GenServer.cast(monitor, {:register_server, server_id, pid})
  end
  
  def unregister_server(monitor, server_id) do
    GenServer.cast(monitor, {:unregister_server, server_id})
  end
  
  def check_health(monitor, server_id) do
    GenServer.call(monitor, {:check_health, server_id})
  end
  
  def get_status(monitor) do
    GenServer.call(monitor, :get_status)
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    state = %__MODULE__{
      manager: opts[:manager],
      servers: %{},
      check_interval: opts[:check_interval] || 30_000,
      check_timers: %{}
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:register_server, server_id, pid}, state) do
    # Cancel existing timer if any
    case Map.get(state.check_timers, server_id) do
      nil -> :ok
      timer -> Process.cancel_timer(timer)
    end
    
    # Schedule first health check
    timer = schedule_health_check(server_id, state.check_interval)
    
    new_state = %{state |
      servers: Map.put(state.servers, server_id, pid),
      check_timers: Map.put(state.check_timers, server_id, timer)
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:unregister_server, server_id}, state) do
    # Cancel health check timer
    case Map.get(state.check_timers, server_id) do
      nil -> :ok
      timer -> Process.cancel_timer(timer)
    end
    
    new_state = %{state |
      servers: Map.delete(state.servers, server_id),
      check_timers: Map.delete(state.check_timers, server_id)
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call({:check_health, server_id}, _from, state) do
    case Map.get(state.servers, server_id) do
      nil ->
        {:reply, {:error, :server_not_registered}, state}
        
      pid ->
        result = perform_health_check(server_id, pid, state)
        {:reply, {:ok, result}, state}
    end
  end
  
  @impl true
  def handle_call(:get_status, _from, state) do
    status = Enum.map(state.servers, fn {server_id, pid} ->
      {server_id, %{
        pid: pid,
        alive: Process.alive?(pid),
        next_check: get_next_check_time(server_id, state)
      }}
    end)
    |> Map.new()
    
    {:reply, {:ok, status}, state}
  end
  
  @impl true
  def handle_info({:perform_health_check, server_id}, state) do
    case Map.get(state.servers, server_id) do
      nil ->
        # Server was unregistered
        {:noreply, state}
        
      pid ->
        # Perform health check
        result = perform_health_check(server_id, pid, state)
        
        # Notify manager
        if state.manager do
          send(state.manager, {:health_check_result, server_id, result})
        end
        
        # Schedule next check
        timer = schedule_health_check(server_id, state.check_interval)
        new_state = %{state | check_timers: Map.put(state.check_timers, server_id, timer)}
        
        {:noreply, new_state}
    end
  end
  
  # Private functions
  
  defp schedule_health_check(server_id, interval) do
    Process.send_after(self(), {:perform_health_check, server_id}, interval)
  end
  
  defp perform_health_check(server_id, pid, state) do
    # First check if process is alive
    if not Process.alive?(pid) do
      :unhealthy
    else
      # Get server config from manager to determine check type
      case get_server_config(server_id, state) do
        nil ->
          # Basic process check
          basic_health_check(pid)
          
        config ->
          # Perform specific health check based on config
          perform_specific_health_check(config, pid)
      end
    end
  end
  
  defp basic_health_check(pid) do
    # Simple process-based health check
    case Process.info(pid, [:status, :message_queue_len, :memory]) do
      nil ->
        :unhealthy
        
      info ->
        cond do
          info[:message_queue_len] > 1000 -> :degraded
          info[:memory] > 100_000_000 -> :degraded  # 100MB
          info[:status] == :suspended -> :unhealthy
          true -> :healthy
        end
    end
  end
  
  defp perform_specific_health_check(config, pid) do
    case config.health_check[:type] do
      :stdio ->
        check_stdio_health(config, pid)
        
      :tcp ->
        check_tcp_health(config)
        
      :websocket ->
        check_websocket_health(config)
        
      :custom ->
        check_custom_health(config, pid)
        
      _ ->
        basic_health_check(pid)
    end
  end
  
  defp check_stdio_health(config, pid) do
    # Send a health check message through stdio
    message = config.health_check[:health_message] || %{
      jsonrpc: "2.0",
      method: "health",
      params: %{},
      id: :erlang.unique_integer()
    }
    
    try do
      case GenServer.call(pid, {:send_message, message}, 5_000) do
        :ok -> :healthy
        _ -> :unhealthy
      end
    catch
      :exit, _ -> :unhealthy
    end
  end
  
  defp check_tcp_health(config) do
    port = config.health_check[:port] || 3333
    timeout = config.health_check[:timeout_ms] || 5_000
    
    case :gen_tcp.connect('localhost', port, [:binary, active: false], timeout) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :healthy
        
      {:error, _reason} ->
        :unhealthy
    end
  end
  
  defp check_websocket_health(config) do
    url = config.health_check[:url]
    timeout = config.health_check[:timeout_ms] || 5_000
    
    # Simple WebSocket ping
    case :httpc.request(:get, {String.to_charlist(url), []}, [{:timeout, timeout}], []) do
      {:ok, _} -> :healthy
      _ -> :unhealthy
    end
  end
  
  defp check_custom_health(config, pid) do
    check_fn = config.health_check[:check_fn]
    
    if is_function(check_fn) do
      try do
        case check_fn.(pid) do
          {:ok, status} when status in [:healthy, :unhealthy, :degraded] ->
            status
            
          _ ->
            :unknown
        end
      catch
        _, _ -> :unhealthy
      end
    else
      basic_health_check(pid)
    end
  end
  
  defp get_server_config(server_id, state) do
    # Query the manager for server config
    if state.manager do
      try do
        case GenServer.call(state.manager, {:get_server_config, server_id}, 1_000) do
          {:ok, config} -> config
          _ -> nil
        end
      catch
        :exit, _ -> nil
      end
    else
      nil
    end
  end
  
  defp get_next_check_time(server_id, state) do
    case Map.get(state.check_timers, server_id) do
      nil -> nil
      timer ->
        case Process.read_timer(timer) do
          false -> nil
          ms -> DateTime.add(DateTime.utc_now(), ms, :millisecond)
        end
    end
  end
end