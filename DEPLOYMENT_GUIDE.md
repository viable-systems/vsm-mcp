# VSM-MCP Deployment Guide

**Version**: 2.0.0  
**Date**: 2025-07-23  
**Status**: ⚠️ BLOCKED - Critical compilation error must be resolved first

## 🚨 CRITICAL PRE-DEPLOYMENT REQUIREMENT

**BLOCKING ISSUE**: Compilation error in `lib/vsm_mcp/llm/api.ex:196`
```elixir
error: AsyncResponse.__struct__/1 is undefined
```

**YOU MUST FIX THIS BEFORE DEPLOYMENT**

## Pre-Deployment Checklist

### 🔍 System Requirements Verification
- [ ] Elixir 1.14+ installed
- [ ] Erlang/OTP 25+ installed  
- [ ] Node.js 18+ for MCP server integration
- [ ] Git for version control
- [ ] 4GB+ RAM available
- [ ] 10GB+ disk space

### 🛠️ Build Verification (CURRENTLY FAILING)
```bash
# These commands MUST succeed before deployment
cd /path/to/vsm-mcp

# 1. Install dependencies
mix deps.get

# 2. Compile (CURRENTLY FAILS)
mix compile  # ❌ FAILS - AsyncResponse error

# 3. Run tests (BLOCKED)  
mix test    # ❌ BLOCKED by compilation

# 4. Security validation (BLOCKED)
mix test --only security  # ❌ BLOCKED
```

### 🔒 Security Configuration Required

#### 1. Environment Variables
Create `.env` file:
```bash
# Required for LLM integration
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# Security settings
VSM_SECURITY_ENABLED=true
VSM_SANDBOX_ENABLED=true
VSM_AUDIT_LOGGING=true

# Performance settings  
VSM_MAX_CONCURRENT_INSTALLS=5
VSM_CACHE_TTL_SECONDS=300
VSM_HTTP_TIMEOUT_MS=10000
```

#### 2. Security Configuration in `config/prod.exs`
```elixir
config :vsm_mcp, :security,
  sandbox_enabled: true,
  whitelist_enforced: true,
  network_isolated: true,
  max_memory_mb: 512,
  max_cpu_percent: 50,
  min_security_score: 70,
  
  # Package whitelist - CRITICAL for security
  package_whitelist: [
    # Web frameworks
    "express", "fastify", "hapi",
    
    # HTTP clients  
    "axios", "node-fetch", "got",
    
    # Utilities
    "lodash", "ramda", "underscore",
    
    # Logging
    "winston", "bunyan", "pino",
    
    # Testing
    "jest", "mocha", "chai",
    
    # Build tools
    "typescript", "babel", "webpack",
    
    # Official SDKs
    "@anthropic/sdk"
  ],
  
  # Blocked dangerous packages
  blocked_packages: [
    "child_process", "cluster", "dgram",
    "dns", "net", "tls", "crypto",
    "fs", "path", "os", "process",
    "eval", "vm", "domain"
  ]
```

## Deployment Methods

### Method 1: Development Deployment (Recommended First)

#### Step 1: Fix Compilation Error (REQUIRED)
```bash
# Navigate to the project
cd /home/batmanosama/viable-systems/vsm-mcp

# Fix the AsyncResponse error in lib/vsm_mcp/llm/api.ex
# This MUST be done before proceeding
```

#### Step 2: Environment Setup
```bash
# Install dependencies
mix deps.get

# Verify compilation (after fix)
mix compile

# Create production configuration
cp config/dev.exs config/prod.exs
# Edit config/prod.exs with production settings
```

#### Step 3: Security Validation
```bash
# Run security tests
mix test test/vsm_mcp/integration/security_test.exs

# Verify sandbox functionality  
mix test test/vsm_mcp/integration/sandbox_test.exs

# Test package validation
elixir -e "
IO.puts VsmMcp.Integration.PackageValidator.validate_package('express')
IO.puts VsmMcp.Integration.PackageValidator.validate_package('child_process')
"
```

#### Step 4: Performance Verification
```bash
# Run performance tests
mix test test/vsm_mcp/integration/parallel_execution_test.exs

# Benchmark variety calculations
elixir lib/vsm_mcp/benchmarks/variety_benchmark.ex
```

#### Step 5: Full System Test
```bash
# Test VSM system integration
elixir examples/real_autonomous_demo.exs

# Test MCP protocol compliance
elixir examples/mcp_demo.exs

# Test consciousness interface
elixir examples/consciousness_demo.exs
```

### Method 2: Production Deployment (After Dev Success)

#### Prerequisites
- [ ] ✅ Compilation successful in development
- [ ] ✅ All tests passing  
- [ ] ✅ Security validation complete
- [ ] ✅ Performance benchmarks acceptable
- [ ] ✅ End-to-end testing successful

#### Production Environment Setup
```bash
# 1. Clone production repository
git clone https://github.com/viable-systems/vsm-mcp.git vsm-mcp-prod
cd vsm-mcp-prod

# 2. Set production environment
export MIX_ENV=prod

# 3. Install production dependencies
mix deps.get --only prod

# 4. Compile for production (after fixing AsyncResponse)
mix compile

# 5. Run production tests
MIX_ENV=prod mix test --include production

# 6. Create release
mix release
```

