defmodule VsmMcp.Interfaces.MCPServer do
  @moduledoc """
  MCP (Model Context Protocol) Server implementation for VSM.
  
  Provides AI tool integration capabilities, allowing AI models to interact
  with the VSM system through a standardized protocol.
  """
  use GenServer
  require Logger
  
  alias VsmMcp.Core.VarietyCalculator
  alias VsmMcp.ConsciousnessInterface
  
  @server_info %{
    name: "vsm-mcp",
    version: "0.1.0",
    description: "Viable System Model with Model Context Protocol",
    capabilities: %{
      tools: true,
      resources: true,
      prompts: true
    }
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def handle_request(request) do
    GenServer.call(__MODULE__, {:handle_request, request})
  end
  
  def list_tools do
    GenServer.call(__MODULE__, :list_tools)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    port = opts[:port] || 3000
    transport = opts[:transport] || :stdio
    
    state = %{
      transport: transport,
      port: port,
      tools: initialize_tools(),
      resources: initialize_resources(),
      active_sessions: %{},
      metrics: %{
        requests_handled: 0,
        tool_calls: 0,
        errors: 0
      }
    }
    
    # Start transport listener
    case transport do
      :stdio -> start_stdio_transport()
      :tcp -> start_tcp_transport(port)
      :websocket -> start_websocket_transport(port)
    end
    
    Logger.info("MCP Server initialized on #{transport} transport")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:handle_request, request}, _from, state) do
    {response, new_state} = process_request(request, state)
    {:reply, response, new_state}
  end
  
  @impl true
  def handle_call(:list_tools, _from, state) do
    tools = Map.values(state.tools)
    {:reply, {:ok, tools}, state}
  end
  
  # Private Functions
  
  defp initialize_tools do
    %{
      "vsm.execute_operation" => %{
        name: "vsm.execute_operation",
        description: "Execute an operational task through VSM System 1",
        input_schema: %{
          type: "object",
          properties: %{
            type: %{type: "string", enum: ["process", "transform"]},
            data: %{type: "string", description: "Operation data"},
            input: %{type: "string", description: "Input for transform operations"},
            output: %{type: "string", description: "Expected output format"}
          },
          required: ["type"]
        }
      },
      "vsm.coordinate_task" => %{
        name: "vsm.coordinate_task",
        description: "Coordinate multiple units for complex tasks",
        input_schema: %{
          type: "object",
          properties: %{
            units: %{type: "array", items: %{type: "string"}},
            task: %{
              type: "object",
              properties: %{
                name: %{type: "string"},
                description: %{type: "string"},
                priority: %{type: "string", enum: ["low", "medium", "high"]}
              }
            }
          },
          required: ["units", "task"]
        }
      },
      "vsm.audit_operations" => %{
        name: "vsm.audit_operations",
        description: "Audit and optimize operational performance",
        input_schema: %{
          type: "object",
          properties: %{
            unit_id: %{type: "string", description: "Unit to audit"}
          },
          required: ["unit_id"]
        }
      },
      "vsm.scan_environment" => %{
        name: "vsm.scan_environment",
        description: "Scan environment for opportunities and threats",
        input_schema: %{
          type: "object",
          properties: %{
            scope: %{type: "string", enum: ["internal", "external", "all"]},
            depth: %{type: "string", enum: ["shallow", "deep"]}
          }
        }
      },
      "vsm.validate_decision" => %{
        name: "vsm.validate_decision",
        description: "Validate strategic decisions against policy",
        input_schema: %{
          type: "object",
          properties: %{
            decision: %{
              type: "object",
              properties: %{
                type: %{type: "string"},
                description: %{type: "string"},
                resources: %{type: "object"}
              }
            },
            context: %{type: "object"}
          },
          required: ["decision"]
        }
      },
      "vsm.calculate_variety" => %{
        name: "vsm.calculate_variety",
        description: "Calculate variety and trigger capability acquisition",
        input_schema: %{
          type: "object",
          properties: %{
            system: %{type: "string", description: "System to analyze"},
            environment: %{type: "object", description: "Environmental factors"}
          },
          required: ["system"]
        }
      },
      "vsm.consciousness_query" => %{
        name: "vsm.consciousness_query",
        description: "Query the consciousness interface of System 5",
        input_schema: %{
          type: "object",
          properties: %{
            query_type: %{type: "string", enum: ["awareness", "reflection", "decision"]},
            context: %{type: "object"}
          },
          required: ["query_type"]
        }
      },
      "vsm.system_status" => %{
        name: "vsm.system_status",
        description: "Get comprehensive status of all VSM systems",
        input_schema: %{
          type: "object",
          properties: %{
            include_metrics: %{type: "boolean"},
            include_history: %{type: "boolean"}
          }
        }
      }
    }
  end
  
  defp initialize_resources do
    %{
      "vsm://policies" => %{
        uri: "vsm://policies",
        name: "VSM Policies",
        description: "Current organizational policies",
        mime_type: "application/json"
      },
      "vsm://capabilities" => %{
        uri: "vsm://capabilities",
        name: "System Capabilities",
        description: "Available system capabilities",
        mime_type: "application/json"
      },
      "vsm://metrics" => %{
        uri: "vsm://metrics",
        name: "System Metrics",
        description: "Real-time system performance metrics",
        mime_type: "application/json"
      }
    }
  end
  
  defp process_request(%{"method" => "initialize"} = request, state) do
    response = %{
      jsonrpc: "2.0",
      id: request["id"],
      result: %{
        protocolVersion: "0.1.0",
        serverInfo: @server_info,
        capabilities: @server_info.capabilities
      }
    }
    
    {response, state}
  end
  
  defp process_request(%{"method" => "tools/list"} = request, state) do
    tools = Map.values(state.tools)
    
    response = %{
      jsonrpc: "2.0",
      id: request["id"],
      result: %{
        tools: tools
      }
    }
    
    {response, state}
  end
  
  defp process_request(%{"method" => "tools/call"} = request, state) do
    tool_name = request["params"]["name"]
    arguments = request["params"]["arguments"]
    
    {result, new_state} = execute_tool(tool_name, arguments, state)
    
    response = %{
      jsonrpc: "2.0",
      id: request["id"],
      result: result
    }
    
    {response, new_state}
  end
  
  defp process_request(%{"method" => "resources/list"} = request, state) do
    resources = Map.values(state.resources)
    
    response = %{
      jsonrpc: "2.0",
      id: request["id"],
      result: %{
        resources: resources
      }
    }
    
    {response, state}
  end
  
  defp process_request(%{"method" => "resources/read"} = request, state) do
    uri = request["params"]["uri"]
    
    content = read_resource(uri, state)
    
    response = %{
      jsonrpc: "2.0",
      id: request["id"],
      result: %{
        contents: [
          %{
            uri: uri,
            text: Jason.encode!(content)
          }
        ]
      }
    }
    
    {response, state}
  end
  
  defp execute_tool("vsm.execute_operation", args, state) do
    operation = %{
      type: String.to_atom(args["type"]),
      data: args["data"],
      input: args["input"],
      output: args["output"]
    }
    
    result = VsmMcp.Systems.System1.execute_operation(operation)
    
    new_state = update_metrics(state, :tool_calls)
    {result, new_state}
  end
  
  defp execute_tool("vsm.coordinate_task", args, state) do
    units = Enum.map(args["units"], &String.to_atom/1)
    task = args["task"]
    
    result = VsmMcp.Systems.System2.coordinate(units, task)
    
    new_state = update_metrics(state, :tool_calls)
    {result, new_state}
  end
  
  defp execute_tool("vsm.audit_operations", args, state) do
    unit_id = String.to_atom(args["unit_id"])
    
    result = VsmMcp.audit_and_optimize(unit_id)
    
    new_state = update_metrics(state, :tool_calls)
    {result, new_state}
  end
  
  defp execute_tool("vsm.scan_environment", args, state) do
    scope = args["scope"] || "all"
    depth = args["depth"] || "shallow"
    
    result = VsmMcp.Systems.System4.scan_environment(%{scope: scope, depth: depth})
    
    new_state = update_metrics(state, :tool_calls)
    {result, new_state}
  end
  
  defp execute_tool("vsm.validate_decision", args, state) do
    decision = args["decision"]
    context = args["context"] || %{}
    
    result = VsmMcp.Systems.System5.validate_decision(decision, context)
    
    new_state = update_metrics(state, :tool_calls)
    {result, new_state}
  end
  
  defp execute_tool("vsm.calculate_variety", args, state) do
    system = args["system"]
    environment = args["environment"] || %{}
    
    result = VarietyCalculator.calculate_variety_gap(system, environment)
    
    new_state = update_metrics(state, :tool_calls)
    {result, new_state}
  end
  
  defp execute_tool("vsm.consciousness_query", args, state) do
    query_type = String.to_atom(args["query_type"])
    context = args["context"] || %{}
    
    result = ConsciousnessInterface.query(query_type, context)
    
    new_state = update_metrics(state, :tool_calls)
    {result, new_state}
  end
  
  defp execute_tool("vsm.system_status", args, state) do
    include_metrics = args["include_metrics"] || false
    include_history = args["include_history"] || false
    
    result = VsmMcp.system_status()
    
    result = if include_metrics do
      Map.put(result, :detailed_metrics, gather_detailed_metrics())
    else
      result
    end
    
    result = if include_history do
      Map.put(result, :history, gather_system_history())
    else
      result
    end
    
    new_state = update_metrics(state, :tool_calls)
    {result, new_state}
  end
  
  defp read_resource("vsm://policies", _state) do
    VsmMcp.Systems.System5.get_policy(:all)
  end
  
  defp read_resource("vsm://capabilities", _state) do
    VsmMcp.Systems.System1.get_status().capabilities
  end
  
  defp read_resource("vsm://metrics", _state) do
    gather_detailed_metrics()
  end
  
  defp update_metrics(state, metric) do
    update_in(state, [:metrics, metric], &(&1 + 1))
  end
  
  defp gather_detailed_metrics do
    %{
      system1: VsmMcp.Systems.System1.get_status().metrics,
      system2: VsmMcp.Systems.System2.get_coordination_status(),
      system3: VsmMcp.Systems.System3.get_control_metrics(),
      system4: VsmMcp.Systems.System4.get_intelligence_report(),
      system5: VsmMcp.Systems.System5.review_system_health(),
      timestamp: DateTime.utc_now()
    }
  end
  
  defp gather_system_history do
    # Placeholder for history gathering
    %{
      recent_operations: [],
      recent_decisions: [],
      recent_adaptations: []
    }
  end
  
  defp start_stdio_transport do
    # STDIO transport reads from stdin and writes to stdout
    Task.start_link(fn -> stdio_loop() end)
  end
  
  defp start_tcp_transport(port) do
    # TCP transport implementation
    Logger.info("Starting TCP transport on port #{port}")
    # Implementation would go here
  end
  
  defp start_websocket_transport(port) do
    # WebSocket transport implementation
    Logger.info("Starting WebSocket transport on port #{port}")
    # Implementation would go here
  end
  
  defp stdio_loop do
    case IO.gets("") do
      :eof -> :ok
      line ->
        line
        |> String.trim()
        |> Jason.decode()
        |> case do
          {:ok, request} ->
            response = handle_request(request)
            IO.puts(Jason.encode!(response))
          {:error, _} ->
            IO.puts(Jason.encode!(%{error: "Invalid JSON"}))
        end
        
        stdio_loop()
    end
  end
end