defmodule VsmMcp do
  @moduledoc """
  Main interface for the VSM-MCP system.
  
  Provides high-level functions for interacting with the Viable System Model
  and its autonomous capabilities.
  """

  alias VsmMcp.{Systems, Variety, Consciousness, Integration}

  # System Status Functions

  @doc """
  Get the current status of all VSM systems.
  """
  def system_status do
    %{
      system1: Systems.System1.get_status(),
      system2: Systems.System2.get_status(),
      system3: Systems.System3.get_status(),
      system4: Systems.System4.get_status(),
      system5: Systems.System5.get_status(),
      variety: variety_status(),
      consciousness: consciousness_status()
    }
  end

  @doc """
  Get variety analysis including gaps and recommendations.
  """
  def variety_status do
    case Variety.Analyst.calculate_variety() do
      {:ok, analysis} -> analysis
      {:error, reason} -> %{error: reason}
    end
  end

  @doc """
  Get consciousness state and meta-cognitive insights.
  """
  def consciousness_status do
    Consciousness.Interface.get_state()
  end

  # Decision Making Functions

  @doc """
  Make a strategic decision using System 5 with consciousness.
  """
  def make_decision(decision, context \\ %{}) do
    # Get consciousness assessment
    consciousness_input = Consciousness.Interface.assess_decision(decision, context)
    
    # Get environmental data from System 4
    environmental_data = Systems.System4.get_environmental_data()
    
    # Make decision through System 5
    case Systems.System5.make_decision(decision, Map.merge(context, %{
      consciousness: consciousness_input,
      environment: environmental_data
    })) do
      {:ok, result} ->
        # Trace decision for learning
        Consciousness.Interface.trace_decision(decision, result, context)
        {:ok, result}
      error -> error
    end
  end

  # Variety Management Functions

  @doc """
  Analyze variety gaps and get acquisition recommendations.
  """
  def analyze_variety_gaps do
    with {:ok, analysis} <- Variety.Analyst.calculate_variety(),
         {:ok, triggers} <- Variety.Analyst.generate_acquisition_triggers(analysis) do
      {:ok, %{
        analysis: analysis,
        triggers: triggers,
        recommendations: get_capability_recommendations(triggers)
      }}
    end
  end

  @doc """
  Search for MCP servers to fill capability gaps.
  """
  def search_capabilities(gap) do
    Integration.CapabilityMatcher.match_servers_to_gap(gap)
  end

  @doc """
  Integrate a new MCP server capability.
  """
  def integrate_capability(server_info) do
    Integration.integrate_server(server_info)
  end

  # Consciousness Functions

  @doc """
  Perform meta-cognitive reflection on system state.
  """
  def reflect do
    Consciousness.Interface.reflect()
  end

  @doc """
  Query consciousness about specific aspect.
  """
  def consciousness_query(query, context \\ %{}) do
    Consciousness.Interface.query(query, context)
  end

  # Operational Functions

  @doc """
  Create a new operational unit in System 1.
  """
  def create_operation(name, config) do
    Systems.System1.create_unit(name, config)
  end

  @doc """
  Register units for coordination in System 2.
  """
  def coordinate_units(units) do
    Systems.System2.register_units(units)
  end

  @doc """
  Trigger System 3 audit.
  """
  def audit_operations do
    Systems.System3.audit_all()
  end

  @doc """
  Scan environment through System 4.
  """
  def scan_environment do
    Systems.System4.scan_environment()
  end

  # Helper Functions

  defp get_capability_recommendations(triggers) do
    Enum.map(triggers, fn trigger ->
      servers = Integration.CapabilityMatcher.match_servers_to_gap(%{
        capability_type: trigger.capability_type,
        requirements: trigger.requirements
      })
      
      %{
        trigger: trigger,
        recommended_servers: Enum.take(servers, 3)
      }
    end)
  end
end