#### Production Configuration
```elixir
# config/prod.exs
import Config

config :vsm_mcp,
  # Disable debug logging in production
  log_level: :info,
  
  # Enable all security features
  security: [
    sandbox_enabled: true,
    whitelist_enforced: true,
    network_isolated: true,
    audit_logging: true,
    max_memory_mb: 1024,
    max_cpu_percent: 75,
    min_security_score: 80
  ],
  
  # Production performance settings
  performance: [
    max_concurrent_installs: 10,
    discovery_cache_ttl: 600,
    health_check_interval: 30,
    http_pool_size: 50
  ],
  
  # Telemetry and monitoring
  telemetry: [
    enabled: true,
    metrics_interval: 60_000,
    export_format: :prometheus
  ]

# Database configuration for audit logs
config :vsm_mcp, VsmMcp.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: 10

# Logger configuration
config :logger,
  level: :info,
  format: "$time $metadata[$level] $message\n",
  backends: [:console, {LoggerFileBackend, :audit}]

config :logger, :audit,
  path: "/var/log/vsm-mcp/audit.log",
  level: :info
```

## Monitoring and Observability

### Health Checks
Create monitoring endpoints:
```elixir
# Health check endpoint
defmodule VsmMcp.HealthCheck do
  def check_system_health do
    %{
      status: :healthy,
      timestamp: DateTime.utc_now(),
      components: %{
        vsm_systems: check_vsm_systems(),
        mcp_servers: check_mcp_servers(),
        security: check_security_status(),
        performance: check_performance_metrics()
      }
    }
  end
end
```

### Metrics Collection
```bash
# Set up Prometheus metrics endpoint
mix deps.get telemetry_metrics_prometheus_core

# Configure in application.ex
{TelemetryMetricsPrometheus.Core, [
  metrics: VsmMcp.Telemetry.metrics()
]},
```

### Log Aggregation
```bash
# Set up structured logging
config :logger, :console,
  format: {VsmMcp.LogFormatter, :format},
  metadata: [:request_id, :mfa, :file, :line]
```

## Security Deployment Checklist

### 🔒 Critical Security Validations

#### Sandbox Isolation Testing
```bash
# Test process isolation
elixir -e "
{:ok, result} = VsmMcp.Integration.Sandbox.test_server(
  'test-package',
  %{capabilities: ['web-search']}
)
IO.inspect(result.security_scan)
"
```

#### Package Whitelist Enforcement
```bash
# Verify whitelist enforcement
elixir -e "
# Should succeed
IO.puts VsmMcp.Integration.PackageValidator.validate_package('express')

# Should fail  
IO.puts VsmMcp.Integration.PackageValidator.validate_package('child_process')
"
```

#### Network Isolation Verification
```bash
# Test network restrictions
elixir -e "
VsmMcp.Integration.Sandbox.test_network_isolation()
"
```

### 🛡️ Security Monitoring Setup

#### Audit Log Configuration
```bash
# Create audit log directory
mkdir -p /var/log/vsm-mcp
chown vsm-mcp:vsm-mcp /var/log/vsm-mcp
chmod 750 /var/log/vsm-mcp

# Set up log rotation
cat > /etc/logrotate.d/vsm-mcp << EOF
/var/log/vsm-mcp/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 640 vsm-mcp vsm-mcp
}
EOF
```

#### Security Alerting
```bash
# Set up security event alerts
config :vsm_mcp, :alerts,
  security_violations: [
    webhook_url: "https://your-alerts.example.com/security",
    threshold: 5,
    window_minutes: 15
  ]
```

## Performance Optimization

### Resource Allocation
```elixir
config :vsm_mcp, :resources,
  # Per-sandbox limits
  sandbox_memory_mb: 512,
  sandbox_cpu_percent: 50,
  sandbox_timeout_ms: 300_000,
  
  # System-wide limits  
  max_concurrent_sandboxes: 10,
  max_concurrent_discoveries: 20,
  max_concurrent_installs: 5,
  
  # Cache settings
  variety_cache_size: 1000,
  discovery_cache_size: 500,
  capability_cache_size: 2000
```

### Database Optimization
```elixir
config :vsm_mcp, VsmMcp.Repo,
  pool_size: 15,
  queue_target: 50,
  queue_interval: 1000,
  
  # Connection settings
  timeout: 15_000,
  ownership_timeout: 60_000,
  
  # Performance tuning
  log: false,
  prepare: :named,
  parameters: [
    application_name: "vsm_mcp_prod"
  ]
```

## Troubleshooting Common Issues

### 🚨 Compilation Errors

#### AsyncResponse Error (CURRENT BLOCKER)
```bash
# Error: AsyncResponse.__struct__/1 is undefined
# Location: lib/vsm_mcp/llm/api.ex:196

# Possible fixes:
# 1. Define the struct:
defmodule AsyncResponse do
  defstruct [:id, :status, :data]
end

# 2. Import from correct module:
import SomeModule.AsyncResponse

# 3. Check dependencies in mix.exs
```

