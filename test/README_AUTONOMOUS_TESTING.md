# VSM-MCP Autonomous Capability Testing Suite

## Overview

This comprehensive testing suite validates the autonomous capabilities of the VSM-MCP system, including:

- **Autonomous Discovery**: Testing MCP server discovery and evaluation
- **Autonomous Integration**: Testing complete capability acquisition pipelines
- **Performance Validation**: Benchmarking autonomous operations under load
- **Real-time Operations**: Testing daemon mode and live monitoring
- **API/WebSocket Integration**: Testing REST API and WebSocket functionality
- **Scenario-based Testing**: End-to-end business workflow validation

## Test Structure

### Core Test Suites

1. **`autonomous_capability_validation_test.exs`**
   - Tests autonomous variety gap detection
   - Validates capability discovery and evaluation
   - Tests complete integration pipelines
   - Validates daemon mode functionality
   - Tests REST API and WebSocket operations
   - **Duration**: ~2 minutes
   - **Priority**: Critical

2. **`autonomous_performance_benchmark_test.exs`**
   - Discovery performance under various loads
   - Integration throughput testing
   - Variety calculation performance
   - Daemon mode responsiveness
   - Scalability testing
   - **Duration**: ~3 minutes
   - **Priority**: High

3. **`autonomous_api_websocket_test.exs`**
   - REST API autonomous operations
   - WebSocket real-time monitoring
   - API-triggered capability acquisition
   - Live updates and notifications
   - **Duration**: ~1.5 minutes
   - **Priority**: High

4. **`autonomous_scenario_integration_test.exs`**
   - Business document processing scenarios
   - Data pipeline automation
   - API integration scenarios
   - Real-time streaming processing
   - ML model deployment
   - Security and compliance
   - Complete business workflow automation
   - **Duration**: ~5 minutes
   - **Priority**: Medium

### Supporting Test Files

5. **`autonomous_integration_execution_test.exs`** (Existing)
   - Basic autonomous integration workflows
   - **Duration**: ~1.5 minutes
   - **Priority**: Medium

6. **`real_mcp_integration_test.exs`** (Existing)
   - Real MCP server integration testing
   - **Duration**: ~2 minutes
   - **Priority**: Low

7. **`mcp_integration_comprehensive_test.exs`** (Existing)
   - Comprehensive MCP integration scenarios
   - **Duration**: ~1 minute
   - **Priority**: Medium

### Test Runner

**`autonomous_test_runner.exs`**
- Orchestrates all autonomous tests
- Provides comprehensive reporting
- Supports multiple execution modes
- Performance analysis and recommendations

## Running Tests

### Quick Start

```bash
# Run all critical and high priority tests
./test/autonomous_test_runner.exs

# Run comprehensive test suite
./test/autonomous_test_runner.exs --comprehensive

# Run quick validation (30s timeout)
./test/autonomous_test_runner.exs --quick

# Run specific test suite
./test/autonomous_test_runner.exs --suite "Autonomous Capability Validation"

# Run by priority
./test/autonomous_test_runner.exs --priority critical
```

### Individual Test Execution

```bash
# Run individual test files
mix test test/autonomous_capability_validation_test.exs
mix test test/autonomous_performance_benchmark_test.exs
mix test test/autonomous_api_websocket_test.exs
mix test test/autonomous_scenario_integration_test.exs

# Run with specific tags
mix test --only autonomous_validation
mix test --only performance_benchmark
mix test --only api_websocket
mix test --only scenario_integration
```

### Environment Setup

The tests require specific environment setup:

```bash
# Ensure test dependencies
mix deps.get

# Set test environment
export MIX_ENV=test
export AUTONOMOUS_TEST_MODE=true

# Optional: Enable real MCP server tests
export RUN_REAL_MCP_TESTS=true

# Optional: Enable external network tests
export ENABLE_NETWORK_TESTS=true
```

## Test Categories

### 🔍 Discovery Tests
- **Autonomous server discovery** - Tests MCP server discovery based on variety gaps
- **Quality evaluation** - Tests server ranking and selection algorithms
- **Adaptive strategies** - Tests learning from discovery failures
- **Caching effectiveness** - Tests discovery result caching

### 🔧 Integration Tests
- **End-to-end pipelines** - Tests complete autonomous integration workflows
- **Transaction integrity** - Tests rollback and consistency mechanisms
- **Concurrent operations** - Tests thread safety and parallel processing
- **Error handling** - Tests autonomous error recovery

### ⚡ Performance Tests
- **Discovery latency** - Measures discovery performance under load
- **Integration throughput** - Tests concurrent integration capabilities
- **Variety calculations** - Benchmarks variety calculation performance
- **Memory efficiency** - Tests resource usage patterns

### 🌐 API/WebSocket Tests
- **REST API operations** - Tests API-triggered autonomous capabilities
- **Real-time monitoring** - Tests WebSocket live updates
- **Concurrent clients** - Tests multiple WebSocket connections
- **API-WebSocket integration** - Tests coordinated API and WebSocket operations

### 📋 Scenario Tests
- **Business workflows** - Tests real-world business process automation
- **Document processing** - Tests PowerPoint and document generation scenarios
- **Data pipelines** - Tests complex data processing workflows
- **API integrations** - Tests external API integration scenarios
- **Streaming processing** - Tests real-time data processing
- **ML deployment** - Tests machine learning model deployment
- **Security compliance** - Tests security scanning and compliance monitoring

