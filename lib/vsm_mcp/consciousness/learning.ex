defmodule VsmMcp.ConsciousnessInterface.Learning do
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def process_outcome(pid, decision_id, outcome, analysis) do
    GenServer.call(pid, {:process_outcome, decision_id, outcome, analysis})
  end

  def get_recent_insights(pid) do
    GenServer.call(pid, :get_recent_insights)
  end

  def assess_learning_rate(pid) do
    GenServer.call(pid, :assess_learning_rate)
  end

  def get_knowledge_base(pid) do
    GenServer.call(pid, :get_knowledge_base)
  end

  @impl true
  def init(_opts) do
    state = %{
      knowledge_base: %{},
      learning_outcomes: [],
      insights: [],
      learning_rate: 0.1,
      performance_history: []
    }
    Logger.info("Learning module initialized")
    {:ok, state}
  end

  @impl true
  def handle_call({:process_outcome, decision_id, outcome, analysis}, _from, state) do
    learning_record = %{
      decision_id: decision_id,
      outcome: outcome,
      analysis: analysis,
      timestamp: DateTime.utc_now()
    }
    
    updated_outcomes = [learning_record | Enum.take(state.learning_outcomes, 99)]
    updated_knowledge = update_knowledge_from_outcome(state.knowledge_base, outcome, analysis)
    new_insights = generate_insights_from_outcome(outcome, analysis)
    updated_insights = new_insights ++ Enum.take(state.insights, 49)
    
    new_state = %{state |
      learning_outcomes: updated_outcomes,
      knowledge_base: updated_knowledge,
      insights: updated_insights
    }
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_recent_insights, _from, state) do
    recent_insights = Enum.take(state.insights, 10)
    {:reply, recent_insights, state}
  end

  @impl true
  def handle_call(:assess_learning_rate, _from, state) do
    rate_assessment = %{
      current_rate: state.learning_rate,
      recent_outcomes: length(state.learning_outcomes),
      knowledge_growth: map_size(state.knowledge_base),
      insights_generated: length(state.insights)
    }
    {:reply, rate_assessment, state}
  end

  @impl true
  def handle_call(:get_knowledge_base, _from, state) do
    {:reply, state.knowledge_base, state}
  end

  defp update_knowledge_from_outcome(knowledge_base, outcome, analysis) do
    case outcome do
      :success -> 
        # Extract successful patterns
        pattern_key = extract_pattern_key(analysis)
        Map.update(knowledge_base, pattern_key, 1, &(&1 + 1))
      :failure ->
        # Learn from failures
        failure_key = "failure_" <> extract_pattern_key(analysis)
        Map.update(knowledge_base, failure_key, 1, &(&1 + 1))
      _ -> knowledge_base
    end
  end

  defp extract_pattern_key(analysis) when is_map(analysis) do
    # Simple pattern extraction
    Map.get(analysis, :type, "general") |> to_string()
  end

  defp extract_pattern_key(_analysis), do: "general"

  defp generate_insights_from_outcome(outcome, analysis) do
    case outcome do
      :success -> 
        [%{
          type: :success_pattern,
          content: "Successful approach: #{inspect(analysis)}",
          timestamp: DateTime.utc_now()
        }]
      :failure ->
        [%{
          type: :failure_analysis,
          content: "Failed approach: #{inspect(analysis)}",
          timestamp: DateTime.utc_now()
        }]
      _ -> []
    end
  end
end