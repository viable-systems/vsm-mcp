#!/usr/bin/env elixir

# Test script to verify basic Elixir compilation and concepts

IO.puts "Testing VSM-MCP concepts..."

# Test variety calculation
defmodule VarietyTest do
  def calculate do
    operational = :math.log2(100)
    environmental = :math.log2(1000)
    ratio = operational / environmental
    
    %{
      operational: operational,
      environmental: environmental,
      ratio: ratio,
      gap_status: if(ratio < 0.7, do: :insufficient, else: :adequate)
    }
  end
end

# Test basic GenServer
defmodule TestServer do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    {:ok, %{started: true, opts: opts}}
  end
  
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end
  
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end

# Run tests
IO.puts "\n1. Variety Calculation:"
result = VarietyTest.calculate()
IO.inspect(result)

IO.puts "\n2. GenServer Test:"
{:ok, pid} = TestServer.start_link(test: true)
state = TestServer.get_state()
IO.inspect(state)

IO.puts "\n3. MCP Message Format:"
mcp_message = %{
  jsonrpc: "2.0",
  method: "initialize",
  params: %{
    protocolVersion: "1.0",
    clientInfo: %{name: "VSM-MCP", version: "0.1.0"}
  },
  id: 1
}
IO.inspect(mcp_message)

IO.puts "\n✅ All basic tests passed!"