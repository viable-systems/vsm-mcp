# CLI Control Interface Specifications

## Overview

This document defines the command-line interface (CLI) for controlling and monitoring the VSM-MCP autonomous daemon system. The CLI provides comprehensive control capabilities for system administration, monitoring, and operational management.

## Installation & Setup

```bash
# Install CLI globally
npm install -g vsm-mcp-cli

# Or use local installation
cd /opt/vsm-mcp && ./bin/vsm-daemon --help

# Set environment variables
export VSM_DAEMON_HOST=localhost
export VSM_DAEMON_PORT=4001
export VSM_DAEMON_TOKEN=your_auth_token_here
```

## 1. Core Daemon Commands

### 1.1 Daemon Lifecycle Management

#### Start Daemon

```bash
vsm-daemon start [OPTIONS]

OPTIONS:
  --config, -c PATH           Configuration file path (default: /etc/vsm-mcp/daemon.config)
  --port, -p PORT            HTTP API port (default: 4000)
  --cli-port PORT            CLI control port (default: 4001)
  --log-level LEVEL          Log level: debug|info|warn|error (default: info)
  --log-file PATH            Log file path (default: /var/log/vsm-daemon.log)
  --pid-file PATH            PID file path (default: /var/run/vsm-daemon.pid)
  --daemon, -d               Run as background daemon
  --no-auto-start            Don't auto-start VSM systems
  --dry-run                  Validate configuration without starting

EXAMPLES:
  vsm-daemon start --config=/home/user/my-config.json --daemon
  vsm-daemon start --port=8080 --log-level=debug
  vsm-daemon start --dry-run  # Validate configuration only
```

#### Stop Daemon

```bash
vsm-daemon stop [OPTIONS]

OPTIONS:
  --graceful, -g             Graceful shutdown (wait for operations)
  --timeout, -t SECONDS      Graceful shutdown timeout (default: 30)
  --force, -f                Force immediate shutdown
  --preserve-state           Save current state before shutdown

EXAMPLES:
  vsm-daemon stop --graceful --timeout=60
  vsm-daemon stop --force                    # Emergency stop
  vsm-daemon stop --preserve-state          # Save state for restart
```

#### Restart Daemon

```bash
vsm-daemon restart [OPTIONS]

OPTIONS:
  --service, -s SERVICE      Restart specific service only
  --graceful, -g             Graceful restart
  --config, -c PATH          New configuration file
  --preserve-connections     Keep client connections during restart

EXAMPLES:
  vsm-daemon restart --service=mcp_servers
  vsm-daemon restart --graceful --config=/new/config.json
```

#### Daemon Status

```bash
vsm-daemon status [OPTIONS]

OPTIONS:
  --detailed, -d             Show detailed status information
  --json, -j                 Output in JSON format
  --watch, -w                Continuously monitor (update every 5s)
  --components COMPONENTS    Show specific components (comma-separated)

EXAMPLES:
  vsm-daemon status --detailed
  vsm-daemon status --json | jq '.vsm_systems'
  vsm-daemon status --watch                 # Live monitoring
  vsm-daemon status --components=vsm_systems,mcp_servers
```

**Sample Output:**
```
VSM-MCP Daemon Status
====================
Daemon:           RUNNING (uptime: 2d 4h 32m)
Version:          0.1.0
Process ID:       12345
Memory Usage:     128.5 MB
CPU Usage:        15.2%

VSM Systems:
  System 1:       ACTIVE    (1,250 operations, 98% success rate)
  System 2:       ACTIVE    (45 coordination points)
  System 3:       ACTIVE    (12 audit cycles, 92% compliance)
  System 4:       ACTIVE    (8 scans completed, 2 threats detected)
  System 5:       ACTIVE    (23 decisions made)

Variety Status:   85% (3 gaps detected, threshold: 70%)

MCP Servers:      5/8 active (4 healthy, 1 degraded)

Consciousness:    AWARE (47 insights, learning: 73%)
```

## 2. VSM System Management

### 2.1 List Systems

