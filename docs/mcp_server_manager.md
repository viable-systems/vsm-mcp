# MCP Server Manager

## Overview

The MCP Server Manager provides bulletproof process management for Model Context Protocol (MCP) servers in the VSM-MCP system. It handles the complete lifecycle of MCP servers with automatic recovery, health monitoring, and resource management.

## Features

### Core Capabilities

- **Server Discovery & Validation**: Automatically discover and validate MCP servers before starting
- **Process Lifecycle Management**: Start, stop, restart servers with full control
- **Health Monitoring**: Continuous health checks with configurable strategies
- **Automatic Recovery**: Smart restart policies based on failure types
- **Resource Management**: Prevent memory leaks and zombie processes
- **Connection Pooling**: Efficient connection management with overflow handling
- **Bulk Operations**: Manage multiple servers simultaneously

### Advanced Features

- **Multiple Server Types**: Support for stdio, TCP, WebSocket, and custom servers
- **Graceful Shutdown**: Clean termination with timeout control
- **Process Isolation**: Prevent cascading failures
- **Performance Metrics**: Real-time monitoring and statistics
- **Configuration Hot-Reload**: Update server configs without downtime
- **Thread-Safe Operations**: Concurrent access with proper synchronization

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     ServerManager                            │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │   Config    │  │   Process    │  │      Health      │  │
│  │ Validation  │  │  Management  │  │    Monitoring    │  │
│  └─────────────┘  └──────────────┘  └──────────────────┘  │
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Resource   │  │  Connection  │  │     Metrics      │  │
│  │   Tracker   │  │     Pool     │  │   Collection     │  │
│  └─────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Starting the Server Manager

```elixir
# Start with default options
{:ok, _pid} = VsmMcp.MCP.ServerManager.start_link()

# Start with custom options
{:ok, _pid} = VsmMcp.MCP.ServerManager.start_link(
  health_check_interval: 60_000,  # 1 minute
  restart_policies: %{
    default: :permanent,
    external: :transient
  }
)
```

### Managing Individual Servers

```elixir
alias VsmMcp.MCP.ServerManager
alias VsmMcp.MCP.ServerManager.ServerConfig

# Create server configuration
config = ServerConfig.create_preset(:stdio,
  command: "npx",
  args: ["some-mcp-server"],
  id: "my_server"
)

# Start server
{:ok, server_id} = ServerManager.start_server(config)

# Check server health
{:ok, health} = ServerManager.get_health(server_id)

# Stop server gracefully
:ok = ServerManager.stop_server(server_id, graceful: true, timeout: 5_000)

# Restart server
:ok = ServerManager.restart_server(server_id)
```

### Server Types

#### External Servers (stdio)

```elixir
config = %{
  type: :external,
  id: "external_stdio_server",
  command: "node",
  args: ["mcp-server.js"],
  env: %{"NODE_ENV" => "production"},
  working_dir: "/path/to/server",
  restart_policy: :permanent,
  health_check: %{
    type: :stdio,
    interval_ms: 30_000,
    init_message: %{jsonrpc: "2.0", method: "health"}
  }
}
```

#### Internal Servers (TCP/WebSocket)

```elixir
# TCP Server
tcp_config = ServerConfig.create_preset(:tcp,
  port: 3333,
  id: "internal_tcp_server"
)

# WebSocket Server
ws_config = ServerConfig.create_preset(:websocket,
  port: 8080,
  path: "/mcp",
  id: "internal_ws_server"
)
```

#### Custom Servers

```elixir
config = %{
  type: :custom,
  id: "custom_server",
  start_fn: fn config ->
    # Custom startup logic
    {:ok, pid} = MyCustomServer.start_link(config)
    {:ok, %{pid: pid}}
  end,
  health_check: %{
    type: :custom,
    check_fn: fn pid ->
      case GenServer.call(pid, :health) do
        :ok -> {:ok, :healthy}
        _ -> {:ok, :unhealthy}
      end
    end
  }
}
```

### Bulk Operations

```elixir
# Start multiple servers
configs = [
  ServerConfig.create_preset(:tcp, port: 3001, id: "server_1"),
  ServerConfig.create_preset(:tcp, port: 3002, id: "server_2"),
  ServerConfig.create_preset(:tcp, port: 3003, id: "server_3")
]

{:ok, results} = ServerManager.start_servers(configs)
# => %{successful: 3, failed: 0, results: [...]}

# Stop multiple servers
server_ids = ["server_1", "server_2", "server_3"]
{:ok, results} = ServerManager.stop_servers(server_ids)
```

### Health Monitoring

