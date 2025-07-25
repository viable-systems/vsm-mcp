defmodule VsmMcp.Core.PureLLMDiscovery do
  @moduledoc """
  Pure LLM-based MCP discovery with NO hardcoded mappings.
  This proves the system can work entirely through LLM as external variety source.
  """
  
  use GenServer
  require Logger
  
  alias VsmMcp.LLM.Integration
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Discover MCP servers using ONLY LLM - no fallbacks!
  """
  def discover_servers(capabilities) do
    GenServer.call(__MODULE__, {:discover_via_llm_only, capabilities}, 60_000)
  end
  
  @impl true
  def init(_opts) do
    {:ok, %{}}
  end
  
  @impl true
  def handle_call({:discover_via_llm_only, capabilities}, _from, state) do
    Logger.info("🤖 Using PURE LLM discovery - no hardcoded mappings!")
    
    # For each capability, ask LLM to find MCP servers
    servers = capabilities
    |> Enum.flat_map(&discover_capability_via_llm/1)
    |> Enum.uniq_by(& &1.name)
    
    {:reply, {:ok, servers}, state}
  end
  
  defp discover_capability_via_llm(capability) do
    Logger.info("📡 Asking LLM about: #{capability}")
    
    # Call the actual LLM integration
    case Integration.process_operation(%{
      type: :research_mcp_servers,
      target: capability,
      query: """
      Find MCP (Model Context Protocol) servers that can handle #{capability}.
      Search npm registry, GitHub, and other sources.
      Return actual package names that exist or could exist.
      Focus on packages starting with 'mcp-server-' or '@modelcontextprotocol/server-'.
      """
    }) do
      {:ok, llm_response} ->
        # Parse LLM response to extract package names
        parse_llm_response(llm_response, capability)
        
      {:error, reason} ->
        Logger.error("LLM query failed: #{reason}")
        []
    end
  end
  
  defp parse_llm_response(response, capability) do
    # Extract package names from LLM response
    # In real implementation, this would parse the LLM's structured response
    
    # For now, simulate parsing - in production this would extract from LLM text
    response
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "mcp-server"))
    |> Enum.map(fn line ->
      # Extract package name from line like "1. mcp-server-foo - Description"
      case Regex.run(~r/((?:@[\w-]+\/)?mcp-server-[\w-]+)/, line) do
        [_, package] ->
          %{
            name: package,
            capability: capability,
            source: :llm,
            description: "Discovered by LLM for #{capability}",
            relevance_score: 0.9
          }
        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end