```bash
vsm-daemon systems list [OPTIONS]

OPTIONS:
  --status STATUS            Filter by status: active|inactive|error
  --include-metrics          Include performance metrics
  --include-capabilities     Include capability information
  --sort FIELD               Sort by: id|status|operations|performance
  --output FORMAT            Output format: table|json|yaml

EXAMPLES:
  vsm-daemon systems list --status=active --include-metrics
  vsm-daemon systems list --output=json
```

### 2.2 System Status

```bash
vsm-daemon systems status SYSTEM_ID [OPTIONS]

SYSTEM_ID: system1|system2|system3|system4|system5

OPTIONS:
  --metrics, -m              Include detailed metrics
  --operations, -o           Show recent operations
  --capabilities, -c         Show capabilities list
  --mcp-servers             Show associated MCP servers

EXAMPLES:
  vsm-daemon systems status system1 --metrics --operations
  vsm-daemon systems status system4 --capabilities
```

### 2.3 Trigger System Actions

```bash
vsm-daemon systems trigger SYSTEM_ID ACTION [OPTIONS]

SYSTEM_ID: system1|system2|system3|system4|system5
ACTION: execute|audit|scan|coordinate|decide|optimize

OPTIONS:
  --parameters, -p PARAMS    Action parameters (JSON format)
  --priority PRIORITY        Priority: low|medium|high|critical
  --timeout SECONDS          Operation timeout (default: 30)
  --async, -a                Run asynchronously
  --dry-run                  Simulate action without execution

EXAMPLES:
  vsm-daemon systems trigger system1 execute --parameters='{"type":"process","data":"test"}'
  vsm-daemon systems trigger system3 audit --async
  vsm-daemon systems trigger system4 scan --priority=high
  vsm-daemon systems trigger system5 decide --parameters='{"context":"emergency"}'
```

## 3. Variety Management

### 3.1 Variety Status

```bash
vsm-daemon variety status [OPTIONS]

OPTIONS:
  --detailed, -d             Show detailed variety analysis
  --trends, -t               Include variety trends
  --gaps, -g                 Show capability gaps
  --breakdown, -b            Show variety breakdown by source
  --threshold                Show threshold information

EXAMPLES:
  vsm-daemon variety status --detailed --trends
  vsm-daemon variety status --gaps --threshold
```

**Sample Output:**
```
Variety Analysis
================
Current Ratio:    85% (102.4 / 120.5)
Threshold:        70% (ABOVE THRESHOLD ✓)
Trend:            INCREASING (+3% last hour)
Last Assessed:    2024-01-01 00:00:00 UTC

Breakdown:
  Internal:       45.2 (37.5%)
  MCP Servers:    35.8 (29.7%) 
  LLM Generated:  21.4 (17.8%)

Capability Gaps (3):
  1. [MEDIUM] Advanced document generation (impact: 15%)
  2. [LOW]    Image processing optimization (impact: 8%)
  3. [LOW]    API rate limiting (impact: 5%)

Opportunities (2):
  1. Optimize existing PDF generation (+8% variety)
  2. Enhance data analysis capabilities (+12% variety)
```

### 3.2 Analyze Variety

```bash
vsm-daemon variety analyze [OPTIONS]

OPTIONS:
  --force, -f                Force new analysis (ignore cache)
  --external-scan            Include external capability scan
  --deep-analysis            Perform comprehensive analysis
  --mcp-discovery            Discover new MCP servers
  --output FORMAT            Output format: summary|detailed|json
  --save-report PATH         Save analysis report to file

EXAMPLES:
  vsm-daemon variety analyze --force --external-scan
  vsm-daemon variety analyze --deep-analysis --save-report=/tmp/variety-report.json
  vsm-daemon variety analyze --mcp-discovery --output=detailed
```

### 3.3 List Capability Gaps

```bash
vsm-daemon variety gaps list [OPTIONS]

OPTIONS:
  --severity LEVEL           Filter by severity: low|medium|high|critical
  --type TYPE                Filter by type: capability|performance|security
  --sort FIELD               Sort by: severity|impact|type|age
  --limit NUMBER             Maximum gaps to show (default: 10)
  --solutions                Include recommended solutions

EXAMPLES:
  vsm-daemon variety gaps list --severity=high --solutions
  vsm-daemon variety gaps list --type=capability --sort=impact
```

