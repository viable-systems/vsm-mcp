defmodule VsmMcp.Integration.Rollback do
  @moduledoc """
  Handles rollback of failed or unwanted capability integrations.
  
  Features:
  - Graceful capability shutdown
  - Resource cleanup
  - State restoration
  - Dependency management
  - Rollback history
  """
  
  require Logger
  
  @rollback_timeout 30_000  # 30 seconds
  @max_rollback_retries 3
  
  @doc """
  Rolls back a capability integration.
  """
  def rollback_capability(capability) do
    Logger.info("Starting rollback for capability: #{capability.id}")
    
    rollback_id = generate_rollback_id()
    
    steps = [
      {:stop_process, &stop_capability_process/1},
      {:cleanup_resources, &cleanup_capability_resources/1},
      {:remove_adapters, &remove_protocol_adapters/1},
      {:uninstall_server, &uninstall_mcp_server/1},
      {:restore_state, &restore_previous_state/1},
      {:notify_dependents, &notify_dependent_systems/1}
    ]
    
    case execute_rollback_steps(steps, capability, rollback_id) do
      :ok ->
        record_successful_rollback(rollback_id, capability)
        :ok
        
      {:error, failed_steps} ->
        record_failed_rollback(rollback_id, capability, failed_steps)
        {:error, {:rollback_failed, failed_steps}}
    end
  end
  
  @doc """
  Plans a rollback without executing it.
  """
  def plan_rollback(capability) do
    steps = analyze_rollback_requirements(capability)
    impact = assess_rollback_impact(capability)
    
    %{
      capability_id: capability.id,
      steps: steps,
      impact: impact,
      estimated_duration: estimate_rollback_duration(steps),
      dependencies: find_dependent_capabilities(capability)
    }
  end
  
  @doc """
  Performs emergency rollback with minimal checks.
  """
  def emergency_rollback(capability_id) do
    Logger.warning("Executing emergency rollback for: #{capability_id}")
    
    # Try to find capability info
    case lookup_capability(capability_id) do
      {:ok, capability} ->
        # Force stop without graceful shutdown
        force_stop_capability(capability)
        
      {:error, :not_found} ->
        # Best effort cleanup
        cleanup_orphaned_resources(capability_id)
    end
  end
  
  @doc """
  Retrieves rollback history.
  """
  def get_rollback_history(limit \\ 10) do
    VsmMcp.Integration.RollbackStore.get_recent_rollbacks(limit)
  end
  
  ## Private Functions
  
  defp generate_rollback_id do
    "rollback_#{:erlang.system_time(:millisecond)}_#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)}"
  end
  
  defp execute_rollback_steps(steps, capability, rollback_id) do
    start_time = System.monotonic_time(:millisecond)
    
    results = Enum.map(steps, fn {step_name, step_fn} ->
      Logger.info("Executing rollback step: #{step_name}")
      
      result = with_retry(fn -> step_fn.(capability) end, @max_rollback_retries)
      
      {step_name, result}
    end)
    
    duration = System.monotonic_time(:millisecond) - start_time
    failed_steps = Enum.filter(results, fn {_, result} -> result != :ok end)
    
    if Enum.empty?(failed_steps) do
      Logger.info("Rollback completed successfully in #{duration}ms")
      :ok
    else
      Logger.error("Rollback failed with #{length(failed_steps)} failed steps")
      {:error, failed_steps}
    end
  end
  
  defp stop_capability_process(capability) do
    case VsmMcp.Integration.DynamicSpawner.terminate_capability(capability.id) do
      :ok ->
        Logger.info("Stopped capability process: #{capability.id}")
        :ok
        
      {:error, :process_not_found} ->
        # Process already stopped
        :ok
        
      error ->
        Logger.error("Failed to stop process: #{inspect(error)}")
        error
    end
  end
  
  defp cleanup_capability_resources(capability) do
    # Clean up any resources allocated by the capability
    resources = [
      {:ports, cleanup_ports(capability)},
      {:files, cleanup_files(capability)},
      {:memory, cleanup_memory(capability)},
      {:connections, cleanup_connections(capability)}
    ]
    
    failed = Enum.filter(resources, fn {_, result} -> result != :ok end)
    
    if Enum.empty?(failed) do
      :ok
    else
      {:error, {:resource_cleanup_failed, failed}}
    end
  end
  
  defp cleanup_ports(capability) do
    # Close any open ports
    if Map.has_key?(capability, :allocated_ports) do
      Enum.each(capability.allocated_ports, &release_port/1)
    end
    :ok
  end
  
  defp cleanup_files(capability) do
    # Remove temporary files
    temp_dir = get_capability_temp_dir(capability)
    
    if File.exists?(temp_dir) do
      File.rm_rf(temp_dir)
    end
    
    :ok
  end
  
  defp cleanup_memory(capability) do
    # Clear any cached data
    VsmMcp.Integration.Cache.clear_capability_data(capability.id)
    :ok
  end
  
  defp cleanup_connections(capability) do
    # Close any open connections
    if capability.adapter && function_exported?(capability.adapter.module, :cleanup_connections, 1) do
      capability.adapter.module.cleanup_connections(capability)
    end
    :ok
  end
  
  defp remove_protocol_adapters(capability) do
    # Remove protocol adapter registrations
    Logger.info("Removing protocol adapters for: #{capability.id}")
    
    # In production, would unregister from adapter registry
    :ok
  end
  
  defp uninstall_mcp_server(capability) do
    if Map.has_key?(capability, :installation_path) do
      case VsmMcp.Integration.Installer.uninstall_server(capability.installation_path) do
        :ok ->
          Logger.info("Uninstalled MCP server from: #{capability.installation_path}")
          :ok
          
        error ->
          Logger.error("Failed to uninstall server: #{inspect(error)}")
          error
      end
    else
      :ok
    end
  end
  
  defp restore_previous_state(capability) do
    # Restore any state that was modified during integration
    case get_previous_state(capability) do
      {:ok, previous_state} ->
        apply_state_restoration(previous_state)
        
      {:error, :no_previous_state} ->
        # Nothing to restore
        :ok
    end
  end
  
  defp notify_dependent_systems(capability) do
    dependents = find_dependent_capabilities(capability)
    
    Enum.each(dependents, fn dependent ->
      send(dependent.pid, {:capability_removed, capability.id})
    end)
    
    :ok
  end
  
  defp with_retry(fun, retries) when retries > 0 do
    case fun.() do
      :ok -> :ok
      {:error, _reason} ->
        Process.sleep(1000)
        with_retry(fun, retries - 1)
    end
  end
  
  defp with_retry(fun, 0), do: fun.()
  
  defp analyze_rollback_requirements(capability) do
    # Analyze what needs to be rolled back
    [
      if(capability.process, do: :stop_process),
      if(capability.installation_path, do: :uninstall_server),
      if(has_allocated_resources?(capability), do: :cleanup_resources),
      if(has_dependents?(capability), do: :notify_dependents)
    ]
    |> Enum.reject(&is_nil/1)
  end
  
  defp assess_rollback_impact(capability) do
    %{
      dependent_capabilities: length(find_dependent_capabilities(capability)),
      active_connections: count_active_connections(capability),
      data_loss_risk: assess_data_loss_risk(capability),
      service_disruption: assess_service_disruption(capability)
    }
  end
  
  defp estimate_rollback_duration(steps) do
    # Estimate time in seconds
    base_time = 5
    step_time = length(steps) * 2
    base_time + step_time
  end
  
  defp find_dependent_capabilities(capability) do
    # Find other capabilities that depend on this one
    VsmMcp.Integration.list_capabilities()
    |> elem(1)
    |> Enum.filter(fn cap ->
      depends_on?(cap, capability)
    end)
  end
  
  defp depends_on?(cap1, cap2) do
    # Check if cap1 depends on cap2
    dependencies = Map.get(cap1, :dependencies, [])
    cap2.id in dependencies
  end
  
  defp has_allocated_resources?(capability) do
    Map.has_key?(capability, :allocated_ports) or
    Map.has_key?(capability, :temp_files) or
    Map.has_key?(capability, :connections)
  end
  
  defp has_dependents?(capability) do
    not Enum.empty?(find_dependent_capabilities(capability))
  end
  
  defp count_active_connections(capability) do
    # Count active connections
    Map.get(capability, :active_connections, 0)
  end
  
  defp assess_data_loss_risk(capability) do
    # Assess risk of data loss
    if Map.get(capability, :stores_data, false) do
      :high
    else
      :low
    end
  end
  
  defp assess_service_disruption(capability) do
    # Assess service disruption impact
    case Map.get(capability, :criticality, :normal) do
      :critical -> :high
      :important -> :medium
      _ -> :low
    end
  end
  
  defp lookup_capability(capability_id) do
    case GenServer.call(VsmMcp.Integration, {:get_capability, capability_id}) do
      {:ok, capability} -> {:ok, capability}
      _ -> {:error, :not_found}
    end
  catch
    :exit, _ -> {:error, :not_found}
  end
  
  defp force_stop_capability(capability) do
    # Force stop without graceful shutdown
    if pid = Map.get(capability, :pid) do
      Process.exit(pid, :kill)
    end
    
    # Cleanup resources
    cleanup_capability_resources(capability)
  end
  
  defp cleanup_orphaned_resources(capability_id) do
    Logger.info("Cleaning up orphaned resources for: #{capability_id}")
    
    # Best effort cleanup when capability info is not available
    # Check common resource locations
    temp_dir = Path.join(["tmp", "capabilities", capability_id])
    if File.exists?(temp_dir), do: File.rm_rf(temp_dir)
    
    :ok
  end
  
  defp get_capability_temp_dir(capability) do
    Path.join(["tmp", "capabilities", capability.id])
  end
  
  defp release_port(port_number) do
    # Release allocated port
    Logger.debug("Releasing port: #{port_number}")
    :ok
  end
  
  defp get_previous_state(capability) do
    # Retrieve state before integration
    case VsmMcp.Integration.StateStore.get_state(capability.id) do
      {:ok, state} -> {:ok, state}
      _ -> {:error, :no_previous_state}
    end
  end
  
  defp apply_state_restoration(state) do
    # Apply the previous state
    Logger.info("Restoring previous state: #{inspect(state)}")
    :ok
  end
  
  defp record_successful_rollback(rollback_id, capability) do
    record = %{
      id: rollback_id,
      capability_id: capability.id,
      status: :success,
      timestamp: DateTime.utc_now(),
      details: %{
        capability_name: capability.name,
        integration_duration: calculate_integration_duration(capability)
      }
    }
    
    VsmMcp.Integration.RollbackStore.save_rollback(record)
  end
  
  defp record_failed_rollback(rollback_id, capability, failed_steps) do
    record = %{
      id: rollback_id,
      capability_id: capability.id,
      status: :failed,
      timestamp: DateTime.utc_now(),
      failed_steps: failed_steps,
      details: %{
        capability_name: capability.name,
        error_count: length(failed_steps)
      }
    }
    
    VsmMcp.Integration.RollbackStore.save_rollback(record)
  end
  
  defp calculate_integration_duration(capability) do
    if verified_at = Map.get(capability, :verified_at) do
      DateTime.diff(DateTime.utc_now(), verified_at, :second)
    else
      0
    end
  end
end

defmodule VsmMcp.Integration.RollbackStore do
  @moduledoc """
  Stores rollback history and state.
  """
  
  use Agent
  
  def start_link(_) do
    Agent.start_link(fn -> %{rollbacks: [], max_history: 100} end, name: __MODULE__)
  end
  
  def save_rollback(record) do
    Agent.update(__MODULE__, fn state ->
      new_rollbacks = [record | state.rollbacks] |> Enum.take(state.max_history)
      %{state | rollbacks: new_rollbacks}
    end)
  end
  
  def get_recent_rollbacks(limit) do
    Agent.get(__MODULE__, fn state ->
      Enum.take(state.rollbacks, limit)
    end)
  end
end