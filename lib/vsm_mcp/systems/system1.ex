defmodule VsmMcp.Systems.System1 do
  @moduledoc """
  System 1: Operations (Purpose Fulfillment)
  
  This module implements the operational core of the VSM, responsible for
  executing the primary activities that directly produce value.
  
  Now integrated with bulletproof MCP server management for reliable
  capability acquisition and execution.
  """
  use GenServer
  require Logger
  
  alias VsmMcp.MCP.ServerManager
  # alias VsmMcp.MCP.ServerManager.ServerConfig
  # alias VsmMcp.MCP.Protocol.JsonRpc

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def execute_operation(operation) do
    # Increase timeout for MCP server operations
    timeout = case operation do
      %{type: :capability_acquisition, method: :mcp_integration} -> 120_000  # 2 minutes for MCP server installation
      _ -> 30_000  # 30 seconds for other operations
    end
    GenServer.call(__MODULE__, {:execute, operation}, timeout)
  end

  def get_status do
    GenServer.call(__MODULE__, :status)
  end

  def add_capability(capability) do
    GenServer.cast(__MODULE__, {:add_capability, capability})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %{
      operations: [],
      capabilities: opts[:capabilities] || [],
      metrics: %{
        operations_count: 0,
        success_rate: 1.0,
        average_duration: 0
      },
      mcp_servers: %{},
      server_manager: opts[:server_manager] || ServerManager
    }
    
    Logger.info("System 1 (Operations) initialized with #{length(state.capabilities)} capabilities")
    {:ok, state}
  end

  @impl true
  def handle_call({:execute, operation}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    # Simulate operation execution
    result = case operation do
      %{type: :process} -> process_operation(operation, state)
      %{type: :transform} -> transform_operation(operation, state)
      %{type: :capability_acquisition} -> acquire_capability(operation, state)
      _ -> {:error, "Unknown operation type"}
    end
    
    duration = System.monotonic_time(:millisecond) - start_time
    
    new_state = update_metrics(state, result, duration)
    |> Map.update!(:operations, &[{operation, result, duration} | &1])
    
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    # Include MCP server status
    mcp_status = case ServerManager.get_status(state.server_manager) do
      {:ok, status} -> status
      _ -> %{servers: [], metrics: %{}}
    end
    
    status = %{
      active: true,
      capabilities: state.capabilities,
      metrics: state.metrics,
      recent_operations: Enum.take(state.operations, 5),
      mcp_servers: mcp_status
    }
    {:reply, status, state}
  end

  @impl true
  def handle_cast({:add_capability, capability}, state) do
    new_state = Map.update!(state, :capabilities, &[capability | &1])
    Logger.info("Added capability: #{inspect(capability)}")
    {:noreply, new_state}
  end
  
  @impl true
  def terminate(reason, state) do
    Logger.info("System 1 terminating: #{inspect(reason)}")
    
    # Clean up all MCP servers
    if map_size(state.mcp_servers) > 0 do
      server_ids = Map.keys(state.mcp_servers)
      Logger.info("Stopping #{length(server_ids)} MCP servers...")
      ServerManager.stop_servers(state.server_manager, server_ids, [graceful: true])
    end
    
    :ok
  end
  
  @impl true
  def handle_info({:server_stopped, server_id}, state) do
    Logger.info("MCP server #{server_id} stopped")
    new_state = %{state | mcp_servers: Map.delete(state.mcp_servers, server_id)}
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:track_server, server_id}, state) do
    Logger.debug("Tracking MCP server: #{server_id}")
    new_state = %{state | mcp_servers: Map.put(state.mcp_servers, server_id, %{
      added_at: DateTime.utc_now(),
      status: :active
    })}
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(msg, state) do
    Logger.debug("System 1 received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private Functions

  defp process_operation(operation, state) do
    # Check if we have the capability internally
    if has_capability?(operation.type, state.capabilities) do
      # Handle internally
      Process.sleep(Enum.random(10..50))
      {:ok, %{result: "Processed #{operation.data} internally", timestamp: DateTime.utc_now()}}
    else
      # Use LLM as external variety source
      case VsmMcp.LLM.Integration.process_operation(operation) do
        {:ok, result} ->
          {:ok, %{result: result, source: :llm, timestamp: DateTime.utc_now()}}
        {:error, reason} ->
          # No fallback - return error
          {:error, "Cannot process operation without MCP server: #{reason}"}
      end
    end
  end

  defp transform_operation(operation, state) do
    # Check if we can transform internally
    if has_capability?(:transform, state.capabilities) do
      Process.sleep(Enum.random(20..80))
      {:ok, %{result: "Transformed #{operation.input} to #{operation.output}", timestamp: DateTime.utc_now()}}
    else
      # Use LLM for complex transformations
      case VsmMcp.LLM.Integration.transform_data(operation) do
        {:ok, result} ->
          {:ok, %{result: result, source: :llm, timestamp: DateTime.utc_now()}}
        {:error, reason} ->
          # No fallback - return error
          {:error, "Cannot transform data without MCP server: #{reason}"}
      end
    end
  end
  
  defp acquire_capability(operation, state) do
    # REAL capability acquisition - not simulation!
    %{
      target: target,
      method: method
    } = operation
    
    case method do
      :mcp_integration ->
        # Actually search for and integrate MCP servers
        acquire_mcp_capability(target, state)
      
      :npm_install ->
        # Actually install npm packages
        acquire_npm_capability(target, state)
      
      :llm_generation ->
        # Use LLM to generate the capability
        acquire_llm_capability(target, state)
      
      _ ->
        # No fallback - must use real MCP
        {:error, "Unknown capability acquisition method: #{method}. MCP server required."}
    end
  end
  
  defp acquire_mcp_capability(target, state) do
    # STEP 1: Use LLM to research what MCP servers exist for this capability
    case VsmMcp.LLM.Integration.process_operation(%{
      type: :research_mcp_servers,
      target: target,
      query: "Find MCP servers that can handle #{target}. Search npm registry, GitHub, and other sources."
    }) do
      {:ok, llm_research} ->
        # STEP 2: Search for real MCP servers based on LLM research
        case VsmMcp.RealImplementation.discover_real_mcp_servers() do
          {:ok, servers} when servers != [] ->
            # STEP 3: Use LLM to select the best server
            server_analysis = VsmMcp.LLM.Integration.process_operation(%{
              type: :select_best_mcp_server,
              servers: servers,
              target: target,
              research: llm_research
            })
            
            server = case server_analysis do
              {:ok, _analysis} -> hd(servers)  # For now, use first server
              _ -> hd(servers)
            end
            
            # STEP 4: Install and integrate using the bulletproof MCP server manager
            case start_managed_mcp_server(server, target, state) do
              {:ok, server_id, result} ->
                {:ok, %{
                  status: :acquired,
                  capability: target,
                  method: :mcp_integration,
                  server: server.name,
                  server_id: server_id,
                  llm_research: llm_research,
                  execution_result: result,
                  timestamp: DateTime.utc_now(),
                  details: "Successfully integrated via managed MCP server: #{server.name}"
                }}
              {:error, reason} ->
                Logger.error("MCP server integration failed: #{reason}")
                {:error, "Failed to acquire capability via MCP server: #{reason}"}
            end
          _ ->
            # STEP 5: If no servers found, use LLM to create one
            case VsmMcp.LLM.Integration.generate_capability("mcp_server_for_#{target}") do
              {:ok, mcp_code} ->
                # Save the generated MCP server
                server_path = "lib/vsm_mcp/generated/mcp_#{target}.ex"
                File.mkdir_p!(Path.dirname(server_path))
                File.write!(server_path, mcp_code)
                
                {:ok, %{
                  status: :acquired,
                  capability: target,
                  method: :llm_generation,
                  timestamp: DateTime.utc_now(),
                  details: "LLM generated MCP server: #{server_path}"
                }}
              {:error, reason} ->
                {:error, "Failed to generate MCP server: #{reason}"}
            end
        end
      {:error, reason} ->
        {:error, "LLM research failed: #{reason}"}
    end
  end
  
  defp acquire_npm_capability(target, _state) do
    # Actually install npm package
    case System.cmd("npm", ["install", target, "--save"]) do
      {output, 0} ->
        {:ok, %{
          status: :acquired,
          capability: target,
          method: :npm_install,
          timestamp: DateTime.utc_now(),
          details: "Installed npm package: #{target}\n#{output}"
        }}
      {error, _} ->
        {:error, "Failed to install npm package: #{error}"}
    end
  end
  
  defp acquire_llm_capability(target, _state) do
    # Use LLM to generate capability code
    case VsmMcp.LLM.Integration.generate_capability(target) do
      {:ok, code} ->
        # Save the generated capability
        file_path = "lib/vsm_mcp/generated/#{target}.ex"
        File.mkdir_p!(Path.dirname(file_path))
        File.write!(file_path, code)
        
        {:ok, %{
          status: :acquired,
          capability: target,
          method: :llm_generation,
          timestamp: DateTime.utc_now(),
          details: "Generated capability using LLM: #{file_path}"
        }}
      {:error, reason} ->
        {:error, "Failed to generate capability: #{reason}"}
    end
  end
  
  defp has_capability?(type, capabilities) do
    Enum.any?(capabilities, fn cap ->
      case cap do
        %{type: ^type} -> true
        ^type -> true
        _ -> false
      end
    end)
  end

  defp update_metrics(state, result, duration) do
    metrics = state.metrics
    count = metrics.operations_count + 1
    success = if match?({:ok, _}, result), do: 1, else: 0
    new_success_rate = (metrics.success_rate * metrics.operations_count + success) / count
    new_avg_duration = (metrics.average_duration * metrics.operations_count + duration) / count
    
    new_metrics = %{
      operations_count: count,
      success_rate: new_success_rate,
      average_duration: new_avg_duration
    }
    
    Map.put(state, :metrics, new_metrics)
  end
  
  # New bulletproof MCP server management functions
  
  defp start_managed_mcp_server(server, target, state) do
    server_name = server[:name] || server.name
    
    Logger.info("Starting managed MCP server: #{server_name}")
    
    # Step 1: Install the MCP server via npm if needed
    case ensure_mcp_server_installed(server_name) do
      :ok ->
        # Step 2: Configure and start using ServerManager
        config = build_server_config(server_name, target)
        
        case ServerManager.start_server(state.server_manager, config) do
          {:ok, server_id} ->
            Logger.info("MCP server started with ID: #{server_id}")
            
            # Step 3: Execute capability through managed server
            case execute_via_managed_server(server_id, target, state) do
              {:ok, result} ->
                # Track the server in our state
                Process.send(self(), {:track_server, server_id}, [:nosuspend])
                {:ok, server_id, result}
              {:error, reason} ->
                # Clean up on failure
                ServerManager.stop_server(state.server_manager, server_id)
                {:error, reason}
            end
            
          {:error, reason} ->
            Logger.error("Failed to start MCP server: #{inspect(reason)}")
            {:error, "Server startup failed: #{inspect(reason)}"}
        end
        
      {:error, reason} ->
        Logger.error("Failed to install MCP server: #{reason}")
        {:error, "Installation failed: #{reason}"}
    end
  end
  
  defp ensure_mcp_server_installed(server_name) do
    # Check if already installed
    case System.cmd("npm", ["list", "-g", server_name], stderr_to_stdout: true) do
      {_output, 0} ->
        Logger.info("MCP server #{server_name} already installed")
        :ok
      _ ->
        # Install the server
        Logger.info("Installing MCP server: #{server_name}")
        case System.cmd("npm", ["install", "-g", server_name], stderr_to_stdout: true) do
          {_output, 0} ->
            Logger.info("Successfully installed MCP server: #{server_name}")
            :ok
          {error_output, exit_code} ->
            {:error, "Installation failed with exit code #{exit_code}: #{error_output}"}
        end
    end
  end
  
  defp build_server_config(server_name, target) do
    %{
      id: "mcp_#{server_name}_#{System.unique_integer([:positive])}",
      type: :external,
      command: determine_server_command(server_name),
      args: [],
      env: %{
        "NODE_ENV" => "production",
        "MCP_MODE" => "stdio"
      },
      working_dir: File.cwd!(),
      restart_policy: :transient,
      health_check: %{
        type: :stdio,
        interval_ms: 10_000,
        timeout_ms: 5_000,
        enabled: true,
        init_message: %{
          jsonrpc: "2.0",
          method: "initialize",
          params: %{
            protocolVersion: "2024-11-05",
            capabilities: %{}
          }
        }
      },
      pool_size: 5,
      max_overflow: 2,
      timeout_ms: 30_000,
      metadata: %{
        target_capability: target,
        server_name: server_name
      }
    }
  end
  
  defp determine_server_command(server_name) do
    # Try to find the executable
    cond do
      executable = System.find_executable("npx") ->
        "#{executable} #{server_name}"
      executable = System.find_executable(server_name) ->
        executable
      true ->
        # Fallback to npx
        "npx #{server_name}"
    end
  end
  
  defp execute_via_managed_server(server_id, target, state) do
    # Get connection from pool
    case ServerManager.get_connection(state.server_manager, server_id) do
      {:ok, conn} ->
        # Build and send MCP request
        request = build_mcp_request(target)
        
        case send_mcp_request_via_connection(conn, request) do
          {:ok, response} ->
            process_mcp_response(response, target)
          {:error, reason} ->
            {:error, "MCP request failed: #{inspect(reason)}"}
        end
        
      {:error, reason} ->
        {:error, "Failed to get connection: #{inspect(reason)}"}
    end
  end
  
  defp build_mcp_request(target) do
    # Build proper MCP protocol request
    VsmMcp.MCP.Protocol.JsonRpc.build_jsonrpc_request(
      "tools/call",
      %{
        name: determine_tool_name(target),
        arguments: build_tool_arguments(target)
      }
    )
  end
  
  defp send_mcp_request_via_connection(conn, request) do
    # Use the bulletproof JSON-RPC implementation
    with {:ok, json} <- VsmMcp.MCP.Protocol.JsonRpc.encode_jsonrpc_message(request),
         :ok <- send_to_connection(conn, json),
         {:ok, response_json} <- receive_from_connection(conn),
         {:ok, response} <- VsmMcp.MCP.Protocol.JsonRpc.parse_jsonrpc_message(response_json) do
      {:ok, response}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp send_to_connection(conn, data) do
    # Send data through the connection (implementation depends on connection type)
    GenServer.call(conn, {:send, data})
  end
  
  defp receive_from_connection(conn) do
    # Receive response from connection with timeout
    GenServer.call(conn, :receive, 10_000)
  end
  
  defp process_mcp_response(response, target) do
    case response do
      %{result: result} when not is_nil(result) ->
        {:ok, %{
          target: target,
          result: result,
          timestamp: DateTime.utc_now()
        }}
        
      %{error: error} when not is_nil(error) ->
        {:error, "MCP error: #{error.message} (code: #{error.code})"}
        
      _ ->
        {:error, "Invalid MCP response format"}
    end
  end
  
  
  defp determine_tool_name(target) do
    case String.downcase(to_string(target)) do
      target when target in ["document_creation", "report_creation"] -> "create_document"
      target when target in ["image_generation", "visualization"] -> "generate_image"
      target when target in ["data_analysis", "analysis"] -> "analyze_data"
      target when target in ["web_scraping", "scraping"] -> "scrape_web"
      target when target in ["api_integration", "api_call"] -> "call_api"
      target when target in ["code_generation", "programming"] -> "generate_code"
      _ -> "execute_capability"
    end
  end
  
  defp build_tool_arguments(target) do
    case String.downcase(to_string(target)) do
      target when target in ["document_creation", "report_creation"] ->
        %{
          type: "document",
          title: "Generated Document",
          content: "Document content for #{target}",
          format: "pdf"
        }
      target when target in ["image_generation", "visualization"] ->
        %{
          type: "image",
          description: "Generated visualization for #{target}",
          format: "png",
          width: 800,
          height: 600
        }
      target when target in ["data_analysis"] ->
        %{
          type: "analysis",
          data: [1, 2, 3, 4, 5],
          operation: "statistics"
        }
      _ ->
        %{
          capability: target,
          action: "execute"
        }
    end
  end
  
  
  
end