### 3.4 Acquire Capability

```bash
vsm-daemon variety acquire CAPABILITY [OPTIONS]

CAPABILITY: The capability to acquire (e.g., "document_generation", "image_processing")

OPTIONS:
  --method METHOD            Acquisition method: mcp_server|npm_package|llm_generation|auto
  --priority PRIORITY        Priority: low|medium|high|critical
  --timeout SECONDS          Acquisition timeout (default: 300)
  --auto-integrate           Automatically integrate after acquisition
  --sandbox-test             Test in sandbox before integration
  --security-scan            Perform security scan
  --dry-run                  Simulate acquisition without execution

EXAMPLES:
  vsm-daemon variety acquire "presentation_generation" --method=mcp_server --auto-integrate
  vsm-daemon variety acquire "advanced_analytics" --priority=high --sandbox-test
  vsm-daemon variety acquire "document_processing" --dry-run
```

## 4. MCP Server Management

### 4.1 List MCP Servers

```bash
vsm-daemon mcp list [OPTIONS]

OPTIONS:
  --status STATUS            Filter by status: active|inactive|starting|stopping|error
  --health HEALTH            Filter by health: healthy|degraded|unhealthy
  --capabilities CAPS        Filter by capabilities (comma-separated)
  --sort FIELD               Sort by: name|status|uptime|requests|health
  --output FORMAT            Output format: table|json|yaml
  --include-metrics          Include performance metrics

EXAMPLES:
  vsm-daemon mcp list --status=active --include-metrics
  vsm-daemon mcp list --health=degraded
  vsm-daemon mcp list --capabilities=document,pdf --output=json
```

### 4.2 Register MCP Server

```bash
vsm-daemon mcp register [OPTIONS]

OPTIONS:
  --name NAME                Server name (required)
  --source SOURCE            Installation source: npm:package|github:repo|local:path
  --command COMMAND          Execution command
  --transport TYPE           Transport type: stdio|tcp|websocket
  --port PORT                Port for TCP/WebSocket transport
  --auto-start               Automatically start after registration
  --health-check             Enable health monitoring
  --config PATH              Server configuration file

EXAMPLES:
  vsm-daemon mcp register --name=document-gen --source=npm:@mcp/document-generator --auto-start
  vsm-daemon mcp register --name=custom-ai --source=github:user/custom-ai-mcp --health-check
  vsm-daemon mcp register --name=local-server --source=local:/opt/servers/my-server --command="node server.js"
```

### 4.3 Server Control

```bash
vsm-daemon mcp start SERVER_ID [OPTIONS]
vsm-daemon mcp stop SERVER_ID [OPTIONS] 
vsm-daemon mcp restart SERVER_ID [OPTIONS]

OPTIONS:
  --graceful, -g             Graceful operation
  --timeout SECONDS          Operation timeout
  --force, -f                Force operation (stop/restart only)

EXAMPLES:
  vsm-daemon mcp start mcp_doc_gen_001
  vsm-daemon mcp stop mcp_analysis_002 --graceful --timeout=30
  vsm-daemon mcp restart mcp_image_proc_003 --force
```

### 4.4 Server Details

```bash
vsm-daemon mcp status SERVER_ID [OPTIONS]

OPTIONS:
  --metrics, -m              Include performance metrics
  --capabilities, -c         Show available capabilities
  --logs, -l                 Show recent logs
  --health, -h               Show health check details

EXAMPLES:
  vsm-daemon mcp status mcp_doc_gen_001 --metrics --capabilities
  vsm-daemon mcp status mcp_analysis_002 --logs --health
```

### 4.5 Discover MCP Servers

