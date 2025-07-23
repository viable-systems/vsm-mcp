# VSM-MCP: Viable System Model with Model Context Protocol

A complete Elixir/OTP implementation of Stafford Beer's Viable System Model (VSM) with preparations for Model Context Protocol (MCP) integration.

## Overview

This project implements all five systems of the VSM as OTP GenServers:

- **System 1**: Operations - Executes primary value-creating activities
- **System 2**: Coordination - Harmonizes operations between units
- **System 3**: Control - Optimizes internal operations and resource allocation
- **System 4**: Intelligence - Monitors environment and provides strategic insights
- **System 5**: Policy - Maintains identity and balances present/future needs

## Project Structure

```
vsm-mcp/
├── lib/
│   ├── vsm_mcp.ex              # Main API module
│   ├── vsm_mcp/
│   │   ├── application.ex      # OTP Application supervisor
│   │   └── systems/
│   │       ├── system1.ex      # Operations
│   │       ├── system2.ex      # Coordination
│   │       ├── system3.ex      # Control & Optimization
│   │       ├── system4.ex      # Intelligence & Environment
│   │       └── system5.ex      # Policy & Identity
│   └── (future MCP integration modules)
├── examples/
│   └── basic_vsm_demo.exs      # Demonstration script
├── mix.exs                      # Project configuration
└── README_ELIXIR.md            # This file
```

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd vsm-mcp

# Get dependencies
mix deps.get

# Compile the project
mix compile
```

## Usage

### Running the Demo

```bash
mix run examples/basic_vsm_demo.exs
```

### Interactive Shell

```bash
iex -S mix

# Check system status
VsmMcp.system_status()

# Execute an operation
VsmMcp.execute_operation(%{type: :process, data: "request_123"})

# Validate a decision
VsmMcp.validate_decision(%{type: :strategic, resources: %{budget: 100000}})
```

### Basic API Examples

```elixir
# 1. Operations (System 1)
{:ok, result} = VsmMcp.execute_operation(%{type: :process, data: "customer_order"})

# 2. Coordination (System 2)
VsmMcp.Systems.System2.register_unit(:unit1, [:processing, :storage])
{:ok, plan} = VsmMcp.coordinate_task([:unit1, :unit2], %{name: "complex_task"})

# 3. Control & Audit (System 3)
{:ok, audit} = VsmMcp.audit_and_optimize(:unit1)

# 4. Intelligence (System 4)
{:ok, intelligence} = VsmMcp.environmental_intelligence()

# 5. Policy & Balance (System 5)
validation = VsmMcp.validate_decision(%{type: :strategic, resources: %{budget: 50000}})
{:ok, balance} = VsmMcp.balance_objectives(present_needs, future_goals)
```

## Dependencies

- **jason** - JSON encoding/decoding
- **httpoison** - HTTP client for external integrations
- **plug_cowboy** - Web server (for future MCP server)
- **websocket_client** - WebSocket support
- **telemetry** - Metrics and monitoring
- **telemetry_metrics** - Metrics definitions
- **telemetry_poller** - Periodic measurements

## System Features

### System 1 - Operations
- Execute various operation types (process, transform)
- Track performance metrics
- Manage operational capabilities
- Real-time operation monitoring

### System 2 - Coordination
- Register and manage operational units
- Create coordination plans
- Resolve conflicts between units
- Distribute tasks efficiently

### System 3 - Control
- Audit operational performance
- Optimize resource allocation
- Enforce operational policies
- Monitor efficiency metrics
- Telemetry integration

### System 4 - Intelligence
- Environmental scanning
- Trend analysis
- Future state predictions
- Alert system for anomalies
- Multiple intelligence sources

### System 5 - Policy
- Organizational identity management
- Policy definition and enforcement
- Decision validation framework
- Present/future balance optimization
- System health monitoring

## Architecture

All systems are implemented as OTP GenServers with:
- Fault tolerance through supervision
- State persistence in GenServer state
- Asynchronous message passing
- Telemetry for monitoring
- Periodic self-maintenance tasks

## Future MCP Integration

The project is structured to support MCP server integration:
- Plug/Cowboy for HTTP endpoints
- WebSocket support for real-time communication
- JSON-RPC ready with Jason
- Modular architecture for tool registration

## Development

```bash
# Run tests (when implemented)
mix test

# Generate documentation
mix docs

# Run code quality checks
mix credo

# Static analysis
mix dialyzer
```

## Configuration

The application starts all VSM systems automatically via the OTP supervisor. Systems are started in order with System 5 (Policy) first to establish organizational identity.

## License

This implementation demonstrates VSM principles in Elixir/OTP for educational and practical purposes.