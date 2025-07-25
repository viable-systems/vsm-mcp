#!/usr/bin/env elixir
# Simple test of MCP capability mapping without full app startup

# Load the capability mapping module directly
Code.require_file("lib/vsm_mcp/core/capability_mapping.ex")

IO.puts("🚀 Testing MCP Capability Mapping\n")

# Test mapping generic capabilities to real packages
test_cases = [
  {"enhanced_processing", "Generic term for better processing"},
  {"pattern_recognition", "Generic term for pattern analysis"},
  {"data_transformation", "Generic term for data manipulation"},
  {"filesystem", "Direct filesystem operations"},
  {"database", "Database operations"},
  {"memory", "Memory/caching operations"},
  {"parallel_processing", "Concurrent operations"},
  {"containerization", "Container management"}
]

IO.puts("📋 Capability Mappings:")
IO.puts("=" |> String.duplicate(60))

Enum.each(test_cases, fn {capability, description} ->
  packages = VsmMcp.Core.CapabilityMapping.map_capability_to_packages(capability)
  
  IO.puts("\n#{capability}")
  IO.puts("  Description: #{description}")
  IO.puts("  Maps to #{length(packages)} packages:")
  
  Enum.each(packages, fn package ->
    IO.puts("    - #{package}")
  end)
end)

IO.puts("\n\n📦 All Known MCP Packages:")
IO.puts("=" |> String.duplicate(60))

all_packages = VsmMcp.Core.CapabilityMapping.all_known_packages()
IO.puts("Total: #{length(all_packages)} packages\n")

# Group by type
official = Enum.filter(all_packages, &String.starts_with?(&1, "@modelcontextprotocol/"))
community = all_packages -- official

IO.puts("Official MCP Servers (#{length(official)}):")
Enum.each(official, fn pkg ->
  IO.puts("  - #{pkg}")
end)

IO.puts("\nCommunity MCP Servers (#{length(community)}):")
Enum.each(community, fn pkg ->
  IO.puts("  - #{pkg}")
end)

IO.puts("\n✅ Test complete!")