```bash
vsm-daemon mcp discover [OPTIONS]

OPTIONS:
  --source SOURCE            Discovery source: npm|github|registry|all
  --capability CAPABILITY    Search for specific capability
  --auto-register           Automatically register suitable servers
  --security-threshold SCORE Minimum security score (0-100)
  --limit NUMBER             Maximum servers to discover
  --save-catalog PATH        Save discovery results to file

EXAMPLES:
  vsm-daemon mcp discover --source=npm --capability=document_generation
  vsm-daemon mcp discover --auto-register --security-threshold=80
  vsm-daemon mcp discover --save-catalog=/tmp/mcp-catalog.json
```

### 4.6 Call MCP Server Tool

```bash
vsm-daemon mcp call SERVER_ID TOOL_NAME [OPTIONS]

OPTIONS:
  --arguments, -a ARGS       Tool arguments (JSON format)
  --timeout SECONDS          Call timeout (default: 30)
  --output FORMAT            Output format: json|text|raw
  --save-result PATH         Save result to file

EXAMPLES:
  vsm-daemon mcp call mcp_doc_gen_001 create_document --arguments='{"title":"Report","format":"pdf"}'
  vsm-daemon mcp call mcp_analysis_002 analyze_data --arguments='{"data":[1,2,3,4,5]}' --output=json
```

## 5. Monitoring and Diagnostics

### 5.1 View Logs

```bash
vsm-daemon logs [OPTIONS]

OPTIONS:
  --follow, -f               Follow log output (tail -f style)
  --level LEVEL              Filter by log level: debug|info|warn|error
  --component COMPONENT      Filter by component: daemon|vsm|mcp|consciousness
  --since DURATION           Show logs since duration (e.g., 1h, 30m, 5s)
  --lines, -n NUMBER         Number of lines to show (default: 100)
  --search, -s PATTERN       Search for pattern in logs
  --json                     Output in JSON format

EXAMPLES:
  vsm-daemon logs --follow --level=error
  vsm-daemon logs --component=mcp --since=1h
  vsm-daemon logs --search="variety gap" --lines=50
  vsm-daemon logs --json | jq '.[] | select(.level=="error")'
```

### 5.2 System Metrics

```bash
vsm-daemon metrics [OPTIONS]

OPTIONS:
  --type TYPE                Metric type: variety|performance|health|all
  --timeframe DURATION       Time range: 1h|24h|7d|30d
  --granularity UNIT         Data granularity: minute|hour|day
  --component COMPONENT      Specific component metrics
  --export FORMAT            Export format: json|csv|prometheus
  --save PATH                Save metrics to file
  --live                     Live metrics (updates every 5s)

EXAMPLES:
  vsm-daemon metrics --type=performance --timeframe=24h
  vsm-daemon metrics --live --type=variety
  vsm-daemon metrics --export=csv --save=/tmp/metrics.csv
  vsm-daemon metrics --component=mcp_servers --granularity=minute
```

### 5.3 Health Check

```bash
vsm-daemon health check [OPTIONS]

OPTIONS:
  --component COMPONENT      Check specific component
  --detailed, -d             Detailed health information
  --fix                      Attempt to fix issues automatically
  --timeout SECONDS          Health check timeout (default: 10)

EXAMPLES:
  vsm-daemon health check --detailed
  vsm-daemon health check --component=mcp_servers --fix
  vsm-daemon health check --timeout=30
```

### 5.4 Run Diagnostics

```bash
vsm-daemon diagnostics run [OPTIONS]

OPTIONS:
  --full, -f                 Full system diagnostics
  --component COMPONENT      Diagnose specific component
  --performance              Performance diagnostics
  --security                 Security diagnostics
  --network                  Network connectivity diagnostics
  --save-report PATH         Save diagnostic report

EXAMPLES:
  vsm-daemon diagnostics run --full --save-report=/tmp/diagnostics.json
  vsm-daemon diagnostics run --component=mcp_servers --performance
  vsm-daemon diagnostics run --security --network
```

## 6. Configuration Management

### 6.1 Show Configuration

```bash
vsm-daemon config show [OPTIONS]

OPTIONS:
  --section SECTION          Show specific section: daemon|monitoring|mcp_servers|security
  --format FORMAT            Output format: json|yaml|toml
  --expand-env               Expand environment variables
  --validate                 Validate configuration

EXAMPLES:
  vsm-daemon config show --section=mcp_servers --format=yaml
  vsm-daemon config show --validate
  vsm-daemon config show --expand-env
```

