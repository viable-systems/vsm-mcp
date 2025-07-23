defmodule VsmMcp.Integration.ProtocolAdapter do
  @moduledoc """
  Creates protocol adapters for different MCP server transport types.
  
  Supports:
  - Stdio (standard input/output)
  - WebSocket
  - HTTP/REST
  - TCP sockets
  """
  
  require Logger
  
  @doc """
  Creates an adapter for the given MCP server configuration.
  """
  def create_adapter(server_config, verified_capability) do
    adapter_module = determine_adapter_module(server_config)
    
    adapter = %{
      module: adapter_module,
      config: build_adapter_config(server_config, verified_capability),
      server: server_config,
      capability: verified_capability
    }
    
    # Validate adapter can connect
    case test_adapter(adapter) do
      :ok -> {:ok, adapter}
      {:error, reason} -> {:error, {:adapter_test_failed, reason}}
    end
  end
  
  ## Private Functions
  
  defp determine_adapter_module(server_config) do
    transport = Map.get(server_config, :transport, "stdio")
    
    case String.downcase(transport) do
      "stdio" -> VsmMcp.Integration.Adapters.StdioAdapter
      "websocket" -> VsmMcp.Integration.Adapters.WebSocketAdapter
      "ws" -> VsmMcp.Integration.Adapters.WebSocketAdapter
      "http" -> VsmMcp.Integration.Adapters.HttpAdapter
      "tcp" -> VsmMcp.Integration.Adapters.TcpAdapter
      _ -> VsmMcp.Integration.Adapters.StdioAdapter  # Default
    end
  end
  
  defp build_adapter_config(server_config, verified_capability) do
    base_config = %{
      name: server_config.name,
      installation_path: verified_capability.installation_path,
      start_command: get_start_command(server_config, verified_capability),
      env: get_environment_vars(server_config),
      timeout: Map.get(server_config, :timeout, 30_000)
    }
    
    # Add transport-specific config
    merge_transport_config(base_config, server_config)
  end
  
  defp get_start_command(server_config, verified_capability) do
    cond do
      Map.has_key?(server_config, :start_command) ->
        server_config.start_command
        
      File.exists?(Path.join(verified_capability.installation_path, "start.sh")) ->
        "./start.sh"
        
      server_config.source_type == :npm ->
        "npm start"
        
      true ->
        "node index.js"
    end
  end
  
  defp get_environment_vars(server_config) do
    default_env = %{
      "MCP_MODE" => "server",
      "NODE_ENV" => "production"
    }
    
    Map.merge(default_env, Map.get(server_config, :env, %{}))
  end
  
  defp merge_transport_config(base_config, server_config) do
    transport_config = case Map.get(server_config, :transport, "stdio") do
      "websocket" ->
        %{
          port: Map.get(server_config, :port, 8080),
          path: Map.get(server_config, :ws_path, "/mcp"),
          secure: Map.get(server_config, :secure, false)
        }
        
      "http" ->
        %{
          port: Map.get(server_config, :port, 3000),
          base_url: Map.get(server_config, :base_url, "/api/mcp")
        }
        
      "tcp" ->
        %{
          port: Map.get(server_config, :port, 9000),
          host: Map.get(server_config, :host, "localhost")
        }
        
      _ ->
        %{}
    end
    
    Map.merge(base_config, transport_config)
  end
  
  defp test_adapter(adapter) do
    # Quick connectivity test
    case adapter.module.test_connection(adapter.config) do
      :ok -> :ok
      error -> error
    end
  end
end