#### Missing Dependencies
```bash
# Error: Can't continue due to errors on dependencies
mix deps.get
mix deps.compile
```

### 🔧 Runtime Issues

#### Sandbox Creation Failures
```bash
# Check directory permissions
ls -la /tmp/vsm-mcp-sandboxes/
chmod 755 /tmp/vsm-mcp-sandboxes/

# Check available disk space
df -h /tmp
```

#### Memory Limit Exceeded
```bash
# Monitor memory usage
elixir -e "
:observer.start()
# Or programmatically:
:erlang.memory()
"

# Adjust limits in config
config :vsm_mcp, :security,
  max_memory_mb: 1024  # Increase if needed
```

#### Network Connectivity Issues
```bash
# Test external connectivity
curl -I https://registry.npmjs.org/

# Check firewall rules
iptables -L | grep -i drop

# Verify DNS resolution
nslookup registry.npmjs.org
```

### 📊 Performance Issues

#### Slow Variety Calculations
```bash
# Check cache hit rates
elixir -e "VsmMcp.Core.VarietyCalculatorOptimized.cache_stats()"

# Monitor parallel processing
elixir -e "VsmMcp.Benchmarks.VarietyBenchmark.benchmark_parallel_efficiency()"
```

#### MCP Discovery Timeouts
```bash
# Check HTTP pool status
elixir -e "Finch.get_pool_status(MCPFinch)"

# Adjust timeout settings
config :vsm_mcp, :discovery,
  http_timeout: 15_000,  # Increase timeout
  max_retries: 5
```

## Rollback Procedures

### Emergency Rollback
```bash
# 1. Stop application
systemctl stop vsm-mcp

# 2. Restore previous version
cp -r /opt/vsm-mcp-backup/* /opt/vsm-mcp/

# 3. Restore configuration
cp config/prod.exs.backup config/prod.exs

# 4. Restart with previous version
systemctl start vsm-mcp

# 5. Verify rollback success
curl http://localhost:4000/health
```

### Gradual Rollback
```bash
# 1. Switch traffic to backup instance
# Update load balancer to backup servers

# 2. Monitor for 30 minutes
# Check metrics and logs

# 3. Full rollback if issues persist
# Complete switch to previous version
```

## Post-Deployment Verification

### 🧪 Functional Testing
```bash
# 1. Basic system health
curl http://localhost:4000/health

# 2. VSM system status
elixir -e "VsmMcp.status()"

# 3. Security validation
elixir test/vsm_mcp/integration/security_test.exs

# 4. Performance benchmark
elixir lib/vsm_mcp/benchmarks/variety_benchmark.ex

# 5. End-to-end capability acquisition
elixir examples/real_autonomous_demo.exs
```

### 📈 Performance Validation
```bash
# Check performance metrics meet targets
elixir -e "
metrics = VsmMcp.Telemetry.get_metrics()
IO.puts 'Variety calculation speed: #{metrics.variety_speed_improvement}'
IO.puts 'Cache hit rate: #{metrics.cache_hit_rate}'
IO.puts 'Parallel efficiency: #{metrics.parallel_efficiency}'
"
```

### 🔐 Security Validation
```bash
# Verify all security features active
elixir -e "
security_status = VsmMcp.SecurityStatus.full_report()
IO.inspect(security_status)
"

# Test sandbox escape prevention
# (Should be performed by security team)
```

## Maintenance Procedures

### Daily Maintenance
- [ ] Check audit logs for security violations
- [ ] Monitor performance metrics
- [ ] Verify backup completion
- [ ] Review resource utilization

### Weekly Maintenance
- [ ] Update MCP server whitelist if needed
- [ ] Review and rotate logs
- [ ] Performance optimization review
- [ ] Security vulnerability scan

### Monthly Maintenance
- [ ] Full system backup
- [ ] Dependency update review
- [ ] Capacity planning review
- [ ] Security audit

## Support and Escalation

### Level 1: Application Issues
- Performance degradation
- Configuration problems
- User access issues

### Level 2: Security Issues
- Potential security violations
- Sandbox escape attempts
- Unauthorized access

### Level 3: Critical System Issues
- System unavailable
- Data corruption
- Security breaches

### Emergency Contacts
- **Technical Lead**: [Contact Info]
- **Security Team**: [Contact Info]  
- **DevOps Team**: [Contact Info]

---

## ⚠️ REMEMBER: DEPLOYMENT IS BLOCKED

**THIS DEPLOYMENT GUIDE CANNOT BE USED UNTIL:**
1. ✅ AsyncResponse compilation error is fixed
2. ✅ `mix compile` succeeds without errors
3. ✅ All tests pass successfully
4. ✅ Security validation completes

**DO NOT ATTEMPT DEPLOYMENT WITH COMPILATION ERRORS**

---

**Deployment Guide Version**: 2.0.0  
**Last Updated**: 2025-07-23  
**Status**: BLOCKED - Fix compilation error first  
**Next Review**: After AsyncResponse fix