### 6.2 Set Configuration

```bash
vsm-daemon config set KEY VALUE [OPTIONS]

OPTIONS:
  --type TYPE                Value type: string|number|boolean|json
  --temporary                Temporary setting (not persisted)
  --restart-required         Restart services after change

EXAMPLES:
  vsm-daemon config set daemon.log_level debug
  vsm-daemon config set monitoring.variety_threshold 0.8 --type=number
  vsm-daemon config set mcp_servers.auto_discovery true --type=boolean --restart-required
```

### 6.3 Reload Configuration

```bash
vsm-daemon config reload [OPTIONS]

OPTIONS:
  --file PATH                Reload from specific file
  --validate                 Validate before reloading
  --restart-services         Restart affected services
  --backup                   Backup current configuration

EXAMPLES:
  vsm-daemon config reload --validate --restart-services
  vsm-daemon config reload --file=/new/config.json --backup
```

## 7. Consciousness Interface

### 7.1 Consciousness Status

```bash
vsm-daemon consciousness status [OPTIONS]

OPTIONS:
  --detailed, -d             Detailed consciousness information
  --insights, -i             Show recent insights
  --patterns, -p             Show decision patterns
  --learning, -l             Show learning progress

EXAMPLES:
  vsm-daemon consciousness status --detailed --insights
  vsm-daemon consciousness status --patterns --learning
```

### 7.2 Trigger Reflection

```bash
vsm-daemon consciousness reflect [OPTIONS]

OPTIONS:
  --focus AREA               Focus area: variety|performance|decisions|self_model
  --depth LEVEL              Reflection depth: shallow|moderate|deep
  --context CONTEXT          Additional context (JSON format)
  --store-insights           Store generated insights
  --async                    Run asynchronously

EXAMPLES:
  vsm-daemon consciousness reflect --focus=variety --depth=deep
  vsm-daemon consciousness reflect --context='{"recent_changes":true}' --store-insights
```

### 7.3 Query Consciousness

```bash
vsm-daemon consciousness query QUESTION [OPTIONS]

OPTIONS:
  --context CONTEXT          Query context (JSON format)
  --detailed                 Detailed response
  --confidence               Include confidence scores

EXAMPLES:
  vsm-daemon consciousness query "What capabilities should we prioritize?"
  vsm-daemon consciousness query "How is system performance trending?" --detailed
  vsm-daemon consciousness query "What are our main limitations?" --confidence
```

## 8. Capability Management

### 8.1 List Capabilities

```bash
vsm-daemon capabilities list [OPTIONS]

OPTIONS:
  --source SOURCE            Filter by source: internal|mcp_server|llm_generated
  --status STATUS            Filter by status: active|inactive|deprecated
  --type TYPE                Filter by type: operational|analytical|transformational
  --sort FIELD               Sort by: name|usage|performance|age
  --usage-stats              Include usage statistics

EXAMPLES:
  vsm-daemon capabilities list --source=mcp_server --usage-stats
  vsm-daemon capabilities list --status=active --sort=usage
```

### 8.2 Capability Details

```bash
vsm-daemon capabilities info CAPABILITY_ID [OPTIONS]

OPTIONS:
  --metrics, -m              Include performance metrics
  --dependencies, -d         Show dependencies
  --usage-history            Show usage history

EXAMPLES:
  vsm-daemon capabilities info cap_document_gen_001 --metrics --dependencies
  vsm-daemon capabilities info cap_analysis_002 --usage-history
```

### 8.3 Remove Capability

```bash
vsm-daemon capabilities remove CAPABILITY_ID [OPTIONS]

OPTIONS:
  --force, -f                Force removal even if in use
  --cleanup                  Clean up associated resources
  --backup                   Backup capability before removal

EXAMPLES:
  vsm-daemon capabilities remove cap_old_processor_001 --cleanup
  vsm-daemon capabilities remove cap_deprecated_002 --force --backup
```

## 9. Utility Commands