defmodule VsmMcp.Integration.Adapters.StdioAdapter do
  @moduledoc """
  Adapter for stdio-based MCP servers.
  """
  
  @behaviour VsmMcp.Integration.AdapterBehaviour
  
  require Logger
  
  @impl true
  def connect(config) do
    Logger.info("Connecting to stdio MCP server: #{config.name}")
    
    port_opts = [
      :binary,
      :exit_status,
      :use_stdio,
      :stderr_to_stdout,
      {:cd, config.installation_path},
      {:env, Enum.map(config.env, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)},
      {:line, 65536}
    ]
    
    case Port.open({:spawn, config.start_command}, port_opts) do
      port when is_port(port) ->
        # Wait for initialization
        receive do
          {^port, {:data, data}} ->
            Logger.debug("Initial data from MCP server: #{inspect(data)}")
            {:ok, %{port: port, buffer: ""}}
        after
          5000 ->
            Port.close(port)
            {:error, :timeout}
        end
        
      error ->
        {:error, error}
    end
  end
  
  @impl true
  def disconnect(connection) do
    Port.close(connection.port)
    :ok
  end
  
  @impl true
  def execute(connection, method, params) do
    request = build_json_rpc_request(method, params)
    
    case send_request(connection, request) do
      {:ok, response} ->
        parse_response(response)
        
      error ->
        error
    end
  end
  
  @impl true
  def health_check(connection) do
    # Send a simple ping/info request
    case execute(connection, "mcp/info", %{}) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  @impl true
  def reconnect(connection) do
    disconnect(connection)
    Process.sleep(1000)
    connect(connection.config)
  end
  
  @impl true
  def test_connection(config) do
    # Quick test without full initialization
    case System.cmd("which", [extract_command(config.start_command)], cd: config.installation_path) do
      {_, 0} -> :ok
      _ -> {:error, :command_not_found}
    end
  end
  
  ## Private Functions
  
  defp build_json_rpc_request(method, params) do
    %{
      jsonrpc: "2.0",
      id: generate_request_id(),
      method: method,
      params: params
    }
    |> Jason.encode!()
  end
  
  defp send_request(connection, request) do
    Port.command(connection.port, request <> "\n")
    
    receive do
      {port, {:data, {:eol, data}}} when port == connection.port ->
        {:ok, data}
        
      {port, {:data, data}} when port == connection.port ->
        {:ok, data}
        
      {port, {:exit_status, status}} when port == connection.port ->
        {:error, {:process_exited, status}}
        
    after
      30_000 ->
        {:error, :timeout}
    end
  end
  
  defp parse_response(data) do
    case Jason.decode(data) do
      {:ok, %{"result" => result}} ->
        {:ok, result}
        
      {:ok, %{"error" => error}} ->
        {:error, {:rpc_error, error}}
        
      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end
  
  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  defp extract_command(start_command) do
    start_command
    |> String.split(" ")
    |> List.first()
  end
end

defmodule VsmMcp.Integration.Adapters.WebSocketAdapter do
  @moduledoc """
  Adapter for WebSocket-based MCP servers.
  """
  
  @behaviour VsmMcp.Integration.AdapterBehaviour
  
  require Logger
  
  @impl true
  def connect(config) do
    url = build_ws_url(config)
    
    case WebSockex.start_link(url, __MODULE__, %{config: config}) do
      {:ok, pid} -> {:ok, %{pid: pid, config: config}}
      error -> error
    end
  end
  
  @impl true
  def disconnect(connection) do
    WebSockex.stop(connection.pid)
  end
  
  @impl true
  def execute(connection, method, params) do
    request = build_json_rpc_request(method, params)
    
    case WebSockex.call(connection.pid, {:send, request}) do
      {:ok, response} -> parse_response(response)
      error -> error
    end
  end
  
  @impl true
  def health_check(connection) do
    case Process.alive?(connection.pid) do
      true -> :ok
      false -> {:error, :connection_dead}
    end
  end
  
  @impl true
  def reconnect(connection) do
    disconnect(connection)
    Process.sleep(1000)
    connect(connection.config)
  end
  
  @impl true
  def test_connection(config) do
    # Test if server endpoint is reachable
    url = build_ws_url(config)
    uri = URI.parse(url)
    
    case :gen_tcp.connect(String.to_charlist(uri.host), uri.port, [:binary, active: false], 5000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :ok
        
      {:error, reason} ->
        {:error, {:connection_failed, reason}}
    end
  end
  
  ## WebSockex Callbacks
  
  def handle_frame({:text, msg}, state) do
    # Handle incoming messages
    {:ok, state}
  end
  
  def handle_cast({:send, message}, state) do
    {:reply, {:text, message}, state}
  end
  
  ## Private Functions
  
  defp build_ws_url(config) do
    protocol = if config.secure, do: "wss", else: "ws"
    "#{protocol}://localhost:#{config.port}#{config.path}"
  end
  
  defp build_json_rpc_request(method, params) do
    %{
      jsonrpc: "2.0",
      id: generate_request_id(),
      method: method,
      params: params
    }
    |> Jason.encode!()
  end
  
  defp parse_response(data) do
    case Jason.decode(data) do
      {:ok, %{"result" => result}} -> {:ok, result}
      {:ok, %{"error" => error}} -> {:error, {:rpc_error, error}}
      {:error, reason} -> {:error, {:parse_error, reason}}
    end
  end
  
  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end

defmodule VsmMcp.Integration.AdapterBehaviour do
  @moduledoc """
  Behaviour for MCP protocol adapters.
  """
  
  @callback connect(config :: map()) :: {:ok, connection :: any()} | {:error, reason :: any()}
  @callback disconnect(connection :: any()) :: :ok
  @callback execute(connection :: any(), method :: String.t(), params :: map()) ::
    {:ok, result :: any()} | {:error, reason :: any()}
  @callback health_check(connection :: any()) :: :ok | {:error, reason :: any()}
  @callback reconnect(connection :: any()) :: {:ok, connection :: any()} | {:error, reason :: any()}
  @callback test_connection(config :: map()) :: :ok | {:error, reason :: any()}
end