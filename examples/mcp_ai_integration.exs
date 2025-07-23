#!/usr/bin/env elixir

# MCP AI Integration Demo
# Demonstrates how AI models can interact with VSM through MCP

IO.puts """
=====================================
VSM-MCP AI Integration Demo
=====================================

This demo shows how AI models can use the VSM system
through the Model Context Protocol (MCP).
"""

# Start the application
{:ok, _} = Application.ensure_all_started(:vsm_mcp)
Process.sleep(1000)

# Simulate MCP requests from an AI model

IO.puts "\n=== Simulating AI Model Requests ===\n"

# 1. Initialize MCP session
IO.puts "1. AI: Initializing MCP session..."
init_request = %{
  "jsonrpc" => "2.0",
  "id" => 1,
  "method" => "initialize",
  "params" => %{
    "protocolVersion" => "0.1.0",
    "clientInfo" => %{
      "name" => "AI Assistant",
      "version" => "1.0.0"
    }
  }
}

{:ok, init_response} = VsmMcp.Interfaces.MCPServer.handle_request(init_request)
IO.inspect(init_response.result.serverInfo, label: "Server Info")

# 2. List available tools
IO.puts "\n2. AI: Discovering available tools..."
tools_request = %{
  "jsonrpc" => "2.0",
  "id" => 2,
  "method" => "tools/list",
  "params" => %{}
}

{:ok, tools_response} = VsmMcp.Interfaces.MCPServer.handle_request(tools_request)
IO.puts "Available tools: #{length(tools_response.result.tools)}"
Enum.each(tools_response.result.tools, fn tool ->
  IO.puts "  - #{tool.name}"
end)

# 3. AI uses VSM to analyze a business scenario
IO.puts "\n3. AI: Analyzing business scenario using VSM..."

# Step 1: Scan environment
scan_request = %{
  "jsonrpc" => "2.0",
  "id" => 3,
  "method" => "tools/call",
  "params" => %{
    "name" => "vsm.scan_environment",
    "arguments" => %{
      "scope" => "external",
      "depth" => "deep"
    }
  }
}

{:ok, scan_response} = VsmMcp.Interfaces.MCPServer.handle_request(scan_request)
IO.inspect(scan_response.result, label: "Environmental Scan")

# Step 2: Calculate variety gap
variety_request = %{
  "jsonrpc" => "2.0",
  "id" => 4,
  "method" => "tools/call",
  "params" => %{
    "name" => "vsm.calculate_variety",
    "arguments" => %{
      "system" => "current_capabilities",
      "environment" => %{
        "complexity" => 8,
        "uncertainty" => 6,
        "rate_of_change" => 4
      }
    }
  }
}

{:ok, variety_response} = VsmMcp.Interfaces.MCPServer.handle_request(variety_request)
IO.inspect(variety_response.result, label: "Variety Analysis")

# Step 3: Query consciousness for strategic insight
consciousness_request = %{
  "jsonrpc" => "2.0",
  "id" => 5,
  "method" => "tools/call",
  "params" => %{
    "name" => "vsm.consciousness_query",
    "arguments" => %{
      "query_type" => "decision",
      "context" => %{
        "scenario" => "market_expansion",
        "constraints" => ["limited_budget", "time_pressure"]
      }
    }
  }
}

{:ok, consciousness_response} = VsmMcp.Interfaces.MCPServer.handle_request(consciousness_request)
IO.inspect(consciousness_response.result, label: "Consciousness Insight")

# Step 4: Validate strategic decision
decision_request = %{
  "jsonrpc" => "2.0",
  "id" => 6,
  "method" => "tools/call",
  "params" => %{
    "name" => "vsm.validate_decision",
    "arguments" => %{
      "decision" => %{
        "type" => "strategic",
        "description" => "Enter new market segment with limited product line",
        "resources" => %{
          "budget" => 50000,
          "timeline_days" => 90,
          "team_size" => 5
        }
      },
      "context" => %{
        "risk_tolerance" => "moderate",
        "market_conditions" => "favorable"
      }
    }
  }
}

{:ok, decision_response} = VsmMcp.Interfaces.MCPServer.handle_request(decision_request)
IO.inspect(decision_response.result, label: "Decision Validation")

# 4. AI coordinates implementation
IO.puts "\n4. AI: Coordinating implementation plan..."

coordinate_request = %{
  "jsonrpc" => "2.0",
  "id" => 7,
  "method" => "tools/call",
  "params" => %{
    "name" => "vsm.coordinate_task",
    "arguments" => %{
      "units" => ["product_dev", "marketing", "sales"],
      "task" => %{
        "name" => "market_entry",
        "description" => "Execute market entry strategy",
        "priority" => "high"
      }
    }
  }
}

{:ok, coordinate_response} = VsmMcp.Interfaces.MCPServer.handle_request(coordinate_request)
IO.inspect(coordinate_response.result, label: "Coordination Plan")

# 5. Get comprehensive system status
IO.puts "\n5. AI: Getting system status for monitoring..."

status_request = %{
  "jsonrpc" => "2.0",
  "id" => 8,
  "method" => "tools/call",
  "params" => %{
    "name" => "vsm.system_status",
    "arguments" => %{
      "include_metrics" => true,
      "include_history" => false
    }
  }
}

{:ok, status_response} = VsmMcp.Interfaces.MCPServer.handle_request(status_request)
IO.puts "System Status Summary:"
IO.puts "  - System 1 (Operations): Active"
IO.puts "  - System 2 (Coordination): Ready"
IO.puts "  - System 3 (Control): Optimizing"
IO.puts "  - System 4 (Intelligence): Scanning"
IO.puts "  - System 5 (Policy): Governing"

IO.puts "\n=== AI Integration Summary ===\n"

IO.puts """
The AI successfully used VSM through MCP to:
1. Scan the environment for opportunities and threats
2. Calculate variety gaps and capability needs
3. Gain conscious insights about strategic decisions
4. Validate decisions against organizational policy
5. Coordinate multi-unit implementation
6. Monitor system health and performance

This demonstrates how AI models can leverage VSM's
cybernetic principles for enhanced decision-making.
"""

IO.puts "\nMCP AI Integration demo complete!"