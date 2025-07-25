defmodule VsmMcp.MCP.ServerManager.ConnectionPool do
  @moduledoc """
  Connection pooling for MCP servers to improve performance and resource management.
  """
  
  use GenServer
  require Logger
  
  defstruct [
    :name,
    :size,
    :max_overflow,
    :strategy,
    :connections,
    :available,
    :waiting,
    :overflow_count,
    :metrics,
    :connection_fn,
    :validate_fn
  ]
  
  @strategies [:fifo, :lifo, :random]
  @default_size 10
  @default_max_overflow 5
  @default_strategy :fifo
  @validation_interval 30_000  # 30 seconds
  
  # Client API
  
  def start_link(opts) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def checkout(pool, timeout \\ 5_000) do
    GenServer.call(pool, :checkout, timeout)
  end
  
  def checkin(pool, conn) do
    GenServer.cast(pool, {:checkin, conn})
  end
  
  def status(pool) do
    GenServer.call(pool, :status)
  end
  
  def stop(pool) do
    GenServer.stop(pool)
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    state = %__MODULE__{
      name: opts[:name],
      size: opts[:size] || @default_size,
      max_overflow: opts[:max_overflow] || @default_max_overflow,
      strategy: validate_strategy(opts[:strategy]) || @default_strategy,
      connections: %{},
      available: :queue.new(),
      waiting: :queue.new(),
      overflow_count: 0,
      metrics: %{
        checkouts: 0,
        checkins: 0,
        timeouts: 0,
        errors: 0,
        created: 0,
        destroyed: 0
      },
      connection_fn: opts[:connection_fn] || fn -> {:ok, make_ref()} end,
      validate_fn: opts[:validate_fn] || fn _conn -> true end
    }
    
    # Start with initial connections
    state = initialize_connections(state)
    
    # Schedule periodic validation
    schedule_validation()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:checkout, from, state) do
    case get_available_connection(state) do
      {:ok, conn, new_state} ->
        # Validate connection before giving it out
        if state.validate_fn.(conn) do
          new_state = update_metrics(new_state, :checkouts, 1)
          {:reply, {:ok, conn}, new_state}
        else
          # Connection is invalid, destroy it and try again
          new_state = destroy_connection(conn, new_state)
          handle_checkout_with_retry(from, new_state)
        end
        
      {:error, :none_available} ->
        # Try to create overflow connection
        case create_overflow_connection(state) do
          {:ok, conn, new_state} ->
            new_state = update_metrics(new_state, :checkouts, 1)
            {:reply, {:ok, conn}, new_state}
            
          {:error, :max_overflow_reached} ->
            # Add to waiting queue
            new_state = add_to_waiting(from, state)
            {:noreply, new_state}
            
          {:error, reason} ->
            new_state = update_metrics(state, :errors, 1)
            {:reply, {:error, reason}, new_state}
        end
    end
  end
  
  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      size: state.size,
      available: :queue.len(state.available),
      in_use: map_size(state.connections) - :queue.len(state.available),
      waiting: :queue.len(state.waiting),
      overflow: state.overflow_count,
      max_overflow: state.max_overflow,
      metrics: state.metrics
    }
    
    {:reply, {:ok, status}, state}
  end
  
  @impl true
  def handle_cast({:checkin, conn}, state) do
    new_state = case Map.get(state.connections, conn) do
      nil ->
        Logger.warning("Attempted to checkin unknown connection: #{inspect(conn)}")
        state
        
      _info ->
        state
        |> update_metrics(:checkins, 1)
        |> handle_checkin(conn)
    end
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:validate_connections, state) do
    new_state = validate_all_connections(state)
    schedule_validation()
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:checkout_timeout, from}, state) do
    new_state = remove_from_waiting(from, state)
    new_state = update_metrics(new_state, :timeouts, 1)
    GenServer.reply(from, {:error, :timeout})
    {:noreply, new_state}
  end
  
  @impl true
  def terminate(_reason, state) do
    # Clean up all connections
    Enum.each(state.connections, fn {conn, _info} ->
      destroy_connection_resource(conn)
    end)
    
    :ok
  end
  
  # Private functions
  
  defp initialize_connections(state) do
    Enum.reduce(1..state.size, state, fn _, acc_state ->
      case create_connection(acc_state) do
        {:ok, conn, new_state} ->
          new_state
          
        {:error, _reason} ->
          # Continue with fewer connections
          acc_state
      end
    end)
  end
  
  defp create_connection(state) do
    case state.connection_fn.() do
      {:ok, conn} ->
        info = %{
          created_at: DateTime.utc_now(),
          last_used: DateTime.utc_now(),
          use_count: 0,
          is_overflow: false
        }
        
        new_state = %{state |
          connections: Map.put(state.connections, conn, info),
          available: :queue.in(conn, state.available),
          metrics: Map.update(state.metrics, :created, 1, &(&1 + 1))
        }
        
        {:ok, conn, new_state}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp create_overflow_connection(state) do
    if state.overflow_count >= state.max_overflow do
      {:error, :max_overflow_reached}
    else
      case state.connection_fn.() do
        {:ok, conn} ->
          info = %{
            created_at: DateTime.utc_now(),
            last_used: DateTime.utc_now(),
            use_count: 0,
            is_overflow: true
          }
          
          new_state = %{state |
            connections: Map.put(state.connections, conn, info),
            overflow_count: state.overflow_count + 1,
            metrics: Map.update(state.metrics, :created, 1, &(&1 + 1))
          }
          
          {:ok, conn, new_state}
          
        {:error, reason} ->
          {:error, reason}
      end
    end
  end
  
  defp get_available_connection(state) do
    case get_from_queue(state.available, state.strategy) do
      {:ok, conn, new_queue} ->
        # Update connection info
        info = Map.get(state.connections, conn)
        updated_info = %{info | 
          last_used: DateTime.utc_now(),
          use_count: info.use_count + 1
        }
        
        new_state = %{state |
          available: new_queue,
          connections: Map.put(state.connections, conn, updated_info)
        }
        
        {:ok, conn, new_state}
        
      :empty ->
        {:error, :none_available}
    end
  end
  
  defp handle_checkin(state, conn) do
    # Check if anyone is waiting
    case :queue.out(state.waiting) do
      {{:value, from}, new_waiting} ->
        # Give connection to waiter
        GenServer.reply(from, {:ok, conn})
        %{state | waiting: new_waiting}
        
      {:empty, _} ->
        # Return to pool or destroy if overflow
        info = Map.get(state.connections, conn)
        
        if info.is_overflow and :queue.len(state.available) >= state.size do
          # Destroy overflow connection
          destroy_connection(conn, state)
        else
          # Return to available pool
          %{state | available: return_to_queue(state.available, conn, state.strategy)}
        end
    end
  end
  
  defp handle_checkout_with_retry(from, state) do
    case get_available_connection(state) do
      {:ok, conn, new_state} ->
        if state.validate_fn.(conn) do
          new_state = update_metrics(new_state, :checkouts, 1)
          {:reply, {:ok, conn}, new_state}
        else
          new_state = destroy_connection(conn, new_state)
          handle_checkout_with_retry(from, new_state)
        end
        
      {:error, :none_available} ->
        # No connections available, wait
        new_state = add_to_waiting(from, state)
        {:noreply, new_state}
    end
  end
  
  defp destroy_connection(conn, state) do
    destroy_connection_resource(conn)
    
    info = Map.get(state.connections, conn)
    
    new_state = %{state |
      connections: Map.delete(state.connections, conn),
      metrics: Map.update(state.metrics, :destroyed, 1, &(&1 + 1))
    }
    
    if info && info.is_overflow do
      %{new_state | overflow_count: max(0, new_state.overflow_count - 1)}
    else
      new_state
    end
  end
  
  defp destroy_connection_resource(conn) do
    # Clean up the actual connection resource
    # This is a placeholder - actual implementation depends on connection type
    if is_pid(conn) and Process.alive?(conn) do
      Process.exit(conn, :shutdown)
    end
  end
  
  defp add_to_waiting(from, state) do
    # Set a timeout for the waiting request
    Process.send_after(self(), {:checkout_timeout, from}, 5_000)
    
    %{state | waiting: :queue.in(from, state.waiting)}
  end
  
  defp remove_from_waiting(from, state) do
    new_waiting = :queue.filter(fn waiting_from -> waiting_from != from end, state.waiting)
    %{state | waiting: new_waiting}
  end
  
  defp validate_all_connections(state) do
    # Validate available connections
    {valid, invalid} = state.available
      |> :queue.to_list()
      |> Enum.split_with(&state.validate_fn.(&1))
    
    # Destroy invalid connections
    new_state = Enum.reduce(invalid, state, fn conn, acc ->
      destroy_connection(conn, acc)
    end)
    
    # Rebuild available queue with valid connections
    %{new_state | available: :queue.from_list(valid)}
  end
  
  defp get_from_queue(queue, strategy) do
    case strategy do
      :fifo ->
        case :queue.out(queue) do
          {{:value, item}, new_queue} -> {:ok, item, new_queue}
          {:empty, _} -> :empty
        end
        
      :lifo ->
        case :queue.out_r(queue) do
          {{:value, item}, new_queue} -> {:ok, item, new_queue}
          {:empty, _} -> :empty
        end
        
      :random ->
        list = :queue.to_list(queue)
        case list do
          [] -> :empty
          _ ->
            item = Enum.random(list)
            new_list = List.delete(list, item)
            {:ok, item, :queue.from_list(new_list)}
        end
    end
  end
  
  defp return_to_queue(queue, item, strategy) do
    case strategy do
      :fifo -> :queue.in(item, queue)
      :lifo -> :queue.in_r(item, queue)
      :random -> :queue.in(item, queue)  # For simplicity
    end
  end
  
  defp validate_strategy(strategy) when strategy in @strategies, do: strategy
  defp validate_strategy(_), do: @default_strategy
  
  defp update_metrics(state, metric, increment) do
    %{state | metrics: Map.update(state.metrics, metric, increment, &(&1 + increment))}
  end
  
  defp schedule_validation do
    Process.send_after(self(), :validate_connections, @validation_interval)
  end
end