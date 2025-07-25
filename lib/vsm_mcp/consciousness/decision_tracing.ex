defmodule VsmMcp.ConsciousnessInterface.DecisionTracing do
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def trace(pid, decision_id, context, reasoning_chain) do
    GenServer.call(pid, {:trace, decision_id, context, reasoning_chain})
  end

  def analyze_patterns(pid) do
    GenServer.call(pid, :analyze_patterns)
  end

  def get_summary(pid) do
    GenServer.call(pid, :get_summary)
  end

  def get_recent(pid, count) do
    GenServer.call(pid, {:get_recent, count})
  end

  @impl true
  def init(_opts) do
    state = %{
      decision_history: [],
      patterns: %{},
      reasoning_chains: %{}
    }
    Logger.info("DecisionTracing module initialized")
    {:ok, state}
  end

  @impl true
  def handle_call({:trace, decision_id, context, reasoning_chain}, _from, state) do
    decision_record = %{
      id: decision_id,
      context: context,
      reasoning_chain: reasoning_chain,
      timestamp: DateTime.utc_now()
    }
    
    updated_history = [decision_record | Enum.take(state.decision_history, 99)]
    updated_chains = Map.put(state.reasoning_chains, decision_id, reasoning_chain)
    
    new_state = %{state |
      decision_history: updated_history,
      reasoning_chains: updated_chains
    }
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:analyze_patterns, _from, state) do
    patterns = analyze_decision_patterns(state.decision_history)
    updated_state = %{state | patterns: patterns}
    {:reply, patterns, updated_state}
  end

  @impl true
  def handle_call(:get_summary, _from, state) do
    summary = %{
      total_decisions: length(state.decision_history),
      recent_decisions: Enum.take(state.decision_history, 5),
      patterns: state.patterns
    }
    {:reply, summary, state}
  end

  @impl true
  def handle_call({:get_recent, count}, _from, state) do
    recent = Enum.take(state.decision_history, count)
    {:reply, recent, state}
  end

  defp analyze_decision_patterns(history) do
    context_patterns = Enum.reduce(history, %{}, fn decision, acc ->
      context_type = Map.get(decision.context, :type, :unknown)
      Map.update(acc, context_type, 1, &(&1 + 1))
    end)
    
    %{context_distribution: context_patterns}
  end
end