```elixir
# Get overall status
{:ok, status} = ServerManager.get_status()

# Status includes:
# - List of all servers with their current state
# - Resource usage statistics
# - Operational metrics

# Get specific server health
{:ok, health} = ServerManager.get_health("my_server")
# => %{
#   status: :healthy,
#   last_check: ~U[2024-01-20 12:00:00Z],
#   uptime: 3600,
#   restart_count: 0,
#   resource_usage: %{memory: 50_000_000, cpu: 2.5}
# }
```

### Connection Pooling

```elixir
# Configure server with connection pool
config = %{
  type: :internal,
  id: "pooled_server",
  pool_size: 10,        # Base pool size
  max_overflow: 5,      # Additional connections under load
  server_opts: [...]
}

{:ok, server_id} = ServerManager.start_server(config)

# Get connection from pool
{:ok, conn} = ServerManager.get_connection(server_id)

# Connection is automatically returned to pool when done
```

### Restart Policies

- **`:permanent`** - Always restart on failure
- **`:transient`** - Restart only on abnormal termination
- **`:temporary`** - Never restart automatically

```elixir
config = %{
  type: :external,
  id: "critical_server",
  command: "important-mcp-server",
  restart_policy: :permanent,  # Always restart
  # Restart attempts use exponential backoff:
  # 1s, 2s, 4s, 8s, 16s, 32s, 60s (max)
}
```

## Configuration

### Global Configuration

```elixir
# In config/config.exs
config :vsm_mcp, VsmMcp.MCP.ServerManager,
  health_check_interval: 30_000,
  default_memory_limit: 500_000_000,  # 500MB
  cleanup_interval: 60_000,           # 1 minute
  restart_policies: %{
    default: :permanent,
    external: :transient,
    internal: :permanent
  }
```

### Per-Server Configuration

```elixir
# Update configuration at runtime
ServerManager.update_config("my_server", %{
  pool_size: 20,
  restart_policy: :transient,
  health_check: %{interval_ms: 60_000}
})
```

## Monitoring & Metrics

### Available Metrics

```elixir
{:ok, metrics} = ServerManager.get_metrics()
# => %{
#   started: 10,        # Total servers started
#   stopped: 5,         # Total servers stopped
#   restarted: 2,       # Total restart attempts
#   failed: 1,          # Total failures
#   health_checks: 150  # Total health checks performed
# }
```

### Resource Tracking

The ResourceTracker component monitors:
- Process memory usage
- CPU utilization
- Message queue length
- Port/socket connections
- Zombie process detection

## Error Handling

### Common Errors

- `:server_not_found` - Server ID doesn't exist
- `:server_already_exists` - Duplicate server ID
- `:command_not_found` - External command not found
- `:max_overflow_reached` - Connection pool exhausted
- `:timeout` - Operation timed out

### Recovery Strategies

1. **Automatic Restart**: Based on restart policy
2. **Exponential Backoff**: Prevent restart loops
3. **Health-Based Recovery**: Restart unhealthy servers
4. **Resource Cleanup**: Automatic zombie process removal

## Integration with VSM

The ServerManager integrates seamlessly with VSM systems:

```elixir
# Use high-level integration module
alias VsmMcp.MCP.Integration

# Setup complete VSM-MCP environment
{:ok, env} = Integration.setup_vsm_mcp_environment(
  transport: :stdio,
  enable_dashboard: true,
  config_file: "mcp_servers.json"
)

# Get unified health view
{:ok, health} = Integration.get_system_health()
```

## Best Practices

1. **Always specify server IDs** for easier management
2. **Configure appropriate restart policies** based on criticality
3. **Set reasonable health check intervals** (30-60 seconds)
4. **Monitor resource usage** to prevent memory leaks
5. **Use connection pooling** for better performance
6. **Implement custom health checks** for complex servers
7. **Handle errors gracefully** in your server implementations

## Troubleshooting

### Server Won't Start

1. Check if command exists: `System.find_executable("command")`
2. Verify working directory exists
3. Check for port conflicts (TCP/WebSocket servers)
4. Review server logs for startup errors

### Memory Leaks

1. Monitor with `ServerManager.get_status/0`
2. Set memory limits in configuration
3. Enable automatic cleanup
4. Check for message queue buildup

### Connection Issues

1. Verify server is running: `ServerManager.get_health/1`
2. Check connection pool status
3. Increase pool size if needed
4. Monitor for connection timeouts

## Examples

See `/examples/mcp_server_manager_demo.exs` for comprehensive examples.

## Testing

Run the test suite:

```bash
mix test test/vsm_mcp/mcp/server_manager_test.exs
```

The test suite covers:
- Server lifecycle management
- Restart policies
- Health monitoring
- Resource tracking
- Connection pooling
- Bulk operations
- Error scenarios