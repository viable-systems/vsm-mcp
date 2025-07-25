defmodule VsmMcp.MCP.CapabilityRouter do
  @moduledoc """
  Routes tasks to appropriate MCP servers based on their capabilities.
  Manages the mapping between high-level capabilities and specific MCP tools.
  """
  
  use GenServer
  require Logger
  
  alias VsmMcp.MCP.{JsonRpcClient, ExternalServerSpawner}
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Execute a capability-based task. Routes to the appropriate MCP server.
  """
  def execute_task(capability, task_params) do
    GenServer.call(__MODULE__, {:execute_task, capability, task_params}, 60_000)
  end
  
  @doc """
  Get available capabilities and their servers.
  """
  def list_capabilities do
    GenServer.call(__MODULE__, :list_capabilities)
  end
  
  @doc """
  Refresh capability mappings from running servers.
  """
  def refresh_capabilities do
    GenServer.cast(__MODULE__, :refresh_capabilities)
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      capability_map: %{},
      server_tools: %{},
      initialized_servers: MapSet.new()
    }
    
    # Initial capability discovery
    Process.send_after(self(), :initial_setup, 1000)
    
    # Schedule periodic refresh every 5 seconds
    Process.send_after(self(), :periodic_refresh, 5000)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:execute_task, capability, task_params}, _from, state) do
    result = execute_capability_task(capability, task_params, state)
    {:reply, result, state}
  end
  
  @impl true
  def handle_call(:list_capabilities, _from, state) do
    capabilities = build_capability_list(state)
    {:reply, capabilities, state}
  end
  
  @impl true
  def handle_cast(:refresh_capabilities, state) do
    new_state = discover_all_capabilities(state)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:initial_setup, state) do
    Logger.info("Initializing MCP capability router...")
    new_state = discover_all_capabilities(state)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:periodic_refresh, state) do
    Logger.debug("Refreshing MCP capabilities...")
    new_state = discover_all_capabilities(state)
    
    # Schedule next refresh
    Process.send_after(self(), :periodic_refresh, 5000)
    
    {:noreply, new_state}
  end
  
  # Private functions
  
  defp discover_all_capabilities(state) do
    servers = ExternalServerSpawner.list_running_servers()
    
    Enum.reduce(servers, state, fn server, acc_state ->
      if server.status == :running do
        discover_server_capabilities(server, acc_state)
      else
        acc_state
      end
    end)
  end
  
  defp discover_server_capabilities(server, state) do
    server_id = server.id
    
    # Initialize if needed
    state = if MapSet.member?(state.initialized_servers, server_id) do
      state
    else
      case JsonRpcClient.initialize_server(server_id) do
        {:ok, _} ->
          Logger.info("Initialized MCP server: #{server_id}")
          Map.update!(state, :initialized_servers, &MapSet.put(&1, server_id))
        {:error, reason} ->
          Logger.error("Failed to initialize #{server_id}: #{inspect(reason)}")
          state
      end
    end
    
    # List tools
    case JsonRpcClient.list_tools(server_id) do
      {:ok, %{"tools" => tools}} ->
        update_capability_mappings(server, tools, state)
      {:error, reason} ->
        Logger.error("Failed to list tools for #{server_id}: #{inspect(reason)}")
        state
    end
  end
  
  defp update_capability_mappings(server, tools, state) do
    server_id = server.id
    
    # Store tools for this server
    state = Map.update!(state, :server_tools, &Map.put(&1, server_id, tools))
    
    # Update capability mappings based on package and tools
    state = case server.package do
      "blockchain-mcp-server" ->
        state
        |> add_capability_mapping("blockchain", server_id)
        |> add_capability_mapping("ethereum", server_id)
        |> add_capability_mapping("vanity_address", server_id)
        
      "@shtse8/filesystem-mcp" ->
        state
        |> add_capability_mapping("filesystem", server_id)
        |> add_capability_mapping("file_operations", server_id)
        
      "smart-memory-mcp" ->
        state
        |> add_capability_mapping("memory", server_id)
        |> add_capability_mapping("persistence", server_id)
        
      "database-mcp" ->
        state
        |> add_capability_mapping("database", server_id)
        |> add_capability_mapping("sql", server_id)
        
      _ ->
        state
    end
    
    state
  end
  
  defp add_capability_mapping(state, capability, server_id) do
    Map.update!(state, :capability_map, fn cap_map ->
      Map.update(cap_map, capability, [server_id], &[server_id | &1])
    end)
  end
  
  defp execute_capability_task(capability, task_params, state) do
    case Map.get(state.capability_map, capability) do
      nil ->
        {:error, {:capability_not_found, capability}}
        
      [] ->
        {:error, {:no_servers_for_capability, capability}}
        
      [server_id | _] ->
        # Route to the first available server
        execute_on_server(server_id, capability, task_params, state)
    end
  end
  
  defp execute_on_server(server_id, capability, task_params, state) do
    # Map capability to specific tool based on task
    tool_name = determine_tool_name(capability, task_params, state)
    
    case tool_name do
      {:ok, tool} ->
        Logger.info("Executing #{tool} on server #{server_id}")
        
        # Extract tool-specific params
        tool_params = case {capability, tool} do
          {"blockchain", "generateVanityAddress"} ->
            %{
              "prefix" => Map.get(task_params, "prefix") || Map.get(task_params, :prefix),
              "caseSensitive" => Map.get(task_params, "caseSensitive") || Map.get(task_params, :caseSensitive) || false
            }
          _ ->
            # Remove type field as it's not needed by the tool
            Map.delete(task_params, "type") |> Map.delete(:type)
        end
        
        JsonRpcClient.call_tool(server_id, tool, tool_params)
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp determine_tool_name(capability, task_params, _state) do
    # Map high-level capabilities to specific MCP tools
    # Handle both string and atom types
    task_type = case Map.get(task_params, "type") || Map.get(task_params, :type) do
      type when is_binary(type) -> String.to_atom(type)
      type when is_atom(type) -> type
      _ -> nil
    end
    
    tool = case {capability, task_type} do
      {"blockchain", :vanity_address} ->
        "generateVanityAddress"
        
      {"blockchain", :cast_command} ->
        cmd = Map.get(task_params, "command") || Map.get(task_params, :command)
        "cast_" <> to_string(cmd)
        
      {"filesystem", :read_file} ->
        "readFile"
        
      {"filesystem", :write_file} ->
        "writeFile"
        
      {"memory", :store} ->
        "memoryStore"
        
      {"memory", :retrieve} ->
        "memoryRetrieve"
        
      {"database", :query} ->
        "query"
        
      _ ->
        nil
    end
    
    if tool do
      {:ok, tool}
    else
      {:error, {:unknown_task_type, capability, task_type}}
    end
  end
  
  defp build_capability_list(state) do
    Enum.map(state.capability_map, fn {capability, server_ids} ->
      servers = Enum.map(server_ids, fn id ->
        case Map.get(state.server_tools, id) do
          nil -> %{server_id: id, tools: []}
          tools -> %{server_id: id, tools: Enum.map(tools, & &1["name"])}
        end
      end)
      
      %{
        capability: capability,
        servers: servers
      }
    end)
  end
end