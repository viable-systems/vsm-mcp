# VSM-MCP Test Suite

This directory contains comprehensive tests for the VSM-MCP system.

## Test Structure

```
test/
├── vsm_mcp_basic_test.exs                    # Basic functionality tests
├── vsm_mcp_test.exs                          # Main module tests
├── integration/
│   └── full_system_test.exs                  # Full system integration tests
└── vsm_mcp/
    ├── consciousness/
    │   └── awareness_test.exs                # Consciousness awareness tests
    ├── consciousness_interface_test.exs       # Consciousness interface tests
    ├── core/
    │   ├── mcp_discovery_test.exs           # MCP discovery tests
    │   └── variety_calculator_test.exs      # Variety calculation tests
    ├── integration/
    │   └── capability_matcher_test.exs      # Capability matching tests
    ├── llm/
    │   └── integration_test.exs             # LLM integration tests
    ├── mcp/
    │   ├── client_test.exs                  # MCP client tests
    │   └── protocol_test.exs                # MCP protocol tests
    ├── real_implementation_test.exs          # Real implementation tests
    └── systems/
        ├── system1_test.exs                  # System 1 (Operations) tests
        ├── system2_test.exs                  # System 2 (Coordination) tests
        ├── system3_test.exs                  # System 3 (Control) tests
        ├── system4_test.exs                  # System 4 (Intelligence) tests
        └── system5_test.exs                  # System 5 (Policy) tests
```

## Running Tests

### Run all tests
```bash
mix test
```

### Run tests without starting the application
```bash
mix test --no-start
```

### Run specific test file
```bash
mix test test/vsm_mcp_basic_test.exs
```

### Run tests with coverage
```bash
mix test --cover
```

### Run only integration tests
```bash
mix test --only integration
```

### Run tests that require API keys
```bash
mix test --only requires_api_key
```

## Test Categories

### Unit Tests
- **Systems Tests**: Test each VSM system (1-5) independently
- **Core Tests**: Test variety calculations and MCP discovery
- **Protocol Tests**: Test MCP protocol implementation

### Integration Tests
- **Full System Test**: Tests the complete VSM-MCP system working together
- **Real Implementation Test**: Tests actual HTTP calls and system metrics
- **LLM Integration Test**: Tests AI integration (requires API key)

### Special Test Tags

- `@tag :integration` - Integration tests that may take longer
- `@tag :requires_api_key` - Tests that need LLM API keys
- `@tag :network` - Tests that require network access

## Test Coverage

The test suite covers:
- ✅ All 5 VSM systems (Operations, Coordination, Control, Intelligence, Policy)
- ✅ Variety calculations using Ashby's Law
- ✅ MCP server discovery from NPM
- ✅ Capability matching and integration
- ✅ Consciousness interface and awareness
- ✅ LLM integration for intelligent decisions
- ✅ Real system metrics and calculations
- ✅ End-to-end capability acquisition

## Known Issues

1. Some tests require the application to be started - use `mix test` instead of `mix test --no-start`
2. LLM tests require valid API keys in `.env` file
3. Network tests may fail if offline
4. Some older test files may need updating to match current API

## Writing New Tests

When adding new tests:
1. Place unit tests in the appropriate subdirectory
2. Tag integration tests with `@tag :integration`
3. Use descriptive test names
4. Mock external dependencies where appropriate
5. Ensure tests can run independently