### 🔄 Daemon Mode Tests
- **Responsiveness** - Tests daemon mode response times
- **Resource efficiency** - Tests long-running daemon resource usage
- **Continuous monitoring** - Tests variety gap detection over time
- **Stability** - Tests extended operation stability

## Test Validation Criteria

### ✅ Success Criteria

1. **Discovery Performance**
   - Discovery latency < 5 seconds for complex queries
   - Concurrent discovery throughput ≥ 1 discovery/second
   - Cache effectiveness ≥ 2x speedup
   - Success rate ≥ 80% for discovery operations

2. **Integration Performance**
   - End-to-end integration < 30 seconds
   - Integration throughput ≥ 0.1 integrations/second
   - Success rate ≥ 70% for autonomous integrations
   - Error recovery rate ≥ 90%

3. **Variety Calculations**
   - Simple calculations < 50ms
   - Complex calculations < 1 second
   - Memory usage < 50MB for large contexts
   - No memory leaks in repeated calculations

4. **Daemon Mode**
   - Response time < 1 second average, < 2 seconds maximum
   - Memory overhead < 5MB
   - Process overhead ≤ 3 additional processes
   - CPU usage < 10%

5. **API/WebSocket**
   - API response time < 2 seconds for complex operations
   - WebSocket message delivery < 100ms
   - Concurrent client support ≥ 5 clients
   - Message delivery success rate ≥ 99%

6. **Scenarios**
   - Business workflow completion time < 2 hours
   - Workflow success rate ≥ 95%
   - Error recovery rate ≥ 90%
   - Resource efficiency ≥ 80%

### ⚠️ Warning Thresholds

- Discovery latency > 3 seconds
- Integration failure rate > 20%
- Memory usage growth > 100KB per operation
- API response time > 1 second
- WebSocket delivery failures > 1%

### ❌ Failure Criteria

- System crashes or unrecoverable errors
- Memory leaks or excessive resource usage
- Security vulnerabilities in autonomous operations
- Data corruption or consistency violations
- Performance degradation > 50% from baseline

## Test Environment

### Dependencies

```elixir
# Test-specific dependencies in mix.exs
defp deps do
  [
    {:meck, "~> 0.9", only: :test},
    {:websocket_client, "~> 1.4", only: :test},
    {:httpoison, "~> 1.8"},
    {:jason, "~> 1.4"},
    {:ex_unit, "~> 1.14", only: :test}
  ]
end
```

### Mock Setup

The tests use comprehensive mocking to simulate:
- MCP server discovery responses
- Installation and deployment processes
- External API interactions
- WebSocket connections
- Business workflow components

### Test Data

Test data includes:
- Mock MCP server configurations
- Sample variety gaps and business scenarios
- Performance benchmarking datasets
- Security test vectors
- Compliance standard requirements

## Reporting

### Test Reports

The test runner generates comprehensive reports including:

- **Summary statistics** - Pass/fail rates, duration, performance
- **Priority breakdown** - Results by test priority level
- **Performance analysis** - Speed and efficiency metrics
- **Failure details** - Detailed failure information and stack traces
- **Recommendations** - Suggested improvements and optimizations

### Report Output

```json
{
  "timestamp": "2025-01-24T01:00:00.000Z",
  "overall_score": 87,
  "summary": {
    "total_suites": 7,
    "passed": 6,
    "failed": 1,
    "errors": 0,
    "skipped": 0
  },
  "results": [...]
}
```

### Continuous Integration

For CI/CD integration:

```bash
# Run in CI mode
./test/autonomous_test_runner.exs --quick --output json

# Check exit code
if [ $? -eq 0 ]; then
  echo "Autonomous capability tests passed"
else
  echo "Autonomous capability tests failed"
  exit 1
fi
```

## Troubleshooting

### Common Issues

1. **Test Timeouts**
   - Increase timeout with `--timeout` option
   - Check system resource availability
   - Review test environment setup

2. **Mock Failures**
   - Ensure meck dependency is available
   - Check for conflicting mock setups
   - Verify test isolation

3. **Network Tests**
   - Enable network tests with environment variables
   - Check firewall and network connectivity
   - Use mock mode for isolated testing

4. **Performance Variations**
   - Run tests on consistent hardware
   - Close unnecessary applications
   - Use performance test mode for benchmarking

### Debug Mode

Enable verbose logging:

```bash
export LOG_LEVEL=debug
./test/autonomous_test_runner.exs --verbose
```

### Test Isolation

Each test suite runs in isolation with:
- Unique process names
- Separate test directories
- Independent mock setups
- Cleanup after completion

## Contributing

When adding new autonomous capability tests:

1. Follow the established test structure and naming conventions
2. Include comprehensive documentation and assertions
3. Add appropriate mocking for external dependencies
4. Update the test runner configuration
5. Ensure tests are deterministic and isolated
6. Include performance benchmarks where applicable

### Test Guidelines

- **Test real autonomous behavior** - Focus on end-to-end autonomous workflows
- **Use realistic scenarios** - Base tests on actual business use cases
- **Validate performance** - Include timing and resource usage validation
- **Test error conditions** - Verify autonomous error handling and recovery
- **Document expectations** - Clearly state success criteria and thresholds

## Future Enhancements

Planned test suite improvements:

1. **Fuzzing tests** - Random input validation for robustness
2. **Load testing** - Extended performance testing under extreme load
3. **Chaos engineering** - Testing resilience under failure conditions
4. **Machine learning validation** - Testing autonomous learning capabilities
5. **Multi-environment testing** - Testing across different deployment environments