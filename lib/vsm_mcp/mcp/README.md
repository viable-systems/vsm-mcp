# VSM-MCP Protocol Implementation

This directory contains the complete implementation of the Model Context Protocol (MCP) for VSM-MCP, enabling communication between VSM systems and external MCP-compatible tools and services.

## Architecture

### Core Components

1. **Protocol Layer** (`protocol/`)
   - `json_rpc.ex` - JSON-RPC 2.0 implementation
   - `messages.ex` - MCP message types and builders
   - `handler.ex` - Protocol message routing and handling

2. **Transport Layer** (`transports/`)
   - `stdio.ex` - Standard I/O transport (for CLI tools)
   - `tcp.ex` - TCP socket transport
   - `websocket.ex` - WebSocket transport

3. **Client/Server** 
   - `client.ex` - MCP client for connecting to external servers
   - `server.ex` - MCP server for exposing VSM capabilities

## Features

- **Full MCP Specification Support**: Implements the complete MCP protocol
- **Multiple Transports**: stdio, TCP, and WebSocket support
- **VSM Integration**: Exposes all VSM systems as MCP tools
- **Bidirectional Communication**: Both client and server capabilities
- **Resource Management**: Subscribe/unsubscribe to resource updates
- **Prompt Templates**: Dynamic prompt generation
- **Tool Discovery**: Automatic capability negotiation

## Usage

### Starting an MCP Server

```elixir
# Start server on stdio (for CLI integration)
{:ok, server} = VsmMcp.MCP.start_server(
  transport: :stdio,
  auto_start: true
)

# Start server on TCP
{:ok, server} = VsmMcp.MCP.start_server(
  transport: :tcp,
  port: 3333,
  auto_start: true
)

# Start server on WebSocket
{:ok, server} = VsmMcp.MCP.start_server(
  transport: :websocket,
  port: 3333,
  auto_start: true
)
```

### Connecting as MCP Client

```elixir
# Connect to stdio server
{:ok, client} = VsmMcp.MCP.start_client(
  transport: :stdio,
  auto_connect: true
)

# Connect to TCP server
{:ok, client} = VsmMcp.MCP.start_client(
  transport: :tcp,
  connection: %{host: "localhost", port: 3333},
  auto_connect: true
)

# Connect to WebSocket server
{:ok, client} = VsmMcp.MCP.start_client(
  transport: :websocket,
  connection: %{url: "ws://localhost:3333/mcp"},
  auto_connect: true
)
```

### Using MCP Tools

```elixir
# List available tools
{:ok, tools} = VsmMcp.MCP.list_tools(client)

# Call a tool
{:ok, result} = VsmMcp.MCP.call_tool(client, "vsm.system1.monitor", %{
  "metrics" => ["input", "output", "efficiency"]
})

# Access resources
{:ok, resources} = VsmMcp.MCP.list_resources(client)
{:ok, content} = VsmMcp.MCP.read_resource(client, "vsm://health/status")

# Use prompts
{:ok, prompts} = VsmMcp.MCP.list_prompts(client)
{:ok, messages} = VsmMcp.MCP.get_prompt(client, "vsm_analysis", %{
  "focus_area" => "variety management"
})
```

### Registering Custom Tools

```elixir
VsmMcp.MCP.register_tool(server, "my_tool", %{
  description: "Custom tool description",
  input_schema: %{
    type: "object",
    properties: %{
      input: %{type: "string"}
    },
    required: ["input"]
  },
  execute: fn params ->
    # Tool implementation
    {:ok, "Result: #{params["input"]}"}
  end
})
```

## Default VSM Tools

The MCP server automatically exposes these VSM tools:

- `vsm.system1.monitor` - Monitor System 1 (environmental interface)
- `vsm.system2.transform` - Transform variety (amplify/attenuate)
- `vsm.system3.coordinate` - Coordinate operations
- `vsm.system4.analyze` - Analyze environment
- `vsm.system5.decide` - Make strategic decisions

## Protocol Flow

1. **Client connects** via chosen transport
2. **Initialize handshake** - Protocol version and capability negotiation
3. **Tool/Resource discovery** - Client queries available capabilities
4. **Request/Response** - Client calls tools, reads resources, gets prompts
5. **Notifications** - Server sends updates for subscribed resources
6. **Disconnect** - Clean shutdown

## Error Handling

The implementation follows JSON-RPC 2.0 error codes:

- `-32700` - Parse error
- `-32600` - Invalid Request
- `-32601` - Method not found
- `-32602` - Invalid params
- `-32603` - Internal error

MCP-specific error codes:

- `-32001` - Connection error
- `-32002` - Timeout error
- `-32003` - Resource not found
- `-32004` - Tool not found
- `-32005` - Invalid capabilities

## Testing

Run protocol tests:

```bash
mix test test/vsm_mcp/mcp/protocol_test.exs
```

Run the demo:

```bash
mix run examples/mcp_demo.exs
```

## Integration with External Tools

The MCP implementation allows VSM-MCP to integrate with:

- **Claude Desktop** - Use VSM tools directly in Claude
- **Continue.dev** - VSM-powered code assistance
- **Sourcegraph Cody** - Enhanced code intelligence
- **Custom MCP clients** - Any tool supporting the MCP protocol

## Configuration

Configure MCP settings in your application:

```elixir
config :vsm_mcp, :mcp,
  default_transport: :stdio,
  tcp_port: 3333,
  websocket_port: 3333,
  websocket_path: "/mcp"
```

## Future Enhancements

- [ ] TLS/SSL support for secure connections
- [ ] Authentication and authorization
- [ ] Rate limiting and quotas
- [ ] Metrics and monitoring
- [ ] Connection pooling for clients
- [ ] Batch request support