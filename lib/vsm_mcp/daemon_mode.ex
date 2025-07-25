defmodule VsmMcp.DaemonMode do
  @moduledoc """
  Autonomous daemon mode for VSM-MCP with 30-second monitoring loops.
  This is the REAL implementation that makes the system truly autonomous.
  """
  use GenServer
  require Logger

  alias VsmMcp.Core.{VarietyCalculator, MCPDiscovery}
  alias VsmMcp.Integration.{CapabilityMatcher, ServerManager, VarietyDetector}
  alias VsmMcp.ConsciousnessInterface
  alias VsmMcp.MCP.ExternalServerSpawner

  @default_interval 30_000  # 30 seconds
  @variety_threshold 0.85   # Trigger if variety ratio drops below 85%

  defstruct [
    :interval,
    :timer_ref,
    :monitoring_active,
    :last_variety_check,
    :last_decision,
    :autonomous_actions,
    :state
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_monitoring do
    GenServer.call(__MODULE__, :start_monitoring)
  end

  def stop_monitoring do
    GenServer.call(__MODULE__, :stop_monitoring)
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  def inject_variety_gap(gap_info) do
    GenServer.cast(__MODULE__, {:inject_variety_gap, gap_info})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, @default_interval)
    
    state = %__MODULE__{
      interval: interval,
      monitoring_active: false,
      autonomous_actions: [],
      state: :initialized
    }
    
    # Auto-start monitoring
    {:ok, state, {:continue, :start_monitoring}}
  end

  @impl true
  def handle_continue(:start_monitoring, state) do
    Logger.info("VSM Daemon Mode started - monitoring every #{state.interval}ms")
    new_state = schedule_next_check(state)
    {:noreply, %{new_state | monitoring_active: true, state: :monitoring}}
  end

  @impl true
  def handle_call(:start_monitoring, _from, state) do
    if state.monitoring_active do
      {:reply, {:error, :already_monitoring}, state}
    else
      new_state = schedule_next_check(state)
      {:reply, :ok, %{new_state | monitoring_active: true, state: :monitoring}}
    end
  end

  @impl true
  def handle_call(:stop_monitoring, _from, state) do
    new_state = cancel_timer(state)
    {:reply, :ok, %{new_state | monitoring_active: false, state: :paused}}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      state: state.state,
      monitoring_active: state.monitoring_active,
      interval: state.interval,
      last_variety_check: state.last_variety_check,
      last_decision: state.last_decision,
      autonomous_actions_count: length(state.autonomous_actions)
    }
    {:reply, status, state}
  end

  @impl true
  def handle_cast({:inject_variety_gap, gap_info}, state) do
    Logger.warn("⚠️  Variety gap injected: #{inspect(gap_info)}")
    
    # Immediately respond to injected gap
    {:ok, new_state} = handle_variety_gap(gap_info, state)
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:check_variety, state) do
    Logger.debug("🔍 Running autonomous variety check...")
    
    # Perform variety analysis
    new_state = perform_variety_check(state)
    
    # Schedule next check
    final_state = schedule_next_check(new_state)
    
    {:noreply, final_state}
  end

  # Private Functions

  defp perform_variety_check(state) do
    timestamp = DateTime.utc_now()
    
    # Calculate current variety state
    current_variety = VarietyCalculator.calculate()
    required_variety = calculate_required_variety()
    
    variety_ratio = current_variety / max(required_variety, 1)
    
    Logger.info("📊 Variety Check - Current: #{current_variety}, Required: #{required_variety}, Ratio: #{Float.round(variety_ratio, 2)}")
    
    # Update consciousness
    # TODO: Re-enable when ConsciousnessInterface.update_awareness is implemented
    # ConsciousnessInterface.update_awareness(%{
    #   variety_ratio: variety_ratio,
    #   timestamp: timestamp,
    #   source: :daemon_monitoring
    # })
    
    # Check if intervention needed
    new_state = if variety_ratio < @variety_threshold do
      gap_info = %{
        current_variety: current_variety,
        required_variety: required_variety,
        gap: required_variety - current_variety,
        ratio: variety_ratio,
        timestamp: timestamp
      }
      
      Logger.warn("⚡ Variety gap detected! Ratio: #{Float.round(variety_ratio, 2)} - Triggering autonomous response")
      
      {:ok, updated_state} = handle_variety_gap(gap_info, state)
      updated_state
    else
      state
    end
    
    %{new_state | last_variety_check: timestamp}
  end

  defp handle_variety_gap(gap_info, state) do
    # Determine what capabilities we're missing
    missing_capabilities = analyze_capability_gap(gap_info)
    
    Logger.info("🎯 Missing capabilities identified: #{inspect(missing_capabilities)}")
    
    # Trigger autonomous acquisition
    acquisition_results = Enum.map(missing_capabilities, fn capability ->
      acquire_capability_autonomously(capability)
    end)
    
    # Record the autonomous action
    action = %{
      timestamp: DateTime.utc_now(),
      trigger: :variety_gap,
      gap_info: gap_info,
      capabilities_sought: missing_capabilities,
      results: acquisition_results,
      success: Enum.any?(acquisition_results, &match?({:ok, _}, &1))
    }
    
    # Update consciousness with decision
    decision = %{
      action: :acquire_capabilities,
      reason: "Variety ratio #{Float.round(gap_info.ratio, 2)} below threshold",
      capabilities: missing_capabilities,
      timestamp: action.timestamp
    }
    
    # TODO: Re-enable when ConsciousnessInterface.record_decision is implemented
    # ConsciousnessInterface.record_decision(decision)
    
    new_state = %{state | 
      autonomous_actions: [action | state.autonomous_actions],
      last_decision: decision
    }
    
    {:ok, new_state}
  end

  defp acquire_capability_autonomously(capability) do
    Logger.info("🔄 Autonomously acquiring capability: #{capability}")
    
    with {:ok, servers} <- MCPDiscovery.discover_servers([capability]),
         {:ok, best_match} <- CapabilityMatcher.find_best_match(capability, servers),
         {:ok, integration_result} <- integrate_mcp_server(best_match) do
      
      Logger.info("✅ Successfully acquired #{capability} via #{best_match.name}")
      {:ok, %{capability: capability, server: best_match.name, result: integration_result}}
    else
      error ->
        Logger.error("❌ Failed to acquire #{capability}: #{inspect(error)}")
        {:error, %{capability: capability, reason: error}}
    end
  end

  defp integrate_mcp_server(server_info) do
    # Use the external server spawner for real integration
    package_name = server_info[:package] || server_info[:name] || "mcp-server-#{server_info[:id]}"
    
    case ExternalServerSpawner.spawn_mcp_server(package_name, %{}) do
      {:ok, server_id, result} -> 
        # Register with server manager
        ServerManager.register_server(server_id, result)
        {:ok, %{server_id: server_id, result: result}}
      error -> 
        error
    end
  end

  defp analyze_capability_gap(gap_info) do
    # Check if specific capabilities were requested
    requested = case gap_info do
      %{required_capabilities: caps} when is_list(caps) and length(caps) > 0 -> 
        caps
      _ -> 
        # Fallback to intelligent analysis
        base_capabilities = [
          "filesystem",      # @modelcontextprotocol/server-filesystem
          "memory",          # @modelcontextprotocol/server-memory
          "database"         # @modelcontextprotocol/server-sqlite, postgres, etc
        ]
        
        # Add specific capabilities based on gap size
        specific = if Map.get(gap_info, :gap, 0) > 10 do
          ["containerization", "monitoring", "cloud"]  # docker, prometheus, aws servers
        else
          ["git", "api", "search"]  # git, fetch, brave-search servers
        end
        
        base_capabilities ++ specific
    end
    
    requested |> Enum.take(5)  # Allow up to 5 capabilities
  end

  defp calculate_required_variety do
    # Calculate based on system load and complexity
    base_variety = 50
    
    # Add variety based on active connections
    connection_variety = ServerManager.list_servers()
    |> Enum.count()
    |> Kernel.*(5)
    
    # Add variety based on pending tasks
    task_variety = 10  # Would integrate with task queue
    
    base_variety + connection_variety + task_variety
  end

  defp schedule_next_check(state) do
    timer_ref = Process.send_after(self(), :check_variety, state.interval)
    %{state | timer_ref: timer_ref}
  end

  defp cancel_timer(%{timer_ref: nil} = state), do: state
  defp cancel_timer(%{timer_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | timer_ref: nil}
  end
end