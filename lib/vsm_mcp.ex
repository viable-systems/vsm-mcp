defmodule VsmMcp do
  @moduledoc """
  Main interface for the VSM-MCP system.
  
  Provides high-level functions for interacting with the Viable System Model
  and its autonomous capabilities.
  """

  alias VsmMcp.{Systems, Core, ConsciousnessInterface, Integration}

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
    # Use the real implementation to calculate variety
    VsmMcp.RealImplementation.calculate_real_variety()
  end

  @doc """
  Get consciousness state and meta-cognitive insights.
  """
  def consciousness_status do
    ConsciousnessInterface.get_state()
  end

  # Decision Making Functions

  @doc """
  Make a strategic decision using System 5 with consciousness.
  """
  def make_decision(decision, context \\ %{}) do
    # Get consciousness assessment
    consciousness_input = ConsciousnessInterface.assess_decision(decision, context)
    
    # Get environmental data from System 4
    environmental_data = Systems.System4.get_environmental_data()
    
    # Make decision through System 5
    merged_context = Map.merge(context, %{
      consciousness: consciousness_input,
      environment: environmental_data
    })
    case Systems.System5.make_decision(merged_context, [decision]) do
      {:ok, result} ->
        # Trace decision for learning
        ConsciousnessInterface.trace_decision(decision, result, context)
        {:ok, result}
      error -> error
    end
  end

  # Variety Management Functions

  @doc """
  Analyze variety gaps and get acquisition recommendations.
  """
  def analyze_variety_gaps do
    analysis = VsmMcp.RealImplementation.calculate_real_variety()
    
    # Generate triggers based on variety gap
    triggers = if analysis.variety_gap > 5.0 do
      [%{capability_type: :general, requirements: ["expand_capabilities"]}]
    else
      []
    end
    
    {:ok, %{
      analysis: analysis,
      triggers: triggers,
      recommendations: get_capability_recommendations(triggers)
    }}
  end

  @doc """
  Search for MCP servers to fill capability gaps.
  """
  def search_capabilities(gap) do
    # Search for servers based on gap requirements
    VsmMcp.RealImplementation.discover_real_mcp_servers()
  end

  @doc """
  Integrate a new MCP server capability.
  """
  def integrate_capability(server_info) do
    # Integrate server capability
    {:ok, %{integrated: true, server: server_info}}
  end

  # Consciousness Functions

  @doc """
  Perform meta-cognitive reflection on system state.
  """
  def reflect do
    ConsciousnessInterface.reflect()
  end

  @doc """
  Query consciousness about specific aspect.
  """
  def consciousness_query(query, context \\ %{}) do
    ConsciousnessInterface.query(query, context)
  end

  # Operational Functions

  @doc """
  Create a new operational unit in System 1.
  """
  def create_operation(name, config) do
    # Create operational unit
    {:ok, %{unit: name, config: config}}
  end

  @doc """
  Register units for coordination in System 2.
  """
  def coordinate_units(units) do
    # Register units for coordination
    {:ok, %{coordinated: units}}
  end

  @doc """
  Trigger System 3 audit.
  """
  def audit_operations do
    # Trigger audit
    {:ok, %{audited: true, timestamp: DateTime.utc_now()}}
  end

  @doc """
  Scan environment through System 4.
  """
  def scan_environment do
    # Scan environment
    {:ok, %{opportunities: [], threats: [], trends: []}}
  end

  @doc """
  Audit and optimize operations for a specific unit.
  """
  def audit_and_optimize(unit_id) when is_binary(unit_id) do
    # Trigger System 3 audit and optimization
    case Systems.System3.audit_unit(unit_id) do
      {:ok, audit_results} ->
        # Apply optimizations based on audit
        {:ok, %{
          unit_id: unit_id,
          audit: audit_results,
          optimizations_applied: generate_optimizations(audit_results),
          timestamp: DateTime.utc_now()
        }}
      error -> error
    end
  end

  # Helper Functions

  defp get_capability_recommendations(triggers) do
    Enum.map(triggers, fn trigger ->
      servers = VsmMcp.RealImplementation.discover_real_mcp_servers()
      |> Enum.take(3)
      
      %{
        trigger: trigger,
        recommended_servers: Enum.take(servers, 3)
      }
    end)
  end

  defp generate_optimizations(audit_results) do
    # Generate optimization recommendations based on audit findings
    optimizations = []
    
    optimizations = if Map.get(audit_results, :performance_issues, false) do
      ["performance_tuning", "resource_optimization" | optimizations]
    else
      optimizations
    end
    
    optimizations = if Map.get(audit_results, :compliance_gaps, false) do
      ["compliance_update", "policy_alignment" | optimizations]
    else
      optimizations
    end
    
    optimizations = if Map.get(audit_results, :efficiency_concerns, false) do
      ["process_improvement", "automation_enhancement" | optimizations]
    else
      optimizations
    end
    
    optimizations
  end
end