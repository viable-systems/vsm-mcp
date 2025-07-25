# VSM-MCP Real Package Discovery and Installation

## Overview

The VSM-MCP system has been updated to discover and install real MCP (Model Context Protocol) servers from NPM instead of searching for generic terms. This ensures that when a variety gap is detected, the system actually acquires functional MCP servers that can extend its capabilities.

## Key Changes

### 1. Capability Mapping Module (`lib/vsm_mcp/core/capability_mapping.ex`)

A new module that maps generic capability names to real MCP server packages:

- **Generic capabilities** (e.g., "enhanced_processing") → Real packages (e.g., "@modelcontextprotocol/server-memory")
- **Direct capabilities** (e.g., "filesystem") → Exact packages (e.g., "@modelcontextprotocol/server-filesystem")
- **Fallback mapping** for unknown capabilities → Default useful servers

### 2. Updated MCP Discovery (`lib/vsm_mcp/core/mcp_discovery.ex`)

Enhanced to use real package names:

- **Direct NPM lookups** - Searches for exact package names first
- **Keyword fallback** - Falls back to keyword search if exact match fails
- **Package metadata extraction** - Extracts capabilities from package.json
- **Intelligent capability matching** - Maps discovered packages to required capabilities

### 3. Fixed Daemon Mode (`lib/vsm_mcp/daemon_mode.ex`)

Updated `analyze_capability_gap` to return real capability names:

- Now returns capabilities like "filesystem", "memory", "database"
- These map directly to real MCP servers
- No more generic terms like "enhanced_processing"

## Real MCP Servers

### Official MCP Servers (from @modelcontextprotocol)

- `@modelcontextprotocol/server-filesystem` - File system operations
- `@modelcontextprotocol/server-github` - GitHub integration
- `@modelcontextprotocol/server-git` - Git operations
- `@modelcontextprotocol/server-postgres` - PostgreSQL database
- `@modelcontextprotocol/server-sqlite` - SQLite database
- `@modelcontextprotocol/server-memory` - In-memory storage
- `@modelcontextprotocol/server-slack` - Slack integration
- `@modelcontextprotocol/server-puppeteer` - Web automation
- `@modelcontextprotocol/server-brave-search` - Web search
- `@modelcontextprotocol/server-fetch` - HTTP requests

### Community MCP Servers

- `mcp-server-kubernetes` - Kubernetes management
- `mcp-server-docker` - Docker operations
- `mcp-server-prometheus` - Metrics and monitoring
- `mcp-server-elasticsearch` - Search engine
- `mcp-server-redis` - Redis cache
- `mcp-server-aws` - AWS services
- And many more...

## How It Works

### 1. Variety Gap Detection

When the system detects a variety gap (environmental demands exceed operational capacity):

```elixir
# Daemon mode detects gap and analyzes needed capabilities
capabilities = analyze_capability_gap(gap_info)
# Returns: ["filesystem", "memory", "database"]
```

### 2. Capability Mapping

Generic capabilities are mapped to real packages:

```elixir
VsmMcp.Core.CapabilityMapping.map_capability_to_packages("filesystem")
# Returns: ["@modelcontextprotocol/server-filesystem"]

VsmMcp.Core.CapabilityMapping.map_capability_to_packages("enhanced_processing")
# Returns: ["@modelcontextprotocol/server-memory", 
#          "@modelcontextprotocol/server-filesystem",
#          "mcp-server-rust-python"]
```

### 3. Discovery Process

The discovery module searches NPM for real packages:

```elixir
# Direct package lookup
search_npm_exact("@modelcontextprotocol/server-memory")

# Fallback keyword search if needed
search_npm_keyword("memory storage")
```

### 4. Installation

Real NPM packages are installed:

```bash
cd /tmp/vsm_mcp_servers/@modelcontextprotocol/server-memory
npm init -y
npm install @modelcontextprotocol/server-memory
```

## Testing

### Test Scripts

1. **`test_mcp_mapping.exs`** - Tests capability mapping without full app startup
2. **`test_vsm_mcp_integration.exs`** - Full integration test of discovery and installation
3. **`test_direct_mcp_install.exs`** - Direct test of MCP server installation
4. **`inject_variety_gap.exs`** - Simulates a variety gap to trigger autonomous response

### Running Tests

```bash
# Test capability mapping
elixir test_mcp_mapping.exs

# Test full integration
elixir test_vsm_mcp_integration.exs

# Test with variety gap injection
elixir inject_variety_gap.exs
```

## Example Usage

### Manual Discovery

```elixir
# Discover servers for specific capabilities
{:ok, servers} = VsmMcp.Core.MCPDiscovery.discover_servers(["filesystem", "database"])

# Install a specific server
server = %{
  name: "@modelcontextprotocol/server-sqlite",
  source: :npm,
  install_command: "npm install @modelcontextprotocol/server-sqlite"
}
{:ok, installation} = VsmMcp.Core.MCPDiscovery.install_mcp_server(server)
```

### Autonomous Acquisition

```elixir
# Define required capabilities
capabilities = [
  %{type: "filesystem", search_terms: ["file", "fs"]},
  %{type: "memory", search_terms: ["cache", "storage"]}
]

# Discover and acquire automatically
{:ok, result} = VsmMcp.Core.MCPDiscovery.discover_and_acquire(capabilities)
```

## Benefits

1. **Real Functionality** - Installs actual working MCP servers, not mock implementations
2. **NPM Integration** - Leverages the NPM ecosystem for package management
3. **Intelligent Mapping** - Maps abstract capabilities to concrete implementations
4. **Autonomous Operation** - Automatically acquires capabilities when gaps are detected
5. **Extensible** - Easy to add new capability mappings as new MCP servers become available

## Future Enhancements

1. **GitHub Discovery** - Search GitHub for MCP servers not on NPM
2. **Official Registry** - Integration with official MCP registry when available
3. **Capability Testing** - Verify installed servers provide expected capabilities
4. **Version Management** - Handle version conflicts and updates
5. **Resource Optimization** - Only install minimal required dependencies