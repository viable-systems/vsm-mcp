defmodule VsmMcp.MCP.ExternalServerSpawner do
  @moduledoc """
  Spawns and manages external MCP servers via JSON-RPC.
  
  Handles NPM package discovery, installation, and spawning
  of external MCP servers in isolated processes.
  """
  
  use GenServer
  require Logger
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def spawn_mcp_server(package_name, config \\ %{}) do
    GenServer.call(__MODULE__, {:spawn_server, package_name, config}, 60_000)
  end
  
  def list_running_servers do
    GenServer.call(__MODULE__, :list_servers)
  end
  
  def get_server_info(server_id) do
    GenServer.call(__MODULE__, {:get_server_info, server_id})
  end
  
  def stop_mcp_server(server_id) do
    GenServer.call(__MODULE__, {:stop_server, server_id})
  end
  
  def get_server_status(server_id) do
    GenServer.call(__MODULE__, {:server_status, server_id})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    state = %{
      running_servers: %{},
      server_configs: %{},
      installation_path: opts[:installation_path] || "/tmp/vsm_mcp_servers",
      next_server_id: 1,
      process_monitors: %{}
    }
    
    # Ensure installation directory exists
    File.mkdir_p!(state.installation_path)
    
    Logger.info("External MCP Server Spawner initialized")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:spawn_server, package_name, config}, _from, state) do
    Logger.info("Spawning MCP server: #{package_name}")
    
    case spawn_external_server(package_name, config, state) do
      {:ok, server_info} ->
        server_id = "server_#{state.next_server_id}"
        
        # Monitor the spawned process (monitor the port, not the OS PID)
        # Ports need to be monitored using erlang:monitor/2
        monitor_ref = :erlang.monitor(:port, server_info.port)
        
        new_state = state
        |> Map.update!(:running_servers, &Map.put(&1, server_id, server_info))
        |> Map.update!(:server_configs, &Map.put(&1, server_id, config))
        |> Map.update!(:process_monitors, &Map.put(&1, monitor_ref, server_id))
        |> Map.update!(:next_server_id, &(&1 + 1))
        
        # Notify capability router to discover the new server
        Process.send_after(self(), {:notify_capability_router, server_id}, 2000)
        
        {:reply, {:ok, server_id, server_info}, new_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:list_servers, _from, state) do
    servers = Enum.map(state.running_servers, fn {id, info} ->
      %{
        id: id,
        package: info.package_name,
        status: get_process_status(info.port),
        pid: info.pid,
        port: info.port,
        started_at: info.started_at
      }
    end)
    
    {:reply, servers, state}
  end
  
  @impl true
  def handle_call({:stop_server, server_id}, _from, state) do
    case Map.get(state.running_servers, server_id) do
      nil ->
        {:reply, {:error, :server_not_found}, state}
      
      server_info ->
        # Stop the server process
        case stop_external_server(server_info) do
          :ok ->
            new_state = state
            |> Map.update!(:running_servers, &Map.delete(&1, server_id))
            |> Map.update!(:server_configs, &Map.delete(&1, server_id))
            
            {:reply, :ok, new_state}
          
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end
  
  @impl true
  def handle_call({:get_server_info, server_id}, _from, state) do
    case Map.get(state.running_servers, server_id) do
      nil ->
        {:reply, {:error, :server_not_found}, state}
      
      server_info ->
        {:reply, {:ok, server_info}, state}
    end
  end
  
  @impl true
  def handle_call({:server_status, server_id}, _from, state) do
    case Map.get(state.running_servers, server_id) do
      nil ->
        {:reply, {:error, :server_not_found}, state}
      
      server_info ->
        status = %{
          id: server_id,
          package: server_info.package_name,
          status: get_process_status(server_info.port),
          uptime: DateTime.diff(DateTime.utc_now(), server_info.started_at, :second),
          communication_status: test_server_communication(server_info)
        }
        
        {:reply, {:ok, status}, state}
    end
  end
  
  @impl true
  def handle_info({:DOWN, monitor_ref, :port, _port, reason}, state) do
    case Map.get(state.process_monitors, monitor_ref) do
      nil ->
        {:noreply, state}
      
      server_id ->
        Logger.warning("MCP server #{server_id} terminated with reason: #{inspect(reason)}")
        
        new_state = state
        |> Map.update!(:running_servers, &Map.delete(&1, server_id))
        |> Map.update!(:server_configs, &Map.delete(&1, server_id))
        |> Map.update!(:process_monitors, &Map.delete(&1, monitor_ref))
        
        {:noreply, new_state}
    end
  end
  
  # Handle port data messages
  @impl true
  def handle_info({port, {:data, data}}, state) when is_port(port) do
    # Find which server this port belongs to
    server_id = Enum.find_value(state.running_servers, fn {id, info} ->
      if info.port == port, do: id
    end)
    
    case data do
      {:eol, line} ->
        Logger.debug("MCP server #{server_id || "unknown"}: #{line}")
      {:noeol, partial} ->
        Logger.debug("MCP server #{server_id || "unknown"} (partial): #{partial}")
      _ ->
        Logger.debug("MCP server #{server_id || "unknown"} data: #{inspect(data)}")
    end
    
    {:noreply, state}
  end
  
  # Handle capability router notification
  @impl true
  def handle_info({:notify_capability_router, _server_id}, state) do
    # Trigger capability discovery refresh
    if Process.whereis(VsmMcp.MCP.CapabilityRouter) do
      VsmMcp.MCP.CapabilityRouter.refresh_capabilities()
    end
    {:noreply, state}
  end
  
  # Handle port exit status
  @impl true  
  def handle_info({port, {:exit_status, status}}, state) when is_port(port) do
    # Find which server this port belongs to
    server_id = Enum.find_value(state.running_servers, fn {id, info} ->
      if info.port == port, do: id
    end)
    
    Logger.warning("MCP server #{server_id || "unknown"} exited with status: #{status}")
    
    # Clean up the server from state if found
    if server_id do
      # Find the monitor ref for this server
      monitor_ref = Enum.find_value(state.process_monitors, fn {ref, id} ->
        if id == server_id, do: ref
      end)
      
      new_state = state
      |> Map.update!(:running_servers, &Map.delete(&1, server_id))
      |> Map.update!(:server_configs, &Map.delete(&1, server_id))
      |> Map.update!(:process_monitors, fn monitors ->
        if monitor_ref, do: Map.delete(monitors, monitor_ref), else: monitors
      end)
      
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  # Private Functions
  
  defp spawn_external_server(package_name, config, state) do
    # Step 1: Install package if not already installed
    case ensure_package_installed(package_name, state) do
      {:ok, package_path} ->
        # Step 2: Find executable
        case find_mcp_executable(package_path, package_name) do
          {:ok, executable_path} ->
            # Step 3: Spawn the process
            spawn_mcp_process(package_name, executable_path, config)
          
          {:error, reason} ->
            {:error, "Failed to find executable: #{reason}"}
        end
      
      {:error, reason} ->
        {:error, "Failed to install package: #{reason}"}
    end
  end
  
  defp ensure_package_installed(package_name, state) do
    package_dir = Path.join(state.installation_path, package_name)
    
    # Check if already installed
    if File.exists?(package_dir) and File.exists?(Path.join(package_dir, "package.json")) do
      {:ok, package_dir}
    else
      install_npm_package(package_name, package_dir)
    end
  end
  
  defp install_npm_package(package_name, install_dir) do
    Logger.info("Installing NPM package: #{package_name}")
    
    # Create directory
    File.mkdir_p!(install_dir)
    
    # Initialize package.json
    case System.cmd("npm", ["init", "-y"], cd: install_dir, stderr_to_stdout: true) do
      {_output, 0} ->
        # Install the package
        case System.cmd("npm", ["install", package_name], cd: install_dir, stderr_to_stdout: true) do
          {_output, 0} ->
            {:ok, install_dir}
          
          {error, exit_code} ->
            {:error, "npm install failed (#{exit_code}): #{error}"}
        end
      
      {error, exit_code} ->
        {:error, "npm init failed (#{exit_code}): #{error}"}
    end
  end
  
  defp find_mcp_executable(package_path, package_name) do
    # Common locations for MCP executables
    possible_paths = [
      Path.join([package_path, "node_modules", ".bin", package_name]),
      Path.join([package_path, "node_modules", ".bin", "mcp-server"]),
      Path.join([package_path, "node_modules", package_name, "bin", "server"]),
      Path.join([package_path, "node_modules", package_name, "dist", "index.js"]),
      Path.join([package_path, "node_modules", package_name, "index.js"]),
      Path.join([package_path, "node_modules", package_name, "src", "index.js"])
    ]
    
    # Find the first existing executable
    case Enum.find(possible_paths, &File.exists?/1) do
      nil ->
        # Try to find package.json and look for main or bin field
        package_json_path = Path.join([package_path, "node_modules", package_name, "package.json"])
        
        case File.read(package_json_path) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, package_info} ->
                find_executable_from_package_json(package_info, package_path, package_name)
              
              _ ->
                {:error, "Invalid package.json"}
            end
          
          _ ->
            {:error, "No executable found and no package.json"}
        end
      
      executable_path ->
        {:ok, executable_path}
    end
  end
  
  defp find_executable_from_package_json(package_info, package_path, package_name) do
    base_path = Path.join([package_path, "node_modules", package_name])
    
    # Check bin field
    case Map.get(package_info, "bin") do
      bin_path when is_binary(bin_path) ->
        full_path = Path.join(base_path, bin_path)
        if File.exists?(full_path), do: {:ok, full_path}, else: check_main_field(package_info, base_path)
      
      bin_map when is_map(bin_map) ->
        # Look for common MCP server entries
        server_entry = bin_map
        |> Map.keys()
        |> Enum.find(fn key -> String.contains?(String.downcase(key), ["mcp", "server"]) end)
        
        case server_entry do
          nil ->
            # Use first available bin entry
            case Map.values(bin_map) |> List.first() do
              nil -> check_main_field(package_info, base_path)
              bin_path ->
                full_path = Path.join(base_path, bin_path)
                if File.exists?(full_path), do: {:ok, full_path}, else: check_main_field(package_info, base_path)
            end
          
          key ->
            bin_path = Map.get(bin_map, key)
            full_path = Path.join(base_path, bin_path)
            if File.exists?(full_path), do: {:ok, full_path}, else: check_main_field(package_info, base_path)
        end
      
      _ ->
        check_main_field(package_info, base_path)
    end
  end
  
  defp check_main_field(package_info, base_path) do
    case Map.get(package_info, "main") do
      nil ->
        {:error, "No executable found in package.json"}
      
      main_path ->
        full_path = Path.join(base_path, main_path)
        if File.exists?(full_path), do: {:ok, full_path}, else: {:error, "Main file not found"}
    end
  end
  
  defp spawn_mcp_process(package_name, executable_path, config) do
    # Prepare arguments
    args = prepare_mcp_args(config)
    
    Logger.info("Spawning MCP process: #{executable_path} with args: #{inspect(args)}")
    
    try do
      # Determine if we need to use node to run the file
      {spawn_cmd, spawn_args} = if String.ends_with?(executable_path, ".js") do
        node_path = System.find_executable("node") || "/usr/bin/node"
        {node_path, [executable_path | args]}
      else
        {executable_path, args}
      end
      
      # Spawn the process using stdio transport
      port = Port.open({:spawn_executable, spawn_cmd}, [
        :binary,
        {:args, spawn_args},
        :exit_status,
        {:line, 65536}
      ])
      
      # Get the OS process ID
      pid = Port.info(port)[:os_pid]
      
      server_info = %{
        package_name: package_name,
        executable_path: executable_path,
        pid: pid,
        port: port,
        config: config,
        started_at: DateTime.utc_now(),
        transport: :stdio
      }
      
      Logger.info("MCP server spawned successfully: #{package_name} (PID: #{pid})")
      {:ok, server_info}
    rescue
      error ->
        {:error, "Failed to spawn process: #{inspect(error)}"}
    end
  end
  
  defp prepare_mcp_args(config) do
    args = []
    
    # Add common MCP server arguments
    args = if Map.has_key?(config, :stdio) do
      ["--stdio" | args]
    else
      args
    end
    
    args = if Map.has_key?(config, :port) do
      ["--port", to_string(config.port) | args]
    else
      args
    end
    
    # Add custom arguments from config
    case Map.get(config, :args) do
      nil -> args
      custom_args when is_list(custom_args) -> custom_args ++ args
      _ -> args
    end
  end
  
  defp stop_external_server(server_info) do
    try do
      Port.close(server_info.port)
      Logger.info("Stopped MCP server: #{server_info.package_name}")
      :ok
    rescue
      error ->
        {:error, "Failed to stop server: #{inspect(error)}"}
    end
  end
  
  defp get_process_status(port) when is_port(port) do
    case Port.info(port) do
      nil -> :stopped
      _ -> :running
    end
  end
  
  defp get_process_status(_), do: :stopped
  
  defp test_server_communication(server_info) do
    # Test basic JSON-RPC communication
    try do
      # Send a simple ping/initialization request
      request = %{
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: %{
          protocolVersion: "2024-11-05",
          capabilities: %{},
          clientInfo: %{
            name: "vsm-mcp",
            version: "1.0.0"
          }
        }
      }
      
      json_request = Jason.encode!(request) <> "\n"
      Port.command(server_info.port, json_request)
      
      # Wait for response (simplified)
      port = server_info.port
      receive do
        {^port, {:data, _data}} ->
          :healthy
      after
        1000 ->
          :no_response
      end
    rescue
      _ ->
        :communication_error
    end
  end
end