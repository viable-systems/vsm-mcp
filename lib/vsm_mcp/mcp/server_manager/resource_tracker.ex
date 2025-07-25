defmodule VsmMcp.MCP.ServerManager.ResourceTracker do
  @moduledoc """
  Tracks and manages resources used by MCP server processes.
  Prevents memory leaks and zombie processes.
  """
  
  use GenServer
  require Logger
  
  defstruct [
    :processes,
    :ports,
    :memory_limits,
    :cleanup_interval,
    :metrics
  ]
  
  @default_memory_limit 500_000_000  # 500MB per process
  @cleanup_interval 60_000  # 1 minute
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def track_process(tracker, pid, opts \\ []) do
    GenServer.cast(tracker, {:track_process, pid, opts})
  end
  
  def untrack_process(tracker, pid) do
    GenServer.cast(tracker, {:untrack_process, pid})
  end
  
  def track_port(tracker, port, opts \\ []) do
    GenServer.cast(tracker, {:track_port, port, opts})
  end
  
  def untrack_port(tracker, port) do
    GenServer.cast(tracker, {:untrack_port, port})
  end
  
  def get_usage(tracker) do
    GenServer.call(tracker, :get_usage)
  end
  
  def get_process_usage(tracker, pid) do
    GenServer.call(tracker, {:get_process_usage, pid})
  end
  
  def cleanup_dead_processes(tracker, active_pids) do
    GenServer.cast(tracker, {:cleanup_dead_processes, active_pids})
  end
  
  def check_limits(tracker) do
    GenServer.call(tracker, :check_limits)
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    state = %__MODULE__{
      processes: %{},
      ports: %{},
      memory_limits: %{
        default: opts[:default_memory_limit] || @default_memory_limit,
        per_process: opts[:per_process_limits] || %{}
      },
      cleanup_interval: opts[:cleanup_interval] || @cleanup_interval,
      metrics: %{
        total_processes: 0,
        total_ports: 0,
        memory_violations: 0,
        cleanups_performed: 0,
        zombies_killed: 0
      }
    }
    
    # Schedule periodic cleanup
    schedule_cleanup(state.cleanup_interval)
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:track_process, pid, opts}, state) do
    monitor_ref = Process.monitor(pid)
    
    process_info = %{
      pid: pid,
      monitor_ref: monitor_ref,
      started_at: DateTime.utc_now(),
      memory_limit: opts[:memory_limit] || state.memory_limits.default,
      metadata: opts[:metadata] || %{}
    }
    
    new_state = %{state |
      processes: Map.put(state.processes, pid, process_info),
      metrics: Map.update(state.metrics, :total_processes, 1, &(&1 + 1))
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:untrack_process, pid}, state) do
    case Map.get(state.processes, pid) do
      nil ->
        {:noreply, state}
        
      info ->
        Process.demonitor(info.monitor_ref, [:flush])
        
        new_state = %{state |
          processes: Map.delete(state.processes, pid)
        }
        
        {:noreply, new_state}
    end
  end
  
  @impl true
  def handle_cast({:track_port, port, opts}, state) do
    port_info = %{
      port: port,
      started_at: DateTime.utc_now(),
      metadata: opts[:metadata] || %{}
    }
    
    new_state = %{state |
      ports: Map.put(state.ports, port, port_info),
      metrics: Map.update(state.metrics, :total_ports, 1, &(&1 + 1))
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:untrack_port, port}, state) do
    new_state = %{state |
      ports: Map.delete(state.ports, port)
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:cleanup_dead_processes, active_pids}, state) do
    active_set = MapSet.new(active_pids)
    
    # Find dead processes
    {dead, alive} = Map.split_with(state.processes, fn {pid, _} ->
      not MapSet.member?(active_set, pid) and not Process.alive?(pid)
    end)
    
    # Clean up dead processes
    Enum.each(dead, fn {pid, info} ->
      Logger.warning("Cleaning up dead process: #{inspect(pid)}")
      Process.demonitor(info.monitor_ref, [:flush])
    end)
    
    # Find and clean up dead ports
    {dead_ports, alive_ports} = Map.split_with(state.ports, fn {port, _} ->
      not port_alive?(port)
    end)
    
    zombies_killed = map_size(dead) + map_size(dead_ports)
    
    new_state = %{state |
      processes: alive,
      ports: alive_ports,
      metrics: %{state.metrics |
        cleanups_performed: state.metrics.cleanups_performed + 1,
        zombies_killed: state.metrics.zombies_killed + zombies_killed
      }
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call(:get_usage, _from, state) do
    usage = %{
      processes: map_size(state.processes),
      ports: map_size(state.ports),
      total_memory: calculate_total_memory(state),
      process_details: Enum.map(state.processes, fn {pid, info} ->
        %{
          pid: pid,
          memory: get_process_memory(pid),
          uptime: DateTime.diff(DateTime.utc_now(), info.started_at, :second),
          metadata: info.metadata
        }
      end),
      metrics: state.metrics
    }
    
    {:reply, {:ok, usage}, state}
  end
  
  @impl true
  def handle_call({:get_process_usage, pid}, _from, state) do
    case Map.get(state.processes, pid) do
      nil ->
        {:reply, {:error, :not_tracked}, state}
        
      info ->
        usage = %{
          memory: get_process_memory(pid),
          memory_limit: info.memory_limit,
          uptime: DateTime.diff(DateTime.utc_now(), info.started_at, :second),
          message_queue_len: get_message_queue_len(pid),
          reductions: get_reductions(pid),
          metadata: info.metadata
        }
        
        {:reply, {:ok, usage}, state}
    end
  end
  
  @impl true
  def handle_call(:check_limits, _from, state) do
    violations = Enum.filter(state.processes, fn {pid, info} ->
      memory = get_process_memory(pid)
      memory > info.memory_limit
    end)
    
    if length(violations) > 0 do
      new_state = %{state |
        metrics: Map.update(state.metrics, :memory_violations, length(violations), &(&1 + length(violations)))
      }
      
      {:reply, {:violations, violations}, new_state}
    else
      {:reply, :ok, state}
    end
  end
  
  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    # Process died, clean up
    case Enum.find(state.processes, fn {_pid, info} -> info.monitor_ref == ref end) do
      nil ->
        {:noreply, state}
        
      {pid, _info} ->
        new_state = %{state |
          processes: Map.delete(state.processes, pid)
        }
        
        {:noreply, new_state}
    end
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    # Perform periodic cleanup
    new_state = perform_cleanup(state)
    schedule_cleanup(state.cleanup_interval)
    {:noreply, new_state}
  end
  
  # Private functions
  
  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end
  
  defp perform_cleanup(state) do
    # Check for dead processes
    {dead, alive} = Map.split_with(state.processes, fn {pid, _} ->
      not Process.alive?(pid)
    end)
    
    # Clean up monitors for dead processes
    Enum.each(dead, fn {_pid, info} ->
      Process.demonitor(info.monitor_ref, [:flush])
    end)
    
    # Check for dead ports
    {dead_ports, alive_ports} = Map.split_with(state.ports, fn {port, _} ->
      not port_alive?(port)
    end)
    
    # Check memory limits
    memory_violations = Enum.count(alive, fn {pid, info} ->
      get_process_memory(pid) > info.memory_limit
    end)
    
    %{state |
      processes: alive,
      ports: alive_ports,
      metrics: %{state.metrics |
        cleanups_performed: state.metrics.cleanups_performed + 1,
        zombies_killed: state.metrics.zombies_killed + map_size(dead) + map_size(dead_ports),
        memory_violations: state.metrics.memory_violations + memory_violations
      }
    }
  end
  
  defp calculate_total_memory(state) do
    Enum.reduce(state.processes, 0, fn {pid, _}, acc ->
      acc + get_process_memory(pid)
    end)
  end
  
  defp get_process_memory(pid) do
    case Process.info(pid, :memory) do
      {:memory, bytes} -> bytes
      nil -> 0
    end
  end
  
  defp get_message_queue_len(pid) do
    case Process.info(pid, :message_queue_len) do
      {:message_queue_len, len} -> len
      nil -> 0
    end
  end
  
  defp get_reductions(pid) do
    case Process.info(pid, :reductions) do
      {:reductions, count} -> count
      nil -> 0
    end
  end
  
  defp port_alive?(port) do
    case :erlang.port_info(port) do
      :undefined -> false
      _ -> true
    end
  end
end