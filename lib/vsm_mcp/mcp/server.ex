defmodule VsmMcp.MCP.Server do
  @moduledoc """
  MCP server for exposing VSM capabilities to external clients.
  Provides tools, resources, and prompts based on VSM systems.
  """

  use GenServer
  alias VsmMcp.MCP.Protocol.Handler
  alias VsmMcp.MCP.Transports
  require Logger

  defstruct [
    :name,
    :transport_type,
    :transport,
    :handler,
    :port,
    :tools,
    :resources,
    :prompts,
    :capabilities
  ]

  # Server API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def register_tool(server, name, tool_spec) do
    GenServer.call(server, {:register_tool, name, tool_spec})
  end

  def register_resource(server, uri, resource_spec) do
    GenServer.call(server, {:register_resource, uri, resource_spec})
  end

  def register_prompt(server, name, prompt_spec) do
    GenServer.call(server, {:register_prompt, name, prompt_spec})
  end

  def start_listening(server) do
    GenServer.call(server, :start_listening)
  end

  def stop_listening(server) do
    GenServer.call(server, :stop_listening)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      name: opts[:name] || "vsm-mcp-server",
      transport_type: opts[:transport] || :stdio,
      port: opts[:port] || 3333,
      tools: %{},
      resources: %{},
      prompts: %{},
      capabilities: build_capabilities(opts[:capabilities] || %{})
    }

    # Register default VSM tools
    state = register_default_tools(state)

    # Auto-start if requested
    state =
      if opts[:auto_start] do
        case do_start_listening(state) do
          {:ok, listening_state} ->
            listening_state

          {:error, reason} ->
            Logger.error("Auto-start failed: #{inspect(reason)}")
            state
        end
      else
        state
      end

    {:ok, state}
  end

  @impl true
  def handle_call({:register_tool, name, spec}, _from, state) do
    tool = %{
      name: name,
      description: spec.description,
      input_schema: spec.input_schema,
      execute: spec.execute
    }

    new_state = %{state | tools: Map.put(state.tools, name, tool)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:register_resource, uri, spec}, _from, state) do
    resource = %{
      uri: uri,
      name: spec.name,
      description: spec.description,
      mime_type: spec.mime_type || "text/plain",
      read: spec.read,
      subscribe: spec[:subscribe],
      unsubscribe: spec[:unsubscribe]
    }

    new_state = %{state | resources: Map.put(state.resources, uri, resource)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:register_prompt, name, spec}, _from, state) do
    prompt = %{
      name: name,
      description: spec.description,
      arguments: spec.arguments || [],
      get: spec.get
    }

    new_state = %{state | prompts: Map.put(state.prompts, name, prompt)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:start_listening, _from, state) do
    case do_start_listening(state) do
      {:ok, listening_state} ->
        {:reply, :ok, listening_state}

      {:error, reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:stop_listening, _from, state) do
    if state.transport do
      GenServer.stop(state.transport)
    end

    if state.handler do
      GenServer.stop(state.handler)
    end

    {:reply, :ok, %{state | transport: nil, handler: nil}}
  end

  # Private functions

  defp do_start_listening(state) do
    # Prepare handlers for the protocol handler
    handlers = %{
      tools: state.tools,
      resources: state.resources,
      prompts: state.prompts
    }

    # Start protocol handler
    {:ok, handler} = Handler.start_link(
      transport: self(),
      capabilities: state.capabilities,
      handlers: handlers
    )

    # Start transport based on type
    transport_result =
      case state.transport_type do
        :stdio ->
          Transports.Stdio.start_link(handler: handler)

        :tcp ->
          {:ok, transport} = Transports.Tcp.start_link(
            handler: handler,
            mode: :server
          )

          case Transports.Tcp.listen(transport, state.port) do
            :ok ->
              Logger.info("MCP server listening on TCP port #{state.port}")
              {:ok, transport}

            error ->
              GenServer.stop(transport)
              error
          end

        :websocket ->
          {:ok, transport} = Transports.WebSocket.start_link(handler: handler)

          case Transports.WebSocket.listen(transport, state.port, "/mcp") do
            :ok ->
              Logger.info("MCP server listening on WebSocket port #{state.port}")
              {:ok, transport}

            error ->
              GenServer.stop(transport)
              error
          end
      end

    case transport_result do
      {:ok, transport} ->
        {:ok, %{state | transport: transport, handler: handler}}

      {:error, reason} ->
        GenServer.stop(handler)
        {:error, reason}
    end
  end

  defp build_capabilities(custom_caps) do
    # Default capabilities
    default_caps = %{
      tools: %{},
      resources: %{
        subscribe: true,
        unsubscribe: true
      },
      prompts: %{},
      completion: %{}
    }

    Map.merge(default_caps, custom_caps)
  end

  defp register_default_tools(state) do
    # Register VSM System tools
    tools = [
      {"vsm.system1.monitor", %{
        description: "Monitor System 1 (environmental interface)",
        input_schema: %{
          type: "object",
          properties: %{
            metrics: %{
              type: "array",
              items: %{type: "string"},
              description: "Metrics to monitor"
            }
          }
        },
        execute: fn params ->
          # Call System 1 monitoring
          case VsmMcp.Systems.System1.get_status() do
            {:ok, status} ->
              {:ok, Jason.encode!(status)}

            error ->
              error
          end
        end
      }},

      {"vsm.system2.transform", %{
        description: "Transform variety using System 2",
        input_schema: %{
          type: "object",
          properties: %{
            input: %{
              type: "object",
              description: "Input variety to transform"
            },
            mode: %{
              type: "string",
              enum: ["amplify", "attenuate"],
              description: "Transformation mode"
            }
          },
          required: ["input", "mode"]
        },
        execute: fn params ->
          mode = String.to_atom(params["mode"])
          
          case VsmMcp.Systems.System2.transform_variety(params["input"], mode) do
            {:ok, result} ->
              {:ok, Jason.encode!(result)}

            error ->
              error
          end
        end
      }},

      {"vsm.system3.coordinate", %{
        description: "Coordinate operations using System 3",
        input_schema: %{
          type: "object",
          properties: %{
            operations: %{
              type: "array",
              items: %{type: "object"},
              description: "Operations to coordinate"
            }
          },
          required: ["operations"]
        },
        execute: fn params ->
          case VsmMcp.Systems.System3.coordinate_operations(params["operations"]) do
            {:ok, result} ->
              {:ok, Jason.encode!(result)}

            error ->
              error
          end
        end
      }},

      {"vsm.system4.analyze", %{
        description: "Analyze environment using System 4",
        input_schema: %{
          type: "object",
          properties: %{
            scope: %{
              type: "string",
              enum: ["internal", "external", "both"],
              description: "Analysis scope"
            },
            depth: %{
              type: "integer",
              minimum: 1,
              maximum: 10,
              description: "Analysis depth"
            }
          }
        },
        execute: fn params ->
          scope = String.to_atom(params["scope"] || "both")
          depth = params["depth"] || 5

          case VsmMcp.Systems.System4.analyze_environment(scope, depth) do
            {:ok, analysis} ->
              {:ok, Jason.encode!(analysis)}

            error ->
              error
          end
        end
      }},

      {"vsm.system5.decide", %{
        description: "Make strategic decisions using System 5",
        input_schema: %{
          type: "object",
          properties: %{
            context: %{
              type: "object",
              description: "Decision context"
            },
            options: %{
              type: "array",
              items: %{type: "object"},
              description: "Available options"
            },
            criteria: %{
              type: "array",
              items: %{type: "string"},
              description: "Decision criteria"
            }
          },
          required: ["context", "options"]
        },
        execute: fn params ->
          case VsmMcp.Systems.System5.make_decision(
            params["context"],
            params["options"],
            params["criteria"] || []
          ) do
            {:ok, decision} ->
              {:ok, Jason.encode!(decision)}

            error ->
              error
          end
        end
      }}
    ]

    # Register each tool
    Enum.reduce(tools, state, fn {name, spec}, acc_state ->
      %{acc_state | tools: Map.put(acc_state.tools, name, spec)}
    end)
  end
end