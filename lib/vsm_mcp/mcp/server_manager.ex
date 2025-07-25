defmodule VsmMcp.MCP.ServerManager do
  @moduledoc """
  Bulletproof MCP server process manager that handles the complete lifecycle of MCP servers.
  
  Features:
  - Server discovery and validation before starting
  - Process startup with health checks
  - Process monitoring and automatic restart on failure
  - Graceful shutdown and cleanup
  - Resource management (prevent memory/process leaks)
  - Connection pooling for multiple servers
  - Fallback mechanisms when servers fail
  """
  
  use GenServer
  require Logger
  
  alias VsmMcp.MCP.ServerManager.{
    ServerConfig,
    ServerProcess,
    HealthMonitor,
    ResourceTracker,
    ConnectionPool
  }
  
  @restart_strategies %{
    permanent: :permanent,
    transient: :transient,
    temporary: :temporary
  }
  
  @health_check_interval 30_000  # 30 seconds
  @max_restart_attempts 3
  @restart_backoff_ms 1_000
  
  defstruct [
    :name,
    :servers,
    :monitors,
    :pools,
    :metrics,
    :resource_tracker,
    :health_monitor,
    :restart_policies
  ]
  
  # Client API
  
  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc "Start a new MCP server"
  def start_server(manager \\ __MODULE__, config) do
    GenServer.call(manager, {:start_server, config})
  end
  
  @doc "Stop a running MCP server"
  def stop_server(manager \\ __MODULE__, server_id, opts \\ []) do
    GenServer.call(manager, {:stop_server, server_id, opts})
  end
  
  @doc "Restart a server"
  def restart_server(manager \\ __MODULE__, server_id) do
    GenServer.call(manager, {:restart_server, server_id})
  end
  
  @doc "Get status of all servers"
  def get_status(manager \\ __MODULE__) do
    GenServer.call(manager, :get_status)
  end
  
  @doc "Get health report for specific server"
  def get_health(manager \\ __MODULE__, server_id) do
    GenServer.call(manager, {:get_health, server_id})
  end
  
  @doc "Bulk start multiple servers"
  def start_servers(manager \\ __MODULE__, configs) do
    GenServer.call(manager, {:start_servers, configs}, 30_000)
  end
  
  @doc "Bulk stop multiple servers"
  def stop_servers(manager \\ __MODULE__, server_ids, opts \\ []) do
    GenServer.call(manager, {:stop_servers, server_ids, opts}, 30_000)
  end
  
  @doc "Get server metrics"
  def get_metrics(manager \\ __MODULE__, server_id \\ :all) do
    GenServer.call(manager, {:get_metrics, server_id})
  end
  
  @doc "Update server configuration"
  def update_config(manager \\ __MODULE__, server_id, config) do
    GenServer.call(manager, {:update_config, server_id, config})
  end
  
  @doc "Get connection from pool"
  def get_connection(manager \\ __MODULE__, server_id) do
    GenServer.call(manager, {:get_connection, server_id})
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    # Start sub-components
    {:ok, resource_tracker} = ResourceTracker.start_link()
    {:ok, health_monitor} = HealthMonitor.start_link(
      check_interval: opts[:health_check_interval] || @health_check_interval,
      manager: self()
    )
    
    state = %__MODULE__{
      name: opts[:name] || __MODULE__,
      servers: %{},
      monitors: %{},
      pools: %{},
      metrics: %{
        started: 0,
        stopped: 0,
        restarted: 0,
        failed: 0,
        health_checks: 0
      },
      resource_tracker: resource_tracker,
      health_monitor: health_monitor,
      restart_policies: opts[:restart_policies] || default_restart_policies()
    }
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:start_server, config}, _from, state) do
    case do_start_server(config, state) do
      {:ok, server_id, new_state} ->
        {:reply, {:ok, server_id}, new_state}
        
      {:error, reason} = error ->
        new_state = update_metrics(state, :failed, 1)
        {:reply, error, new_state}
    end
  end
  
  @impl true
  def handle_call({:stop_server, server_id, opts}, _from, state) do
    case do_stop_server(server_id, opts, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}
        
      {:error, reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:restart_server, server_id}, _from, state) do
    case do_restart_server(server_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}
        
      {:error, reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      servers: Enum.map(state.servers, fn {id, server} ->
        %{
          id: id,
          config: server.config,
          status: server.status,
          pid: server.pid,
          started_at: server.started_at,
          restart_count: server.restart_count,
          last_health_check: server.last_health_check,
          health_status: server.health_status
        }
      end),
      metrics: state.metrics,
      resource_usage: ResourceTracker.get_usage(state.resource_tracker)
    }
    
    {:reply, {:ok, status}, state}
  end
  
  @impl true
  def handle_call(:list_servers, _from, state) do
    servers = Map.new(state.servers, fn {id, server} ->
      {id, %{
        status: server.status,
        type: server.config.type,
        health: server.health_status,
        started_at: server.started_at
      }}
    end)
    {:reply, servers, state}
  end
  
  @impl true
  def handle_call({:get_health, server_id}, _from, state) do
    case Map.get(state.servers, server_id) do
      nil ->
        {:reply, {:error, :server_not_found}, state}
        
      server ->
        health = %{
          status: server.health_status,
          last_check: server.last_health_check,
          uptime: calculate_uptime(server),
          restart_count: server.restart_count,
          resource_usage: ResourceTracker.get_process_usage(
            state.resource_tracker,
            server.pid
          )
        }
        {:reply, {:ok, health}, state}
    end
  end
  
  @impl true
  def handle_call({:start_servers, configs}, _from, state) do
    results = Enum.map(configs, fn config ->
      case do_start_server(config, state) do
        {:ok, server_id, new_state} ->
          state = new_state
          {:ok, server_id}
          
        error ->
          error
      end
    end)
    
    successful = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))
    
    {:reply, {:ok, %{successful: successful, failed: failed, results: results}}, state}
  end
  
  @impl true
  def handle_call({:stop_servers, server_ids, opts}, _from, state) do
    {new_state, results} = Enum.reduce(server_ids, {state, []}, fn server_id, {acc_state, acc_results} ->
      case do_stop_server(server_id, opts, acc_state) do
        {:ok, new_state} ->
          {new_state, [{:ok, server_id} | acc_results]}
          
        error ->
          {acc_state, [error | acc_results]}
      end
    end)
    
    {:reply, {:ok, Enum.reverse(results)}, new_state}
  end
  
  @impl true
  def handle_call({:get_metrics, server_id}, _from, state) do
    metrics = case server_id do
      :all ->
        state.metrics
        
      id ->
        case Map.get(state.servers, id) do
          nil -> %{}
          server -> server.metrics
        end
    end
    
    {:reply, {:ok, metrics}, state}
  end
  
  @impl true
  def handle_call({:update_config, server_id, config}, _from, state) do
    case Map.get(state.servers, server_id) do
      nil ->
        {:reply, {:error, :server_not_found}, state}
        
      server ->
        # Validate new config
        case ServerConfig.validate(config) do
          {:ok, validated_config} ->
            # Update server with new config
            updated_server = %{server | config: validated_config}
            new_state = %{state | servers: Map.put(state.servers, server_id, updated_server)}
            
            # Restart if necessary
            if server.status == :running and config[:restart_on_update] do
              case do_restart_server(server_id, new_state) do
                {:ok, final_state} ->
                  {:reply, :ok, final_state}
                  
                error ->
                  {:reply, error, new_state}
              end
            else
              {:reply, :ok, new_state}
            end
            
          error ->
            {:reply, error, state}
        end
    end
  end
  
  @impl true
  def handle_call({:get_connection, server_id}, _from, state) do
    case Map.get(state.pools, server_id) do
      nil ->
        {:reply, {:error, :no_pool_available}, state}
        
      pool ->
        case ConnectionPool.checkout(pool) do
          {:ok, conn} ->
            {:reply, {:ok, conn}, state}
            
          error ->
            {:reply, error, state}
        end
    end
  end
  
  @impl true
  def handle_call({:get_server_config, server_id}, _from, state) do
    case Map.get(state.servers, server_id) do
      nil ->
        {:reply, {:error, :server_not_found}, state}
        
      server ->
        {:reply, {:ok, server.config}, state}
    end
  end
  
  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    # Find which server crashed
    case find_server_by_monitor(ref, state) do
      nil ->
        {:noreply, state}
        
      {server_id, server} ->
        Logger.error("Server #{server_id} crashed: #{inspect(reason)}")
        
        # Update server status
        updated_server = %{server | 
          status: :crashed,
          crash_reason: reason,
          crashed_at: DateTime.utc_now()
        }
        
        # Attempt restart based on policy
        new_state = handle_server_crash(server_id, updated_server, state)
        
        {:noreply, new_state}
    end
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    # Clean up terminated processes and stale resources
    new_state = cleanup_resources(state)
    schedule_cleanup()
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:restart_server, server_id}, state) do
    case do_restart_server(server_id, state) do
      {:ok, new_state} ->
        Logger.info("Successfully restarted server #{server_id}")
        {:noreply, new_state}
        
      {:error, reason} ->
        Logger.error("Failed to restart server #{server_id}: #{inspect(reason)}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:health_check_result, server_id, result}, state) do
    case Map.get(state.servers, server_id) do
      nil ->
        {:noreply, state}
        
      server ->
        updated_server = %{server |
          last_health_check: DateTime.utc_now(),
          health_status: result,
          consecutive_failures: if(result == :healthy, do: 0, else: server.consecutive_failures + 1)
        }
        
        new_state = %{state | 
          servers: Map.put(state.servers, server_id, updated_server),
          metrics: Map.update(state.metrics, :health_checks, 1, &(&1 + 1))
        }
        
        # Handle unhealthy servers
        new_state = if result != :healthy and updated_server.consecutive_failures >= 3 do
          Logger.warning("Server #{server_id} is unhealthy, attempting restart")
          case do_restart_server(server_id, new_state) do
            {:ok, updated_state} -> updated_state
            _ -> new_state
          end
        else
          new_state
        end
        
        {:noreply, new_state}
    end
  end
  
  # Private functions
  
  defp do_start_server(config, state) do
    with {:ok, validated_config} <- ServerConfig.validate(config),
         {:ok, server_id} <- generate_server_id(validated_config),
         :ok <- check_server_not_exists(server_id, state),
         {:ok, process} <- start_server_process(validated_config),
         {:ok, pool} <- start_connection_pool(server_id, validated_config) do
      
      # Monitor the process
      monitor_ref = Process.monitor(process.pid)
      
      # Track resources
      ResourceTracker.track_process(state.resource_tracker, process.pid)
      
      # Register with health monitor
      HealthMonitor.register_server(state.health_monitor, server_id, process.pid)
      
      # Create server record
      server = %ServerProcess{
        id: server_id,
        config: validated_config,
        pid: process.pid,
        status: :running,
        started_at: DateTime.utc_now(),
        monitor_ref: monitor_ref,
        restart_count: 0,
        health_status: :unknown,
        consecutive_failures: 0,
        metrics: %{}
      }
      
      new_state = %{state |
        servers: Map.put(state.servers, server_id, server),
        monitors: Map.put(state.monitors, monitor_ref, server_id),
        pools: Map.put(state.pools, server_id, pool),
        metrics: Map.update(state.metrics, :started, 1, &(&1 + 1))
      }
      
      Logger.info("Started MCP server #{server_id}")
      
      {:ok, server_id, new_state}
    end
  end
  
  defp do_stop_server(server_id, opts, state) do
    case Map.get(state.servers, server_id) do
      nil ->
        {:error, :server_not_found}
        
      server ->
        # Stop health monitoring
        HealthMonitor.unregister_server(state.health_monitor, server_id)
        
        # Stop connection pool
        if pool = Map.get(state.pools, server_id) do
          ConnectionPool.stop(pool)
        end
        
        # Stop the process gracefully
        timeout = opts[:timeout] || 5_000
        graceful = opts[:graceful] != false
        
        if graceful do
          try do
            GenServer.stop(server.pid, :shutdown, timeout)
          catch
            :exit, _ -> :ok
          end
        else
          Process.exit(server.pid, :kill)
        end
        
        # Cleanup resources
        ResourceTracker.untrack_process(state.resource_tracker, server.pid)
        
        # Demonitor
        if server.monitor_ref do
          Process.demonitor(server.monitor_ref, [:flush])
        end
        
        new_state = %{state |
          servers: Map.delete(state.servers, server_id),
          monitors: Map.delete(state.monitors, server.monitor_ref),
          pools: Map.delete(state.pools, server_id),
          metrics: Map.update(state.metrics, :stopped, 1, &(&1 + 1))
        }
        
        Logger.info("Stopped MCP server #{server_id}")
        
        {:ok, new_state}
    end
  end
  
  defp do_restart_server(server_id, state) do
    with {:ok, state_after_stop} <- do_stop_server(server_id, [graceful: true], state),
         server when not is_nil(server) <- Map.get(state.servers, server_id),
         {:ok, new_server_id, state_after_start} <- do_start_server(server.config, state_after_stop) do
      
      # Update restart count
      restarted_server = Map.get(state_after_start.servers, new_server_id)
      updated_server = %{restarted_server | restart_count: server.restart_count + 1}
      
      final_state = %{state_after_start |
        servers: Map.put(state_after_start.servers, new_server_id, updated_server),
        metrics: Map.update(state_after_start.metrics, :restarted, 1, &(&1 + 1))
      }
      
      Logger.info("Restarted MCP server #{server_id} -> #{new_server_id}")
      
      {:ok, final_state}
    else
      nil ->
        # Server was already stopped, just start it
        case Map.get(state.servers, server_id) do
          nil -> {:error, :server_not_found}
          server -> do_start_server(server.config, state)
        end
        
      error ->
        error
    end
  end
  
  defp handle_server_crash(server_id, server, state) do
    restart_policy = get_restart_policy(server.config, state.restart_policies)
    
    case should_restart?(server, restart_policy) do
      true ->
        # Schedule restart with backoff
        backoff = calculate_backoff(server.restart_count)
        Process.send_after(self(), {:restart_server, server_id}, backoff)
        
        %{state | servers: Map.put(state.servers, server_id, server)}
        
      false ->
        Logger.info("Not restarting server #{server_id} based on policy #{restart_policy}")
        
        # Clean up resources
        ResourceTracker.untrack_process(state.resource_tracker, server.pid)
        HealthMonitor.unregister_server(state.health_monitor, server_id)
        
        %{state |
          servers: Map.delete(state.servers, server_id),
          monitors: Map.delete(state.monitors, server.monitor_ref),
          pools: Map.delete(state.pools, server_id),
          metrics: Map.update(state.metrics, :failed, 1, &(&1 + 1))
        }
    end
  end
  
  defp start_server_process(config) do
    # Determine server type and start appropriate process
    case config.type do
      :external ->
        start_external_server(config)
        
      :internal ->
        start_internal_server(config)
        
      :custom ->
        config.start_fn.(config)
    end
  end
  
  defp start_external_server(config) do
    # Start external MCP server process
    ServerProcess.start_external(config)
  end
  
  defp start_internal_server(config) do
    # Start internal Elixir-based MCP server
    VsmMcp.MCP.Server.start_link(config.server_opts)
  end
  
  defp start_connection_pool(server_id, %ServerConfig{} = config) do
    pool_opts = [
      name: :"#{server_id}_pool",
      size: config.pool_size || 10,
      max_overflow: config.max_overflow || 5,
      strategy: :fifo
    ]
    
    ConnectionPool.start_link(pool_opts)
  end
  
  defp start_connection_pool(server_id, config) when is_map(config) do
    pool_opts = [
      name: :"#{server_id}_pool",
      size: config[:pool_size] || 10,
      max_overflow: config[:max_overflow] || 5,
      strategy: :fifo
    ]
    
    ConnectionPool.start_link(pool_opts)
  end
  
  defp generate_server_id(%ServerConfig{} = config) do
    id = config.id || "mcp_server_#{:erlang.unique_integer([:positive])}"
    {:ok, id}
  end
  
  defp generate_server_id(config) when is_map(config) do
    id = config[:id] || "mcp_server_#{:erlang.unique_integer([:positive])}"
    {:ok, id}
  end
  
  defp check_server_not_exists(server_id, state) do
    if Map.has_key?(state.servers, server_id) do
      {:error, :server_already_exists}
    else
      :ok
    end
  end
  
  defp find_server_by_monitor(ref, state) do
    case Map.get(state.monitors, ref) do
      nil -> nil
      server_id -> {server_id, Map.get(state.servers, server_id)}
    end
  end
  
  defp should_restart?(server, policy) do
    case policy do
      :permanent -> true
      :transient -> server.crash_reason != :normal
      :temporary -> false
      _ -> false
    end
  end
  
  defp get_restart_policy(%ServerConfig{} = config, policies) do
    config.restart_policy || policies[:default] || :permanent
  end
  
  defp get_restart_policy(config, policies) when is_map(config) do
    config[:restart_policy] || policies[:default] || :permanent
  end
  
  defp calculate_backoff(restart_count) do
    backoff = @restart_backoff_ms * :math.pow(2, restart_count)
    round(min(backoff, 60_000))
  end
  
  defp calculate_uptime(server) do
    if server.started_at do
      DateTime.diff(DateTime.utc_now(), server.started_at, :second)
    else
      0
    end
  end
  
  defp update_metrics(state, metric, increment) do
    %{state | metrics: Map.update(state.metrics, metric, increment, &(&1 + increment))}
  end
  
  defp cleanup_resources(state) do
    # Find and clean up zombie processes
    active_pids = state.servers
      |> Map.values()
      |> Enum.map(& &1.pid)
      |> Enum.filter(&Process.alive?/1)
    
    ResourceTracker.cleanup_dead_processes(state.resource_tracker, active_pids)
    
    # Clean up stale connection pools
    state
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 60_000) # Every minute
  end
  
  defp default_restart_policies do
    %{
      default: :permanent,
      external: :transient,
      internal: :permanent,
      custom: :temporary
    }
  end
end