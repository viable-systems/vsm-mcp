defmodule VsmMcp.MCP do
  @moduledoc """
  Main module for MCP (Model Context Protocol) implementation.
  Provides high-level API for MCP client and server functionality.
  """

  alias VsmMcp.MCP.{Client, Server}

  @doc """
  Start an MCP client to connect to external MCP servers.

  ## Options

    * `:name` - The name for the client process
    * `:transport` - Transport type (:stdio, :tcp, :websocket)
    * `:connection` - Connection parameters (host, port, url)
    * `:auto_connect` - Whether to connect automatically on start

  ## Examples

      # Connect via stdio
      {:ok, client} = VsmMcp.MCP.start_client(
        name: :my_client,
        transport: :stdio,
        auto_connect: true
      )

      # Connect via TCP
      {:ok, client} = VsmMcp.MCP.start_client(
        name: :my_client,
        transport: :tcp,
        connection: %{host: "localhost", port: 3333},
        auto_connect: true
      )

      # Connect via WebSocket
      {:ok, client} = VsmMcp.MCP.start_client(
        name: :my_client,
        transport: :websocket,
        connection: %{url: "ws://localhost:3333/mcp"},
        auto_connect: true
      )
  """
  def start_client(opts \\ []) do
    Client.start_link(opts)
  end

  @doc """
  Start an MCP server to expose VSM capabilities.

  ## Options

    * `:name` - The name for the server process
    * `:transport` - Transport type (:stdio, :tcp, :websocket)
    * `:port` - Port to listen on (for TCP/WebSocket)
    * `:auto_start` - Whether to start listening automatically

  ## Examples

      # Start stdio server
      {:ok, server} = VsmMcp.MCP.start_server(
        name: :my_server,
        transport: :stdio,
        auto_start: true
      )

      # Start TCP server
      {:ok, server} = VsmMcp.MCP.start_server(
        name: :my_server,
        transport: :tcp,
        port: 3333,
        auto_start: true
      )

      # Start WebSocket server
      {:ok, server} = VsmMcp.MCP.start_server(
        name: :my_server,
        transport: :websocket,
        port: 3333,
        auto_start: true
      )
  """
  def start_server(opts \\ []) do
    Server.start_link(opts)
  end

  @doc """
  Connect a client to an MCP server.
  """
  def connect(client) do
    Client.connect(client)
  end

  @doc """
  Disconnect a client from an MCP server.
  """
  def disconnect(client) do
    Client.disconnect(client)
  end

  @doc """
  List available tools from an MCP server.
  """
  def list_tools(client) do
    Client.list_tools(client)
  end

  @doc """
  Call a tool on an MCP server.
  """
  def call_tool(client, name, arguments) do
    Client.call_tool(client, name, arguments)
  end

  @doc """
  List available resources from an MCP server.
  """
  def list_resources(client) do
    Client.list_resources(client)
  end

  @doc """
  Read a resource from an MCP server.
  """
  def read_resource(client, uri) do
    Client.read_resource(client, uri)
  end

  @doc """
  Subscribe to resource updates from an MCP server.
  """
  def subscribe_resource(client, uri) do
    Client.subscribe_resource(client, uri)
  end

  @doc """
  List available prompts from an MCP server.
  """
  def list_prompts(client) do
    Client.list_prompts(client)
  end

  @doc """
  Get a prompt from an MCP server.
  """
  def get_prompt(client, name, arguments \\ %{}) do
    Client.get_prompt(client, name, arguments)
  end

  @doc """
  Register a tool with an MCP server.

  ## Tool Specification

  The tool specification should include:
    * `:description` - Description of what the tool does
    * `:input_schema` - JSON Schema for the tool's input parameters
    * `:execute` - Function that executes the tool (receives params, returns {:ok, result} or {:error, reason})

  ## Example

      VsmMcp.MCP.register_tool(server, "my_tool", %{
        description: "Does something useful",
        input_schema: %{
          type: "object",
          properties: %{
            input: %{type: "string", description: "The input"}
          },
          required: ["input"]
        },
        execute: fn params ->
          {:ok, "Processed: " <> params["input"]}
        end
      })
  """
  def register_tool(server, name, tool_spec) do
    Server.register_tool(server, name, tool_spec)
  end

  @doc """
  Register a resource with an MCP server.

  ## Resource Specification

  The resource specification should include:
    * `:name` - Display name for the resource
    * `:description` - Description of the resource
    * `:mime_type` - MIME type of the resource content
    * `:read` - Function that returns the resource content
    * `:subscribe` - Optional function to handle subscriptions
    * `:unsubscribe` - Optional function to handle unsubscriptions

  ## Example

      VsmMcp.MCP.register_resource(server, "file:///my/resource", %{
        name: "My Resource",
        description: "A useful resource",
        mime_type: "text/plain",
        read: fn ->
          {:ok, "Resource content"}
        end
      })
  """
  def register_resource(server, uri, resource_spec) do
    Server.register_resource(server, uri, resource_spec)
  end

  @doc """
  Register a prompt with an MCP server.

  ## Prompt Specification

  The prompt specification should include:
    * `:description` - Description of the prompt
    * `:arguments` - List of argument definitions
    * `:get` - Function that generates the prompt messages

  ## Example

      VsmMcp.MCP.register_prompt(server, "analyze_code", %{
        description: "Analyze code for improvements",
        arguments: [
          %{name: "language", type: "string", description: "Programming language"},
          %{name: "code", type: "string", description: "Code to analyze"}
        ],
        get: fn args ->
          {:ok, [
            %{role: "system", content: "You are a code analyst."},
            %{role: "user", content: "Analyze this " <> args["language"] <> " code: " <> args["code"]}
          ]}
        end
      })
  """
  def register_prompt(server, name, prompt_spec) do
    Server.register_prompt(server, name, prompt_spec)
  end

  @doc """
  Start an MCP server listening for connections.
  """
  def start_listening(server) do
    Server.start_listening(server)
  end

  @doc """
  Stop an MCP server from listening.
  """
  def stop_listening(server) do
    Server.stop_listening(server)
  end
end