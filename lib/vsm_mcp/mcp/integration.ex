defmodule VsmMcp.MCP.Integration do
  @moduledoc """
  High-level integration module for MCP functionality in VSM-MCP.
  Combines ServerManager with the existing MCP client/server infrastructure.
  """
  
  alias VsmMcp.MCP.{ServerManager, Client, Server}
  alias VsmMcp.MCP.ServerManager.ServerConfig
  require Logger
  
  @doc """
  Start an MCP server with automatic process management.
  """
  def start_managed_server(type, opts \\ []) do
    config = case type do
      :stdio ->
        ServerConfig.create_preset(:stdio, opts)
        
      :tcp ->
        ServerConfig.create_preset(:tcp, opts)
        
      :websocket ->
        ServerConfig.create_preset(:websocket, opts)
        
      :internal ->
        %{
          type: :internal,
          id: opts[:id] || "internal_mcp_#{:erlang.unique_integer([:positive])}",
          server_opts: Keyword.merge([
            name: {:via, Registry, {VsmMcp.Registry, opts[:id] || :mcp_server}},
            auto_start: true
          ], opts[:server_opts] || [])
        }
        |> Map.merge(Map.take(opts, [:restart_policy, :pool_size, :health_check]))
    end
    
    ServerManager.start_server(config)
  end
  
  @doc """
  Connect to an MCP server with automatic reconnection and pooling.
  """
  def connect_managed_client(server_id, opts \\ []) do
    with {:ok, conn} <- ServerManager.get_connection(server_id),
         {:ok, client} <- create_client_for_connection(conn, opts) do
      {:ok, client}
    end
  end
  
  @doc """
  Start multiple MCP servers from a configuration file.
  """
  def start_from_config(config_path) do
    with {:ok, content} <- File.read(config_path),
         {:ok, config} <- Jason.decode(content) do
      
      servers = config["servers"] || []
      
      results = Enum.map(servers, fn server_config ->
        normalized = normalize_server_config(server_config)
        
        case ServerManager.start_server(normalized) do
          {:ok, id} ->
            Logger.info("Started server: #{id}")
            {:ok, id}
            
          {:error, reason} = error ->
            Logger.error("Failed to start server #{server_config["id"]}: #{inspect(reason)}")
            error
        end
      end)
      
      {:ok, results}
    end
  end
  
  @doc """
  Discover and start available MCP servers on the system.
  """
  def discover_and_start_servers(opts \\ []) do
    search_paths = opts[:search_paths] || default_search_paths()
    
    discovered = Enum.flat_map(search_paths, &discover_in_path/1)
    
    Logger.info("Discovered #{length(discovered)} MCP servers")
    
    # Start discovered servers
    results = Enum.map(discovered, fn server_info ->
      config = %{
        type: :external,
        id: server_info.id,
        command: server_info.command,
        args: server_info.args,
        metadata: %{
          discovered_at: server_info.path,
          name: server_info.name,
          version: server_info.version
        }
      }
      
      ServerManager.start_server(config)
    end)
    
    {:ok, results}
  end
  
  @doc """
  Setup a complete MCP environment with VSM integration.
  """
  def setup_vsm_mcp_environment(opts \\ []) do
    Logger.info("Setting up VSM-MCP environment...")
    
    # 1. Start internal VSM MCP server
    {:ok, vsm_server_id} = start_managed_server(:internal, 
      id: "vsm_mcp_main",
      server_opts: [
        transport: opts[:transport] || :stdio,
        port: opts[:port] || 3333
      ],
      restart_policy: :permanent,
      pool_size: 20
    )
    
    # 2. Register VSM tools and resources
    register_vsm_capabilities(vsm_server_id)
    
    # 3. Start any configured external servers
    external_servers = if config_file = opts[:config_file] do
      case start_from_config(config_file) do
        {:ok, servers} -> servers
        _ -> []
      end
    else
      []
    end
    
    # 4. Setup health monitoring dashboard
    if opts[:enable_dashboard] do
      start_health_dashboard()
    end
    
    {:ok, %{
      vsm_server: vsm_server_id,
      external_servers: external_servers,
      status: :ready
    }}
  end
  
  @doc """
  Get a unified view of all MCP servers and their health.
  """
  def get_system_health do
    with {:ok, status} <- ServerManager.get_status() do
      health_report = %{
        timestamp: DateTime.utc_now(),
        servers: Enum.map(status.servers, fn server ->
          %{
            id: server.id,
            type: server.config.type,
            status: server.status,
            health: server.health_status,
            uptime: server.started_at && DateTime.diff(DateTime.utc_now(), server.started_at, :second),
            restart_count: server.restart_count,
            last_health_check: server.last_health_check
          }
        end),
        metrics: status.metrics,
        resource_usage: status.resource_usage,
        summary: %{
          total: length(status.servers),
          healthy: Enum.count(status.servers, &(&1.health_status == :healthy)),
          unhealthy: Enum.count(status.servers, &(&1.health_status == :unhealthy)),
          unknown: Enum.count(status.servers, &(&1.health_status == :unknown))
        }
      }
      
      {:ok, health_report}
    end
  end
  
  # Private functions
  
  defp create_client_for_connection(conn, opts) do
    # Create appropriate client based on connection type
    client_opts = Keyword.merge([
      name: {:via, Registry, {VsmMcp.Registry, make_ref()}}
    ], opts)
    
    Client.start_link(client_opts)
  end
  
  defp normalize_server_config(config) when is_map(config) do
    base = %{
      id: config["id"],
      type: String.to_atom(config["type"] || "external"),
      restart_policy: String.to_atom(config["restart_policy"] || "permanent")
    }
    
    case base.type do
      :external ->
        Map.merge(base, %{
          command: config["command"],
          args: config["args"] || [],
          env: config["env"] || %{},
          working_dir: config["working_dir"]
        })
        
      :internal ->
        Map.merge(base, %{
          server_opts: config["server_opts"] || []
        })
        
      _ ->
        base
    end
  end
  
  defp default_search_paths do
    [
      # NPM global
      Path.join([System.user_home!(), ".npm", "bin"]),
      # Yarn global
      Path.join([System.user_home!(), ".yarn", "bin"]),
      # Local node_modules
      Path.join([File.cwd!(), "node_modules", ".bin"]),
      # System paths
      "/usr/local/bin",
      "/usr/bin"
    ]
  end
  
  defp discover_in_path(path) do
    if File.exists?(path) do
      path
      |> File.ls!()
      |> Enum.filter(&String.contains?(&1, "mcp"))
      |> Enum.map(fn file ->
        full_path = Path.join(path, file)
        
        %{
          id: "discovered_#{file}",
          name: file,
          command: full_path,
          args: [],
          path: path,
          version: get_version(full_path)
        }
      end)
    else
      []
    end
  rescue
    _ -> []
  end
  
  defp get_version(command) do
    case System.cmd(command, ["--version"], stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      _ -> "unknown"
    end
  rescue
    _ -> "unknown"
  end
  
  defp register_vsm_capabilities(server_id) do
    # This would register all VSM tools, resources, and prompts
    # with the managed server
    Logger.info("Registering VSM capabilities with server #{server_id}")
    
    # Example: Register consciousness tools
    # Server.register_tool(server_id, "consciousness.reflect", %{
    #   description: "Reflect on current state",
    #   input_schema: %{...},
    #   execute: &VsmMcp.ConsciousnessInterface.reflect/1
    # })
    
    :ok
  end
  
  defp start_health_dashboard do
    Logger.info("Starting health monitoring dashboard...")
    # This would start a Phoenix LiveView dashboard
    # showing real-time health metrics
    :ok
  end
end