defmodule VsmMcp.MCP.JsonRpcClient do
  @moduledoc """
  JSON-RPC client for communicating with spawned MCP servers via stdio.
  Handles request/response correlation and proper protocol formatting.
  """
  
  use GenServer
  require Logger
  
  @default_timeout 30_000
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Execute a JSON-RPC method on a specific MCP server.
  """
  def execute(server_id, method, params, timeout \\ @default_timeout) do
    GenServer.call(__MODULE__, {:execute, server_id, method, params, timeout}, timeout + 1000)
  end
  
  @doc """
  Initialize MCP protocol with a server.
  """
  def initialize_server(server_id, client_info \\ nil) do
    params = %{
      "protocolVersion" => "2024-11-05",
      "capabilities" => %{},
      "clientInfo" => client_info || %{
        "name" => "vsm-mcp",
        "version" => "1.0.0"
      }
    }
    
    execute(server_id, "initialize", params)
  end
  
  @doc """
  List available tools/methods from an MCP server.
  """
  def list_tools(server_id) do
    execute(server_id, "tools/list", %{})
  end
  
  @doc """
  Call a specific tool on an MCP server.
  """
  def call_tool(server_id, tool_name, arguments, timeout \\ @default_timeout) do
    params = %{
      "name" => tool_name,
      "arguments" => arguments
    }
    
    execute(server_id, "tools/call", params, timeout)
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      pending_requests: %{},
      request_id: 1,
      server_connections: %{}
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:execute, server_id, method, params, timeout}, from, state) do
    case get_server_port(server_id) do
      {:ok, port} ->
        # Generate request ID
        request_id = state.request_id
        
        # Build JSON-RPC request
        request = %{
          "jsonrpc" => "2.0",
          "id" => request_id,
          "method" => method,
          "params" => params
        }
        
        # Encode and send
        json_request = Jason.encode!(request) <> "\n"
        Port.command(port, json_request)
        
        # Store pending request
        pending = %{
          from: from,
          method: method,
          server_id: server_id,
          timestamp: System.monotonic_time(:millisecond),
          timeout: timeout
        }
        
        new_state = state
        |> Map.update!(:pending_requests, &Map.put(&1, request_id, pending))
        |> Map.update!(:request_id, &(&1 + 1))
        
        # Set timeout timer
        Process.send_after(self(), {:timeout, request_id}, timeout)
        
        {:noreply, new_state}
        
      {:error, reason} ->
        {:reply, {:error, {:server_not_found, reason}}, state}
    end
  end
  
  @impl true
  def handle_info({port, {:data, {:eol, line}}}, state) when is_port(port) do
    # Parse JSON response
    case Jason.decode(line) do
      {:ok, response} ->
        handle_json_response(response, port, state)
        
      {:error, _reason} ->
        # Not valid JSON, might be server output
        Logger.debug("MCP server output: #{line}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({port, {:data, {:noeol, partial}}}, state) when is_port(port) do
    # Handle partial data - buffer it
    # For now, just log it
    Logger.debug("Partial data from MCP server: #{partial}")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:timeout, request_id}, state) do
    case Map.get(state.pending_requests, request_id) do
      nil ->
        {:noreply, state}
        
      pending ->
        GenServer.reply(pending.from, {:error, :timeout})
        new_state = Map.update!(state, :pending_requests, &Map.delete(&1, request_id))
        {:noreply, new_state}
    end
  end
  
  @impl true
  def handle_info({port, {:exit_status, status}}, state) when is_port(port) do
    Logger.warning("MCP server port exited with status: #{status}")
    # Clean up any pending requests for this port
    {:noreply, state}
  end
  
  # Private functions
  
  defp get_server_port(server_id) do
    # Get the port from ExternalServerSpawner
    servers = VsmMcp.MCP.ExternalServerSpawner.list_running_servers()
    
    case Enum.find(servers, fn s -> s.id == server_id end) do
      nil -> {:error, :not_found}
      server -> {:ok, server.port}
    end
  end
  
  defp handle_json_response(%{"id" => id} = response, _port, state) when is_integer(id) do
    case Map.get(state.pending_requests, id) do
      nil ->
        Logger.warning("Received response for unknown request ID: #{id}")
        {:noreply, state}
        
      pending ->
        # Reply to waiting client
        result = case response do
          %{"result" => result} -> 
            {:ok, result}
          %{"error" => error} -> 
            {:error, {:json_rpc_error, error}}
          _ ->
            {:error, :invalid_response}
        end
        
        GenServer.reply(pending.from, result)
        new_state = Map.update!(state, :pending_requests, &Map.delete(&1, id))
        {:noreply, new_state}
    end
  end
  
  defp handle_json_response(response, _port, state) do
    # Response without ID (notification or other)
    Logger.debug("Received JSON-RPC notification: #{inspect(response)}")
    {:noreply, state}
  end
end