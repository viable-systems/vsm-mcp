# VSM-MCP Full System Integration

## Overview

This is the complete integrated VSM-MCP system that combines:

1. **Viable System Model (VSM)** - Stafford Beer's cybernetic management framework
2. **Model Context Protocol (MCP)** - AI tool integration protocol
3. **Multiple VSM Components** - Core, Pattern Engine, Event Bus, and more
4. **Autonomous Capabilities** - Self-organizing and self-adapting system

## Architecture

```
VSM-MCP System
│
├── Core Supervisor
│   ├── VSM Systems (1-5)
│   ├── MCP Server (STDIO/TCP/WebSocket)
│   ├── Variety Calculator
│   ├── Consciousness Interface
│   └── MCP Discovery
│
├── Integrations
│   ├── Event Bus (Phoenix.PubSub)
│   ├── Pattern Engine
│   ├── Metrics (optional)
│   ├── Security (optional)
│   ├── Connections (optional)
│   └── Vector Store (optional)
│
└── Autonomous Features
    ├── Variety Gap Detection
    ├── Automatic Capability Acquisition
    ├── Pattern Recognition
    └── Meta-Cognitive Operations
```

## Key Components

### 1. VSM Systems

- **System 1** (Operations): Executes primary value-creating activities
- **System 2** (Coordination): Harmonizes operations between units
- **System 3** (Control): Optimizes resource allocation and performance
- **System 4** (Intelligence): Scans environment for opportunities/threats
- **System 5** (Policy): Sets identity, purpose, and strategic direction

### 2. MCP Server

Provides AI tool integration through standardized protocol:
- Tools for each VSM system
- Resource access (policies, capabilities, metrics)
- Multiple transport options (STDIO, TCP, WebSocket)

### 3. Variety Calculator

Based on Ashby's Law of Requisite Variety:
- Calculates variety gap between system and environment
- Triggers automatic capability acquisition
- Monitors variety trends over time

### 4. Consciousness Interface

Meta-cognitive layer for System 5:
- Self-awareness and reflection
- Conscious decision-making
- Pattern recognition and insights
- Adaptive learning

### 5. Event Bus Integration

Enables event-driven coordination:
- Inter-system communication
- Asynchronous event processing
- Pub/Sub pattern for loose coupling

### 6. Pattern Engine Integration

Enhances System 3 with:
- Pattern recognition
- Anomaly detection
- Predictive analytics
- Trend analysis

## Getting Started

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd vsm-mcp

# Install dependencies
mix deps.get

# Compile the project
mix compile
```

### Running the System

```bash
# Start the full system
iex -S mix

# Or run a demo script
mix run examples/simple_demo.exs
mix run examples/full_autonomous_demo.exs
mix run examples/mcp_ai_integration.exs
```

### Configuration

Edit `config/config.exs` to customize:

```elixir
config :vsm_mcp,
  system_config: [
    enable_metrics: true,
    enable_security: true,
    enable_connections: true,
    enable_vector_store: true,
    mcp_transport: :stdio,
    variety_threshold: 0.7,
    monitoring_interval: 30_000
  ]
```

## Usage Examples

### Basic Operations

```elixir
# Execute an operation
VsmMcp.execute_operation(%{type: :process, data: "customer_order"})

# Coordinate tasks
VsmMcp.coordinate_task([:unit1, :unit2], %{name: "complex_task"})

# Validate decisions
VsmMcp.validate_decision(%{type: :strategic, resources: %{budget: 100_000}})

# Get system status
VsmMcp.system_status()
```

### Variety Management

```elixir
# Calculate variety gap
VsmMcp.Core.VarietyCalculator.calculate_variety_gap(
  system_capabilities,
  environmental_demands
)

# Monitor variety trends
VsmMcp.Core.VarietyCalculator.monitor_variety()
```

### Consciousness Queries

```elixir
# Query awareness
VsmMcp.Interfaces.ConsciousnessInterface.query(:awareness)

# Make conscious decision
VsmMcp.Interfaces.ConsciousnessInterface.make_conscious_decision(context)

# Generate awareness report
VsmMcp.Interfaces.ConsciousnessInterface.generate_awareness_report()
```

### MCP Integration

```elixir
# Handle MCP requests (for AI tools)
request = %{
  "method" => "tools/call",
  "params" => %{
    "name" => "vsm.execute_operation",
    "arguments" => %{...}
  }
}

VsmMcp.Interfaces.MCPServer.handle_request(request)
```

## Autonomous Features

### Automatic Capability Acquisition

When the Variety Calculator detects a gap:
1. Analyzes required capabilities
2. Searches for relevant MCP servers
3. Automatically installs and integrates them
4. Updates System 1 with new capabilities

### Event-Driven Adaptation

The system responds to events:
- Variety gap events trigger acquisition
- Consciousness insights inform strategy
- System alerts prompt control actions
- Pattern detection enables prediction

### Meta-Learning

The Consciousness Interface enables:
- Learning from decision patterns
- Adapting based on outcomes
- Evolving awareness levels
- Improving over time

## Demo Scripts

### 1. Simple Demo
Basic VSM operations and status checking.

### 2. Full Autonomous Demo
Complete system demonstration including:
- All 5 systems in action
- Variety management
- Consciousness queries
- Pattern detection
- Event-driven coordination

### 3. MCP AI Integration Demo
Shows how AI models can use VSM through MCP:
- Environmental scanning
- Decision validation
- Task coordination
- System monitoring

## Development

### Adding New Capabilities

1. Create a new module in `lib/vsm_mcp/capabilities/`
2. Register with System 1: `System1.add_capability(capability)`
3. Update MCP tools if needed

### Extending Consciousness

1. Add new awareness types in `consciousness_interface.ex`
2. Implement reflection patterns
3. Update meta-learning algorithms

### Custom Integrations

1. Create integration module in `lib/vsm_mcp/integrations/`
2. Add to CoreSupervisor if needed
3. Implement event handlers

## Architecture Principles

1. **Recursive Structure**: Each system can contain its own VSM
2. **Variety Matching**: System variety must match environmental variety
3. **Autonomy**: Each system operates independently within constraints
4. **Feedback Loops**: Continuous monitoring and adaptation
5. **Meta-Cognition**: System aware of its own operations

## Troubleshooting

### Common Issues

1. **Dependencies not found**: Run `mix deps.get`
2. **Systems not starting**: Check logs with `Logger.configure(level: :debug)`
3. **MCP connection issues**: Verify transport configuration

### Health Checks

```elixir
# Check supervisor status
VsmMcp.Supervisors.CoreSupervisor.status()

# Review system health
VsmMcp.system_status()

# Check variety report
VsmMcp.Core.VarietyCalculator.get_variety_report()
```

## Contributing

1. Follow VSM principles in design
2. Maintain autonomy of systems
3. Use event-driven patterns
4. Add tests for new features
5. Update documentation

## References

- Stafford Beer's "Brain of the Firm"
- Ashby's "Law of Requisite Variety"
- Model Context Protocol Specification
- Viable System Model Handbook

## License

See LICENSE file in repository root.