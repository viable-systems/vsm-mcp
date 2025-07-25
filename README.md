# VSM-MCP: Viable System Model with Model Context Protocol

An autonomous cybernetic system implementing Stafford Beer's Viable System Model (VSM) with dynamic capability acquisition through the Model Context Protocol (MCP).

## 🎯 Overview

VSM-MCP is a **fully functional** autonomous system that:
- Implements all 5 VSM systems (Operations, Coordination, Control, Intelligence, Policy)
- Calculates variety gaps using Ashby's Law of Requisite Variety
- Autonomously discovers and integrates MCP servers to fill capability gaps
- Features meta-cognitive consciousness for self-awareness and learning
- Provides full MCP protocol support for AI integration

## 🚀 Proven Capabilities

This system has been **demonstrated to work end-to-end**:

1. **Real MCP Discovery**: Found 23+ actual MCP servers from NPM registry
2. **Real Variety Calculation**: Computed operational variety from actual system metrics
3. **Real LLM Integration**: Successfully integrated with Claude API
4. **Real Capability Acquisition**: Actually installed npm packages and created a PowerPoint

### Example: Autonomous PowerPoint Creation

When asked to create a PowerPoint, the system:
1. Detected it lacked this capability (variety gap)
2. Used Claude AI to suggest search terms
3. Found real packages on NPM (`mcp-powerpoint`, `pptxgenjs`)
4. Actually installed them via npm
5. Created a real 61KB PowerPoint file about VSM

```bash
# The system created this actual file:
-rw-rw-r-- 1 user user 61143 Jul 23 10:44 VSM_Presentation_1753285485584.pptx
```

## 🏗️ Architecture

```
System 5 (Policy) ← Consciousness Interface
    ↓
System 4 (Intelligence) ← MCP Discovery
    ↓
System 3 (Control) ← Pattern Engine
    ↓
System 2 (Coordination) ← Event Bus
    ↓
System 1 (Operations) ← Dynamic Capabilities
```

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/viable-systems/vsm-mcp.git
cd vsm-mcp

# Install dependencies
mix deps.get

# Run the real autonomous demo
elixir examples/real_autonomous_demo.exs

# Run with LLM integration (requires API key in .env)
elixir examples/real_llm_runtime.exs

# Run full end-to-end demo (creates actual PowerPoint)
elixir real_end_to_end.exs
```

## 🧠 Key Features

### Autonomous Variety Management
- Real-time calculation of operational vs environmental variety
- Automatic detection of variety gaps
- Dynamic acquisition of capabilities through MCP servers

### Consciousness Interface
- Meta-cognitive reflection and self-awareness
- Decision tracing and rationale storage
- Learning from past experiences
- Understanding of system limitations

### MCP Integration
- Full protocol support (stdio, TCP, WebSocket)
- Client for connecting to external MCP servers
- Server for exposing VSM capabilities to AI
- Dynamic capability integration

### VSM Implementation
- **System 1**: Operational units with dynamic capabilities
- **System 2**: Coordination and conflict resolution
- **System 3**: Control, audit, and optimization
- **System 4**: Environmental scanning and adaptation
- **System 5**: Policy, identity, and strategic decisions

## 📡 MCP Tools Available

When running as an MCP server, the following tools are exposed:

- `vsm_status` - Get current system status
- `vsm_decision` - Make strategic decisions
- `variety_analysis` - Analyze variety gaps
- `capability_search` - Find MCP servers for gaps
- `system_metrics` - Get performance metrics
- `consciousness_query` - Query meta-cognitive state
- `event_publish` - Publish system events
- `pattern_analyze` - Analyze system patterns

## 🔒 Security Features

### Sandbox Isolation
- **Process Isolation**: Each MCP server runs in a sandboxed environment
- **Resource Limits**: Memory (512MB) and CPU (50%) caps per server
- **Network Restrictions**: Whitelist-only network access
- **File System Isolation**: Restricted to sandbox directories only

### Package Security
- **Whitelist Enforcement**: Only approved npm packages allowed
- **Dependency Scanning**: Automatic vulnerability detection
- **Code Pattern Analysis**: Blocks dangerous operations (eval, exec, etc.)
- **Permission Auditing**: Detects overly permissive files

### Secure Integration
```elixir
# All MCP servers are verified before integration
{:ok, result} = VsmMcp.Integration.Sandbox.test_server(
  installation_path,
  %{capabilities: ["web-search"], security_required: true}
)

# Only servers with security_score > 70 are integrated
if result.security_scan.score >= 70 do
  VsmMcp.integrate_capability(result.server_info)
end
```

## 🔧 Configuration

```elixir
# config/config.exs
config :vsm_mcp,
  # Variety monitoring interval (ms)
  variety_check_interval: 60_000,
  
  # MCP server configuration
  mcp_server: [
    transport: :stdio,  # or :tcp, :websocket
    port: 4000,
    capabilities: ["vsm", "cybernetics", "autonomy"]
  ],
  
  # Security configuration
  security: [
    sandbox_enabled: true,
    package_whitelist: [
      "@anthropic/sdk",
      "express",
      "axios",
      "lodash"
    ],
    max_memory_mb: 512,
    max_cpu_percent: 50,
    min_security_score: 70
  ],
  
  # Consciousness settings
  consciousness: [
    reflection_interval: 300_000,
    learning_rate: 0.1
  ]
```

## 📚 Documentation

- [Architecture Guide](docs/ARCHITECTURE.md)
- [VSM Principles](docs/VSM_PRINCIPLES.md)
- [MCP Integration](docs/MCP_INTEGRATION.md)
- [API Reference](docs/API.md)

## 🧪 Testing

### Test Categories

```bash
# Run all tests
mix test

# Run security tests
mix test test/vsm_mcp/integration/security_test.exs
mix test test/vsm_mcp/integration/sandbox_test.exs

# Run parallel execution tests
mix test test/vsm_mcp/integration/parallel_execution_test.exs

# Run integration tests
mix test --only integration

# Run property-based tests
mix test --only property
```

### Test Coverage
- **Unit Tests**: All core modules with >80% coverage
- **Integration Tests**: End-to-end capability acquisition
- **Security Tests**: Sandbox escaping, package validation
- **Performance Tests**: Parallel execution, load testing
- **Property Tests**: Security constraint validation

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📖 References

- Stafford Beer's "Brain of the Firm" and "Heart of Enterprise"
- W. Ross Ashby's "Design for a Brain" and "Introduction to Cybernetics"
- Model Context Protocol Specification

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Stafford Beer for the Viable System Model
- W. Ross Ashby for the Law of Requisite Variety
- Anthropic for the Model Context Protocol
- The Elixir community for excellent tools and libraries