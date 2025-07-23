#!/usr/bin/env elixir

# Basic demo of VSM-MCP system functionality
# Run with: elixir examples/basic_demo.exs

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║          VSM-MCP: Basic Functionality Demo                ║
╚═══════════════════════════════════════════════════════════╝
"""

# Since we're running as a script, we'll demonstrate the concepts
# without starting the full OTP application

defmodule DemoVSM do
  @moduledoc """
  Simplified VSM demonstration showing core concepts.
  """
  
  def run do
    IO.puts "\n🏗️  Demonstrating VSM Systems:\n"
    
    # System 5 - Policy
    IO.puts "📋 System 5 (Policy): Setting organizational identity and purpose"
    policy = %{
      identity: "Autonomous Cybernetic Organization",
      purpose: "Maintain viability through dynamic adaptation",
      values: ["autonomy", "adaptation", "learning"]
    }
    IO.inspect(policy, label: "   Policy")
    
    # System 4 - Intelligence
    IO.puts "\n🔍 System 4 (Intelligence): Scanning environment"
    environment = %{
      opportunities: ["New MCP servers available", "AI integration possibilities"],
      threats: ["Increasing complexity", "Resource constraints"],
      trends: ["Automation growth", "Distributed systems"]
    }
    IO.inspect(environment, label: "   Environmental Scan")
    
    # System 3 - Control
    IO.puts "\n🎮 System 3 (Control): Monitoring operations"
    control = %{
      audits: ["Resource usage: 45%", "Performance: 87%", "Compliance: 100%"],
      optimizations: ["Load balancing improved", "Memory usage reduced"]
    }
    IO.inspect(control, label: "   Control Status")
    
    # System 2 - Coordination
    IO.puts "\n🤝 System 2 (Coordination): Managing conflicts"
    coordination = %{
      active_units: 5,
      conflicts_resolved: 12,
      resource_allocations: %{cpu: "balanced", memory: "optimized"}
    }
    IO.inspect(coordination, label: "   Coordination")
    
    # System 1 - Operations
    IO.puts "\n⚙️  System 1 (Operations): Running operational units"
    operations = %{
      units: ["DataProcessor", "APIHandler", "StorageManager"],
      tasks_completed: 1523,
      current_load: "moderate"
    }
    IO.inspect(operations, label: "   Operations")
    
    # Variety Calculation
    IO.puts "\n📊 Variety Analysis (Ashby's Law):\n"
    variety_demo()
    
    # MCP Discovery
    IO.puts "\n🔌 MCP Server Discovery:\n"
    mcp_demo()
    
    # Consciousness
    IO.puts "\n🧠 Consciousness Interface:\n"
    consciousness_demo()
    
    IO.puts "\n✅ Demo completed successfully!"
  end
  
  defp variety_demo do
    operational_variety = :math.log2(10 * 5 * 3 * 2 * 4)
    environmental_variety = :math.log2(15 * 8 * 5 * 3 * 6)
    gap = environmental_variety - operational_variety
    ratio = operational_variety / environmental_variety
    
    IO.puts "   Operational Variety: #{Float.round(operational_variety, 2)} bits"
    IO.puts "   Environmental Variety: #{Float.round(environmental_variety, 2)} bits"
    IO.puts "   Variety Gap: #{Float.round(gap, 2)} bits"
    IO.puts "   Requisite Ratio: #{Float.round(ratio * 100, 1)}%"
    
    if ratio < 0.7 do
      IO.puts "   ⚠️  Status: Insufficient variety - need more capabilities!"
    else
      IO.puts "   ✅ Status: Adequate variety"
    end
  end
  
  defp mcp_demo do
    servers = [
      %{name: "claude-mcp-memory", capability: "persistent-memory", source: "npm"},
      %{name: "mcp-server-sqlite", capability: "database", source: "npm"},
      %{name: "claude-mcp-filesystem", capability: "file-operations", source: "npm"}
    ]
    
    IO.puts "   Found #{length(servers)} MCP servers:"
    Enum.each(servers, fn server ->
      IO.puts "   - #{server.name}: #{server.capability} (#{server.source})"
    end)
  end
  
  defp consciousness_demo do
    reflection = %{
      self_awareness: "System understands its current limitations",
      meta_cognition: "Able to reason about reasoning processes",
      learning: "Extracting patterns from past decisions",
      adaptation: "Modifying strategies based on outcomes"
    }
    
    Enum.each(reflection, fn {aspect, status} ->
      IO.puts "   #{aspect}: #{status}"
    end)
  end
end

# Run the demo
DemoVSM.run()