defmodule VsmMcp.Integration do
  @moduledoc """
  Dynamic capability integration system for VSM MCP.
  
  This module orchestrates the discovery, installation, and integration
  of MCP servers to fill variety gaps in the system.
  """
  
  use GenServer
  require Logger
  
  alias VsmMcp.Integration.{
    Installer,
    CapabilityMatcher,
    DynamicSpawner,
    ProtocolAdapter,
    Sandbox,
    Verifier,
    Rollback
  }
  
  @doc """
  Starts the integration system.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Discovers and integrates new MCP servers to fill variety gaps.
  """
  def integrate_capability(variety_gap, options \\ []) do
    GenServer.call(__MODULE__, {:integrate, variety_gap, options}, :infinity)
  end
  
  @doc """
  Lists all integrated capabilities.
  """
  def list_capabilities do
    GenServer.call(__MODULE__, :list_capabilities)
  end
  
  @doc """
  Removes an integrated capability.
  """
  def remove_capability(capability_id) do
    GenServer.call(__MODULE__, {:remove, capability_id})
  end
  
  ## Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      capabilities: %{},
      sandbox_processes: %{},
      rollback_history: [],
      integration_metrics: %{
        successful: 0,
        failed: 0,
        rolled_back: 0
      }
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:integrate, variety_gap, options}, _from, state) do
    Logger.info("Starting integration for variety gap: #{inspect(variety_gap)}")
    
    case integrate_capability_pipeline(variety_gap, options, state) do
      {:ok, capability, new_state} ->
        {:reply, {:ok, capability}, new_state}
        
      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end
  
  @impl true
  def handle_call(:list_capabilities, _from, state) do
    capabilities = Map.values(state.capabilities)
    {:reply, {:ok, capabilities}, state}
  end
  
  @impl true
  def handle_call({:remove, capability_id}, _from, state) do
    case Map.get(state.capabilities, capability_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
        
      capability ->
        # Perform rollback
        case Rollback.rollback_capability(capability) do
          :ok ->
            new_capabilities = Map.delete(state.capabilities, capability_id)
            new_state = %{state | capabilities: new_capabilities}
            {:reply, :ok, new_state}
            
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end
  
  ## Private Functions
  
  defp integrate_capability_pipeline(variety_gap, options, state) do
    with {:ok, mcp_servers} <- CapabilityMatcher.find_matching_servers(variety_gap),
         {:ok, selected_server} <- select_best_server(mcp_servers, variety_gap),
         {:ok, installation_path} <- Installer.install_server(selected_server),
         {:ok, sandbox_result} <- Sandbox.test_server(installation_path, selected_server),
         {:ok, verified} <- Verifier.verify_capability(sandbox_result, variety_gap),
         {:ok, adapter} <- ProtocolAdapter.create_adapter(selected_server, verified),
         {:ok, spawned_process} <- DynamicSpawner.spawn_capability(adapter, verified) do
      
      capability = %{
        id: generate_capability_id(),
        variety_gap: variety_gap,
        mcp_server: selected_server,
        installation_path: installation_path,
        adapter: adapter,
        process: spawned_process,
        verified_at: DateTime.utc_now(),
        metrics: sandbox_result.metrics
      }
      
      new_capabilities = Map.put(state.capabilities, capability.id, capability)
      new_metrics = update_metrics(state.integration_metrics, :successful)
      
      new_state = %{state | 
        capabilities: new_capabilities,
        integration_metrics: new_metrics
      }
      
      Logger.info("Successfully integrated capability: #{capability.id}")
      {:ok, capability, new_state}
    else
      {:error, reason} ->
        Logger.error("Integration failed: #{inspect(reason)}")
        new_metrics = update_metrics(state.integration_metrics, :failed)
        new_state = %{state | integration_metrics: new_metrics}
        
        # Attempt rollback if partial installation occurred
        handle_integration_failure(reason, state)
        
        {:error, reason, new_state}
    end
  end
  
  defp select_best_server(mcp_servers, variety_gap) do
    # Score servers based on capability match, performance, and reliability
    scored_servers = Enum.map(mcp_servers, fn server ->
      score = calculate_server_score(server, variety_gap)
      {server, score}
    end)
    
    case Enum.max_by(scored_servers, &elem(&1, 1), fn -> nil end) do
      nil -> {:error, :no_suitable_server}
      {server, _score} -> {:ok, server}
    end
  end
  
  defp calculate_server_score(server, variety_gap) do
    # Scoring based on:
    # - Capability match percentage
    # - Performance metrics
    # - Community support
    # - Security rating
    # - License compatibility
    
    capability_score = CapabilityMatcher.calculate_match_score(server, variety_gap)
    performance_score = calculate_performance_score(server)
    reliability_score = calculate_reliability_score(server)
    
    # Weighted average
    capability_score * 0.5 + performance_score * 0.3 + reliability_score * 0.2
  end
  
  defp calculate_performance_score(server) do
    # Based on benchmarks, resource usage, etc.
    Map.get(server, :performance_rating, 0.5)
  end
  
  defp calculate_reliability_score(server) do
    # Based on stars, downloads, last update, etc.
    stars = Map.get(server, :stars, 0)
    downloads = Map.get(server, :downloads, 0)
    
    # Normalize to 0-1 scale
    stars_score = min(stars / 1000, 1.0)
    downloads_score = min(downloads / 10000, 1.0)
    
    (stars_score + downloads_score) / 2
  end
  
  defp generate_capability_id do
    "cap_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
  
  defp update_metrics(metrics, type) do
    Map.update!(metrics, type, &(&1 + 1))
  end
  
  defp handle_integration_failure(reason, state) do
    # Log failure details for analysis
    failure_record = %{
      timestamp: DateTime.utc_now(),
      reason: reason,
      state_snapshot: sanitize_state(state)
    }
    
    # Store in rollback history for potential recovery
    Logger.warning("Integration failure recorded: #{inspect(failure_record)}")
  end
  
  defp sanitize_state(state) do
    # Remove sensitive information before logging
    %{
      capability_count: map_size(state.capabilities),
      metrics: state.integration_metrics
    }
  end
end