defmodule VsmMcp.ConsciousnessInterface.SelfModel do
  @moduledoc """
  Self-model for the VSM-MCP system.
  Maintains a model of the system's own capabilities, state, and identity.
  """
  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get_model(pid) do
    GenServer.call(pid, :get_model)
  end

  def update(pid, observations) do
    GenServer.call(pid, {:update, observations})
  end

  def compare_expected_vs_actual(pid) do
    GenServer.call(pid, :compare_expected_vs_actual)
  end

  def integrate_learning(pid, learning_insights) do
    GenServer.call(pid, {:integrate_learning, learning_insights})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      identity: %{
        name: "VSM-MCP System",
        type: :autonomous_agent,
        version: "1.0.0",
        purpose: "Viable System Model with Model Context Protocol integration"
      },
      capabilities: %{
        mcp_integration: :active,
        llm_integration: :active,
        autonomous_execution: :active,
        capability_acquisition: :active,
        consciousness: :developing
      },
      current_state: %{
        operational_status: :running,
        cognitive_load: 0.0,
        performance_level: 0.8,
        learning_rate: 0.1
      },
      self_assessment: %{
        confidence: 0.7,
        accuracy: 0.8,
        adaptability: 0.9,
        last_assessment: DateTime.utc_now()
      },
      expectations: %{
        success_rate: 0.8,
        response_time: 5000,
        quality_threshold: 0.7
      },
      actual_performance: %{
        success_rate: 0.0,
        average_response_time: 0,
        quality_scores: []
      },
      learning_history: []
    }
    
    Logger.info("SelfModel module initialized")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_model, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:update, observations}, _from, state) do
    updated_state = process_observations(state, observations)
    Logger.debug("Self-model updated with observations: #{inspect(observations)}")
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call(:compare_expected_vs_actual, _from, state) do
    comparison = %{
      success_rate_delta: state.actual_performance.success_rate - state.expectations.success_rate,
      response_time_delta: state.actual_performance.average_response_time - state.expectations.response_time,
      overall_performance: calculate_overall_performance(state),
      areas_for_improvement: identify_improvement_areas(state)
    }
    
    {:reply, comparison, state}
  end

  @impl true
  def handle_call({:integrate_learning, learning_insights}, _from, state) do
    updated_capabilities = update_capabilities_from_learning(state.capabilities, learning_insights)
    updated_assessment = update_self_assessment(state.self_assessment, learning_insights)
    
    new_state = %{state |
      capabilities: updated_capabilities,
      self_assessment: updated_assessment,
      learning_history: [learning_insights | Enum.take(state.learning_history, 49)]
    }
    
    Logger.info("Integrated learning insights into self-model")
    {:reply, :ok, new_state}
  end

  # Private Functions

  defp process_observations(state, observations) when is_map(observations) do
    current_state = Map.merge(state.current_state, observations)
    actual_performance = update_actual_performance(state.actual_performance, observations)
    
    %{state |
      current_state: current_state,
      actual_performance: actual_performance
    }
  end

  defp process_observations(state, _observations), do: state

  defp update_actual_performance(performance, observations) do
    performance
    |> update_if_present(observations, :success_rate)
    |> update_if_present(observations, :response_time)
  end

  defp update_if_present(performance, observations, key) do
    case Map.get(observations, key) do
      nil -> performance
      value -> Map.put(performance, key, value)
    end
  end

  defp calculate_overall_performance(state) do
    success_component = state.actual_performance.success_rate * 0.5
    efficiency_component = calculate_efficiency_score(state) * 0.5
    Float.round(success_component + efficiency_component, 2)
  end

  defp calculate_efficiency_score(state) do
    expected_time = state.expectations.response_time
    actual_time = state.actual_performance.average_response_time
    
    if actual_time > 0 do
      min(expected_time / actual_time, 1.0)
    else
      0.0
    end
  end

  defp identify_improvement_areas(state) do
    areas = []
    
    areas = if state.actual_performance.success_rate < state.expectations.success_rate do
      [:success_rate | areas]
    else
      areas
    end
    
    areas = if state.actual_performance.average_response_time > state.expectations.response_time do
      [:response_time | areas]
    else
      areas
    end
    
    areas
  end

  defp update_capabilities_from_learning(capabilities, learning_insights) when is_map(learning_insights) do
    Enum.reduce(learning_insights, capabilities, fn {skill, level}, acc ->
      case skill do
        :mcp_integration -> Map.put(acc, :mcp_integration, level)
        :llm_integration -> Map.put(acc, :llm_integration, level)
        :autonomous_execution -> Map.put(acc, :autonomous_execution, level)
        :capability_acquisition -> Map.put(acc, :capability_acquisition, level)
        _ -> acc
      end
    end)
  end

  defp update_capabilities_from_learning(capabilities, _), do: capabilities

  defp update_self_assessment(assessment, learning_insights) when is_map(learning_insights) do
    confidence_boost = Map.get(learning_insights, :confidence_boost, 0.0)
    accuracy_update = Map.get(learning_insights, :accuracy_update, 0.0)
    
    %{assessment |
      confidence: min(assessment.confidence + confidence_boost, 1.0),
      accuracy: min(assessment.accuracy + accuracy_update, 1.0),
      last_assessment: DateTime.utc_now()
    }
  end

  defp update_self_assessment(assessment, _), do: assessment
end