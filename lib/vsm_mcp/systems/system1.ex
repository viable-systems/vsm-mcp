defmodule VsmMcp.Systems.System1 do
  @moduledoc """
  System 1: Operations (Purpose Fulfillment)
  
  This module implements the operational core of the VSM, responsible for
  executing the primary activities that directly produce value.
  """
  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def execute_operation(operation) do
    GenServer.call(__MODULE__, {:execute, operation})
  end

  def get_status do
    GenServer.call(__MODULE__, :status)
  end

  def add_capability(capability) do
    GenServer.cast(__MODULE__, {:add_capability, capability})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %{
      operations: [],
      capabilities: opts[:capabilities] || [],
      metrics: %{
        operations_count: 0,
        success_rate: 1.0,
        average_duration: 0
      }
    }
    
    Logger.info("System 1 (Operations) initialized with #{length(state.capabilities)} capabilities")
    {:ok, state}
  end

  @impl true
  def handle_call({:execute, operation}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    # Simulate operation execution
    result = case operation do
      %{type: :process} -> process_operation(operation, state)
      %{type: :transform} -> transform_operation(operation, state)
      _ -> {:error, "Unknown operation type"}
    end
    
    duration = System.monotonic_time(:millisecond) - start_time
    
    new_state = update_metrics(state, result, duration)
    |> Map.update!(:operations, &[{operation, result, duration} | &1])
    
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      active: true,
      capabilities: state.capabilities,
      metrics: state.metrics,
      recent_operations: Enum.take(state.operations, 5)
    }
    {:reply, status, state}
  end

  @impl true
  def handle_cast({:add_capability, capability}, state) do
    new_state = Map.update!(state, :capabilities, &[capability | &1])
    Logger.info("Added capability: #{inspect(capability)}")
    {:noreply, new_state}
  end

  # Private Functions

  defp process_operation(operation, _state) do
    # Simulate processing
    Process.sleep(Enum.random(10..50))
    {:ok, %{result: "Processed #{operation.data}", timestamp: DateTime.utc_now()}}
  end

  defp transform_operation(operation, _state) do
    # Simulate transformation
    Process.sleep(Enum.random(20..80))
    {:ok, %{result: "Transformed #{operation.input} to #{operation.output}", timestamp: DateTime.utc_now()}}
  end

  defp update_metrics(state, result, duration) do
    metrics = state.metrics
    count = metrics.operations_count + 1
    success = if match?({:ok, _}, result), do: 1, else: 0
    new_success_rate = (metrics.success_rate * metrics.operations_count + success) / count
    new_avg_duration = (metrics.average_duration * metrics.operations_count + duration) / count
    
    new_metrics = %{
      operations_count: count,
      success_rate: new_success_rate,
      average_duration: new_avg_duration
    }
    
    Map.put(state, :metrics, new_metrics)
  end
end