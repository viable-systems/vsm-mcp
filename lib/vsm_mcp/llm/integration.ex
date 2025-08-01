defmodule VsmMcp.LLM.Integration do
  @moduledoc """
  LLM integration for intelligent decision-making in VSM.
  
  Provides interfaces for connecting to various LLM providers
  and using them for enhanced decision-making, analysis, and
  natural language understanding within the VSM framework.
  
  Now with enhanced resilience features:
  - Circuit breakers per provider
  - Automatic retry with exponential backoff
  - Dead letter queue for failed requests
  - Connection pooling and rate limiting
  """
  
  use GenServer
  require Logger
  
  alias VsmMcp.LLM.API
  alias VsmMcp.Resilience.DeadLetterQueue
  
  @default_timeout 30_000
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Analyze a decision using LLM capabilities.
  """
  def analyze_decision(decision, context) do
    GenServer.call(__MODULE__, {:analyze_decision, decision, context}, @default_timeout)
  end
  
  @doc """
  Generate insights from system data.
  """
  def generate_insights(data) do
    GenServer.call(__MODULE__, {:generate_insights, data}, @default_timeout)
  end
  
  @doc """
  Process natural language query about system state.
  """
  def process_query(query) do
    GenServer.call(__MODULE__, {:process_query, query}, @default_timeout)
  end
  
  @doc """
  Generate recommendations based on variety analysis.
  """
  def generate_recommendations(variety_analysis) do
    GenServer.call(__MODULE__, {:generate_recommendations, variety_analysis}, @default_timeout)
  end
  
  @doc """
  Process an operation using LLM when internal variety is insufficient.
  """
  def process_operation(operation) do
    GenServer.call(__MODULE__, {:process_operation, operation}, @default_timeout)
  end
  
  @doc """
  Transform data using LLM capabilities.
  """
  def transform_data(operation) do
    GenServer.call(__MODULE__, {:transform_data, operation}, @default_timeout)
  end
  
  @doc """
  Generate code for a new capability.
  """
  def generate_capability(target) do
    GenServer.call(__MODULE__, {:generate_capability, target}, @default_timeout)
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    provider = Keyword.get(opts, :provider, :local)
    config = Keyword.get(opts, :config, %{})
    
    # Initialize LLM API with resilience features
    :ok = API.init(provider, config)
    
    state = %{
      provider: provider,
      config: config,
      client: init_client(provider, config),
      stats: %{
        total_requests: 0,
        successful_requests: 0,
        failed_requests: 0,
        circuit_breaker_rejections: 0
      }
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:analyze_decision, decision, context}, _from, state) do
    prompt = build_decision_prompt(decision, context)
    
    case query_llm(state.client, prompt) do
      {:ok, analysis} ->
        {:reply, {:ok, parse_decision_analysis(analysis)}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:generate_insights, data}, _from, state) do
    prompt = build_insights_prompt(data)
    
    case query_llm(state.client, prompt) do
      {:ok, response} ->
        {:reply, {:ok, parse_insights(response)}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:process_query, query}, _from, state) do
    # Get current system state for context
    system_state = VsmMcp.system_status()
    prompt = build_query_prompt(query, system_state)
    
    case query_llm(state.client, prompt) do
      {:ok, response} ->
        {:reply, {:ok, response}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:generate_recommendations, variety_analysis}, _from, state) do
    prompt = build_recommendations_prompt(variety_analysis)
    
    case query_llm(state.client, prompt) do
      {:ok, response} ->
        {:reply, {:ok, parse_recommendations(response)}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:process_operation, operation}, _from, state) do
    prompt = build_operation_prompt(operation)
    
    case query_llm(state.client, prompt) do
      {:ok, response} ->
        {:reply, {:ok, response}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:transform_data, operation}, _from, state) do
    prompt = build_transform_prompt(operation)
    
    case query_llm(state.client, prompt) do
      {:ok, response} ->
        {:reply, {:ok, response}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:generate_capability, target}, _from, state) do
    prompt = build_capability_prompt(target)
    
    case query_llm(state.client, prompt) do
      {:ok, code} ->
        {:reply, {:ok, code}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  # Private functions
  
  defp init_client(:local, _config) do
    # Local inference using patterns and heuristics
    %{type: :local}
  end
  
  defp init_client(:openai, config) do
    %{
      type: :openai,
      api_key: config[:api_key],
      model: config[:model] || "gpt-4",
      base_url: "https://api.openai.com/v1"
    }
  end
  
  defp init_client(:anthropic, config) do
    %{
      type: :anthropic,
      api_key: config[:api_key],
      model: config[:model] || "claude-3-opus-20240229",
      base_url: "https://api.anthropic.com/v1"
    }
  end
  
  defp query_llm(%{type: :local}, prompt) do
    # Local heuristic-based responses
    response = local_inference(prompt)
    {:ok, response}
  end
  
  defp query_llm(%{type: :openai} = client, prompt) do
    body = %{
      model: client.model,
      messages: [
        %{role: "system", content: "You are an AI assistant helping with VSM (Viable System Model) analysis and decision-making."},
        %{role: "user", content: prompt}
      ],
      temperature: 0.7
    }
    
    # Use the resilient API client
    API.request(
      :openai,
      "/chat/completions",
      Jason.encode!(body),
      api_key: client.api_key
    )
  end
  
  defp query_llm(%{type: :anthropic} = client, prompt) do
    body = %{
      model: client.model,
      messages: [
        %{role: "user", content: prompt}
      ],
      max_tokens: 1024
    }
    
    # Use the resilient API client
    API.request(
      :anthropic,
      "/messages",
      Jason.encode!(body),
      api_key: client.api_key
    )
  end
  
  defp build_decision_prompt(decision, context) do
    """
    Analyze the following decision in the context of a Viable System Model (VSM):
    
    Decision: #{inspect(decision)}
    
    Context:
    #{inspect(context, pretty: true)}
    
    Please provide:
    1. Potential impacts on each VSM system (1-5)
    2. Risk assessment
    3. Recommendations for implementation
    4. Alternative approaches to consider
    """
  end
  
  defp build_insights_prompt(data) do
    """
    Generate insights from the following VSM system data:
    
    #{inspect(data, pretty: true)}
    
    Focus on:
    1. Patterns and trends
    2. Potential issues or bottlenecks
    3. Optimization opportunities
    4. Strategic recommendations
    """
  end
  
  defp build_query_prompt(query, system_state) do
    """
    User Query: #{query}
    
    Current VSM System State:
    #{inspect(system_state, pretty: true)}
    
    Please provide a helpful and accurate response based on the system state.
    """
  end
  
  defp build_recommendations_prompt(variety_analysis) do
    """
    Based on this variety analysis from a Viable System Model:
    
    #{inspect(variety_analysis, pretty: true)}
    
    Please recommend:
    1. Specific capabilities to acquire
    2. Priority order for addressing variety gaps
    3. Strategic approaches to increase operational variety
    4. Risk mitigation strategies
    """
  end
  
  defp local_inference(prompt) do
    # Simple pattern matching for local inference
    cond do
      String.contains?(prompt, "variety") ->
        "Based on the variety analysis, I recommend focusing on capabilities that directly address the identified gaps. Priority should be given to high-urgency items."
      
      String.contains?(prompt, "decision") ->
        "This decision appears to have system-wide implications. Consider the impact on operational variety and ensure adequate coordination mechanisms."
      
      String.contains?(prompt, "insights") ->
        "The system shows signs of adaptive behavior. Continue monitoring variety metrics and adjust capabilities as needed."
      
      true ->
        "Please provide more specific information for detailed analysis."
    end
  end
  
  defp parse_decision_analysis(text) do
    %{
      raw_analysis: text,
      impacts: extract_impacts(text),
      risks: extract_risks(text),
      recommendations: extract_recommendations(text)
    }
  end
  
  defp parse_insights(text) do
    %{
      raw_insights: text,
      patterns: extract_patterns(text),
      issues: extract_issues(text),
      opportunities: extract_opportunities(text)
    }
  end
  
  defp parse_recommendations(text) do
    %{
      raw_recommendations: text,
      capabilities: extract_capabilities(text),
      priorities: extract_priorities(text),
      strategies: extract_strategies(text)
    }
  end
  
  # Simple extraction functions (can be enhanced with NLP)
  defp extract_impacts(text), do: extract_section(text, "impact")
  defp extract_risks(text), do: extract_section(text, "risk")
  defp extract_recommendations(text), do: extract_section(text, "recommend")
  defp extract_patterns(text), do: extract_section(text, "pattern")
  defp extract_issues(text), do: extract_section(text, "issue")
  defp extract_opportunities(text), do: extract_section(text, "opportunit")
  defp extract_capabilities(text), do: extract_section(text, "capabilit")
  defp extract_priorities(text), do: extract_section(text, "priorit")
  defp extract_strategies(text), do: extract_section(text, "strateg")
  
  defp extract_section(text, keyword) do
    text
    |> String.downcase()
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, keyword))
    |> Enum.map(&String.trim/1)
  end
  
  defp build_operation_prompt(operation) do
    """
    Process this operation for a Viable System Model:
    
    Operation: #{inspect(operation)}
    
    The VSM System 1 needs to process this operation but lacks internal variety to handle it.
    Please provide a solution or approach to complete this operation.
    
    Focus on:
    1. Understanding the operation requirements
    2. Providing actionable steps or code
    3. Identifying any additional resources needed
    """
  end
  
  defp build_transform_prompt(operation) do
    """
    Transform data for a VSM operation:
    
    Input: #{inspect(operation[:input] || operation.input)}
    Desired Output: #{inspect(operation[:output] || operation.output)}
    Context: #{inspect(Map.get(operation, :context, %{}))}
    
    Please provide the transformation logic or steps needed.
    """
  end
  
  defp build_capability_prompt(target) do
    """
    Generate Elixir code for a new VSM capability:
    
    Capability: #{target}
    
    Create a module that implements this capability for integration into the VSM System 1.
    The module should:
    1. Follow Elixir/OTP conventions
    2. Include necessary functions for the capability
    3. Be compatible with the VSM architecture
    4. Include documentation
    
    Return complete, compilable Elixir code.
    """
  end
end