### 9.1 Version Information

```bash
vsm-daemon version [OPTIONS]

OPTIONS:
  --detailed, -d             Show detailed version information
  --check-updates            Check for available updates
  --components               Show component versions

EXAMPLES:
  vsm-daemon version --detailed
  vsm-daemon version --check-updates --components
```

### 9.2 Backup System

```bash
vsm-daemon backup create [OPTIONS]

OPTIONS:
  --output PATH              Backup file path
  --include COMPONENTS       Components to backup (comma-separated)
  --compress                 Compress backup file
  --exclude-logs             Exclude log files

EXAMPLES:
  vsm-daemon backup create --output=/backups/vsm-backup-$(date +%Y%m%d).tar.gz --compress
  vsm-daemon backup create --include=config,capabilities --exclude-logs
```

### 9.3 Restore System

```bash
vsm-daemon backup restore BACKUP_PATH [OPTIONS]

OPTIONS:
  --components COMPONENTS    Restore specific components only
  --dry-run                  Simulate restore without execution
  --force                    Force restore without confirmation

EXAMPLES:
  vsm-daemon backup restore /backups/vsm-backup-20240101.tar.gz --dry-run
  vsm-daemon backup restore /backups/latest.tar.gz --components=config,mcp_servers
```

## 10. Advanced Operations

### 10.1 Performance Tuning

```bash
vsm-daemon tune [OPTIONS]

OPTIONS:
  --auto                     Automatic performance tuning
  --profile PROFILE          Apply tuning profile: balanced|performance|memory|latency
  --component COMPONENT      Tune specific component
  --dry-run                  Show tuning recommendations without applying

EXAMPLES:
  vsm-daemon tune --auto
  vsm-daemon tune --profile=performance --component=mcp_servers
  vsm-daemon tune --dry-run
```

### 10.2 Security Scan

```bash
vsm-daemon security scan [OPTIONS]

OPTIONS:
  --full, -f                 Full security scan
  --component COMPONENT      Scan specific component
  --fix                      Automatically fix issues
  --report PATH              Save security report

EXAMPLES:
  vsm-daemon security scan --full --report=/tmp/security-report.json
  vsm-daemon security scan --component=mcp_servers --fix
```

### 10.3 Export System State

```bash
vsm-daemon export [OPTIONS]

OPTIONS:
  --format FORMAT            Export format: json|yaml|xml
  --include COMPONENTS       Components to include
  --sanitize                 Remove sensitive information
  --output PATH              Output file path

EXAMPLES:
  vsm-daemon export --format=json --sanitize --output=/tmp/system-state.json
  vsm-daemon export --include=capabilities,mcp_servers --format=yaml
```

## 11. Scripting and Automation

### 11.1 Batch Commands

```bash
# Execute multiple commands from file
vsm-daemon batch --file=commands.txt

# Example commands.txt:
# systems status system1
# variety analyze --force
# mcp list --status=active
# consciousness reflect --focus=variety
```

### 11.2 JSON Output for Scripting

```bash
# All commands support --json flag for script-friendly output
vsm-daemon status --json | jq '.vsm_systems.system1.status'
vsm-daemon variety status --json | jq '.variety_ratio'
vsm-daemon mcp list --json | jq '.[] | select(.status=="active") | .name'
```

### 11.3 Exit Codes

```
0   - Success
1   - General error
2   - Configuration error
3   - Connection error
4   - Authentication error
5   - Resource not found
6   - Operation timeout
7   - Insufficient permissions
8   - Validation error
```

## 12. Configuration Files

### 12.1 CLI Configuration

```bash
# ~/.vsm-daemon/cli.config
{
  "daemon": {
    "host": "localhost",
    "port": 4001,
    "timeout": 30
  },
  "output": {
    "format": "table",
    "colors": true,
    "pager": "auto"
  },
  "authentication": {
    "token_file": "~/.vsm-daemon/token",
    "auto_refresh": true
  }
}
```

This comprehensive CLI interface provides complete control over the VSM-MCP autonomous daemon system, enabling efficient administration, monitoring, and operational management through both interactive and scripted usage.