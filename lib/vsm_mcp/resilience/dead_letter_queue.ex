defmodule VsmMcp.Resilience.DeadLetterQueue do
  @moduledoc """
  Dead Letter Queue for handling permanently failed operations.
  
  Stores failed operations for manual inspection, retry, or analysis.
  Provides persistence, monitoring, and recovery capabilities.
  """
  
  use GenServer
  require Logger
  
  @table_name :vsm_mcp_dlq
  @max_size 10_000
  @persist_interval 60_000  # 1 minute
  
  # Client API
  
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Add a failed item to the dead letter queue.
  """
  def add(dlq \\ __MODULE__, item) do
    GenServer.cast(dlq, {:add, item})
  end
  
  @doc """
  Get all items from the dead letter queue.
  """
  def list_all(dlq \\ __MODULE__) do
    GenServer.call(dlq, :list_all)
  end
  
  @doc """
  Get items by error type.
  """
  def list_by_error(dlq \\ __MODULE__, error_type) do
    GenServer.call(dlq, {:list_by_error, error_type})
  end
  
  @doc """
  Retry a specific item from the queue.
  """
  def retry_item(dlq \\ __MODULE__, id) do
    GenServer.call(dlq, {:retry, id})
  end
  
  @doc """
  Remove an item from the queue.
  """
  def remove(dlq \\ __MODULE__, id) do
    GenServer.call(dlq, {:remove, id})
  end
  
  @doc """
  Clear all items from the queue.
  """
  def clear(dlq \\ __MODULE__) do
    GenServer.call(dlq, :clear)
  end
  
  @doc """
  Get queue statistics.
  """
  def stats(dlq \\ __MODULE__) do
    GenServer.call(dlq, :stats)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    :ets.new(@table_name, [:set, :named_table, :public])
    
    state = %{
      max_size: Keyword.get(opts, :max_size, @max_size),
      persist_file: Keyword.get(opts, :persist_file, "dlq_backup.etf"),
      stats: %{
        total_added: 0,
        total_retried: 0,
        total_removed: 0,
        current_size: 0
      }
    }
    
    # Load persisted data if available
    load_from_disk(state)
    
    # Schedule periodic persistence
    schedule_persist()
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:add, item}, state) do
    id = generate_id()
    timestamp = DateTime.utc_now()
    
    entry = %{
      id: id,
      item: item,
      timestamp: timestamp,
      retries: 0,
      error_type: extract_error_type(item)
    }
    
    # Check size limit
    if state.stats.current_size >= state.max_size do
      # Remove oldest entry
      oldest = find_oldest_entry()
      if oldest do
        :ets.delete(@table_name, oldest.id)
        state = update_stat(state, :current_size, -1)
      end
    end
    
    :ets.insert(@table_name, {id, entry})
    
    Logger.warning("Added item to dead letter queue: #{id}")
    
    state = state
    |> update_stat(:total_added, 1)
    |> update_stat(:current_size, 1)
    
    emit_telemetry(:item_added, %{id: id, error_type: entry.error_type})
    
    {:noreply, state}
  end
  
  @impl true
  def handle_call(:list_all, _from, state) do
    items = :ets.tab2list(@table_name)
    |> Enum.map(fn {_id, entry} -> entry end)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    
    {:reply, items, state}
  end
  
  @impl true
  def handle_call({:list_by_error, error_type}, _from, state) do
    items = :ets.tab2list(@table_name)
    |> Enum.map(fn {_id, entry} -> entry end)
    |> Enum.filter(fn entry -> entry.error_type == error_type end)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    
    {:reply, items, state}
  end
  
  @impl true
  def handle_call({:retry, id}, _from, state) do
    case :ets.lookup(@table_name, id) do
      [{^id, entry}] ->
        result = retry_entry(entry)
        
        case result do
          {:ok, _} ->
            :ets.delete(@table_name, id)
            state = state
            |> update_stat(:total_retried, 1)
            |> update_stat(:current_size, -1)
            
            emit_telemetry(:item_retried, %{id: id, success: true})
            {:reply, result, state}
          
          {:error, _} ->
            # Update retry count
            updated_entry = Map.update!(entry, :retries, &(&1 + 1))
            :ets.insert(@table_name, {id, updated_entry})
            
            emit_telemetry(:item_retried, %{id: id, success: false})
            {:reply, result, state}
        end
      
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:remove, id}, _from, state) do
    case :ets.lookup(@table_name, id) do
      [{^id, _entry}] ->
        :ets.delete(@table_name, id)
        state = state
        |> update_stat(:total_removed, 1)
        |> update_stat(:current_size, -1)
        
        emit_telemetry(:item_removed, %{id: id})
        {:reply, :ok, state}
      
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl true
  def handle_call(:clear, _from, state) do
    count = :ets.info(@table_name, :size)
    :ets.delete_all_objects(@table_name)
    
    state = Map.put(state, :stats, %{
      total_added: state.stats.total_added,
      total_retried: state.stats.total_retried,
      total_removed: state.stats.total_removed + count,
      current_size: 0
    })
    
    emit_telemetry(:queue_cleared, %{items_removed: count})
    {:reply, {:ok, count}, state}
  end
  
  @impl true
  def handle_call(:stats, _from, state) do
    error_breakdown = :ets.tab2list(@table_name)
    |> Enum.map(fn {_id, entry} -> entry.error_type end)
    |> Enum.frequencies()
    
    stats = Map.merge(state.stats, %{
      error_breakdown: error_breakdown,
      oldest_item: find_oldest_entry(),
      newest_item: find_newest_entry()
    })
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_info(:persist, state) do
    persist_to_disk(state)
    schedule_persist()
    {:noreply, state}
  end
  
  # Private Functions
  
  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16()
  end
  
  defp extract_error_type({_fun, error, _attempts}) do
    case error do
      {type, _message} when is_atom(type) -> type
      type when is_atom(type) -> type
      _ -> :unknown
    end
  end
  
  defp retry_entry(%{item: {fun, _error, _attempts}} = entry) when is_function(fun) do
    Logger.info("Retrying DLQ item: #{entry.id}")
    
    try do
      result = fun.()
      {:ok, result}
    rescue
      error ->
        {:error, {error.__struct__, Exception.message(error)}}
    catch
      kind, reason ->
        {:error, {kind, reason}}
    end
  end
  
  defp retry_entry(_), do: {:error, :invalid_entry}
  
  defp find_oldest_entry do
    case :ets.tab2list(@table_name) do
      [] -> nil
      entries ->
        entries
        |> Enum.map(fn {_id, entry} -> entry end)
        |> Enum.min_by(& &1.timestamp, DateTime, fn -> nil end)
    end
  end
  
  defp find_newest_entry do
    case :ets.tab2list(@table_name) do
      [] -> nil
      entries ->
        entries
        |> Enum.map(fn {_id, entry} -> entry end)
        |> Enum.max_by(& &1.timestamp, DateTime, fn -> nil end)
    end
  end
  
  defp update_stat(state, stat, increment) do
    put_in(state, [:stats, stat], state.stats[stat] + increment)
  end
  
  defp schedule_persist do
    Process.send_after(self(), :persist, @persist_interval)
  end
  
  defp persist_to_disk(state) do
    data = :ets.tab2list(@table_name)
    
    case File.write(state.persist_file, :erlang.term_to_binary(data)) do
      :ok ->
        Logger.debug("DLQ persisted to disk: #{length(data)} items")
      {:error, reason} ->
        Logger.error("Failed to persist DLQ: #{inspect(reason)}")
    end
  end
  
  defp load_from_disk(state) do
    case File.read(state.persist_file) do
      {:ok, binary} ->
        data = :erlang.binary_to_term(binary)
        Enum.each(data, fn {id, entry} ->
          :ets.insert(@table_name, {id, entry})
        end)
        
        count = length(data)
        Logger.info("Loaded #{count} items from DLQ backup")
        
        put_in(state, [:stats, :current_size], count)
      
      {:error, :enoent} ->
        # File doesn't exist, that's ok
        :ok
      
      {:error, reason} ->
        Logger.error("Failed to load DLQ backup: #{inspect(reason)}")
    end
  end
  
  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:vsm_mcp, :dead_letter_queue, event],
      measurements,
      %{}
    )
  end
end