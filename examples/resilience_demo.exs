#!/usr/bin/env elixir

# Resilience Demo - Demonstrates VSM-MCP error handling capabilities
#
# This example shows:
# 1. Circuit breakers preventing cascading failures
# 2. Retry logic with exponential backoff
# 3. Dead letter queue for failed operations
# 4. Connection pooling and rate limiting
# 5. Comprehensive telemetry and monitoring

Mix.install([
  {:vsm_mcp, path: "."},
  {:httpoison, "~> 2.0"},
  {:jason, "~> 1.4"}
])

defmodule ResilienceDemo do
  @moduledoc """
  Demonstrates the resilience features of VSM-MCP.
  """
  
  def run do
    IO.puts("""
    ╔══════════════════════════════════════════════════╗
    ║        VSM-MCP Resilience Demo                   ║
    ║                                                  ║
    ║  Demonstrating error handling and resilience     ║
    ╚══════════════════════════════════════════════════╝
    """)
    
    # Start the application
    {:ok, _} = Application.ensure_all_started(:vsm_mcp)
    
    # Demo 1: Circuit Breaker
    demo_circuit_breaker()
    
    # Demo 2: Retry Logic
    demo_retry_logic()
    
    # Demo 3: Dead Letter Queue
    demo_dead_letter_queue()
    
    # Demo 4: Full Integration
    demo_full_integration()
    
    IO.puts("\n✅ Resilience demo completed!")
  end
  
  defp demo_circuit_breaker do
    IO.puts("\n📊 Demo 1: Circuit Breaker")
    IO.puts("─" <> String.duplicate("─", 49))
    
    # Create a circuit breaker
    {:ok, breaker} = VsmMcp.Resilience.CircuitBreaker.start_link(
      name: :demo_breaker,
      config: %{
        failure_threshold: 3,
        success_threshold: 2,
        timeout: 2000
      }
    )
    
    # Simulate service calls
    IO.puts("Making successful calls...")
    for i <- 1..2 do
      result = VsmMcp.Resilience.CircuitBreaker.call(breaker, fn ->
        IO.puts("  Call #{i}: Success ✓")
        {:ok, "Response #{i}"}
      end)
      IO.inspect(result, label: "  Result")
    end
    
    IO.puts("\nSimulating failures...")
    for i <- 1..3 do
      result = VsmMcp.Resilience.CircuitBreaker.call(breaker, fn ->
        IO.puts("  Call #{i}: Failing ✗")
        raise "Service unavailable"
      end)
      IO.puts("  Result: #{inspect(result)}")
    end
    
    # Circuit should now be open
    state = VsmMcp.Resilience.CircuitBreaker.get_state(breaker)
    IO.puts("\nCircuit state: #{state} 🔴")
    
    # Try to call while open
    result = VsmMcp.Resilience.CircuitBreaker.call(breaker, fn ->
      IO.puts("This should not execute")
      :ok
    end)
    IO.puts("Call while open: #{inspect(result)}")
    
    # Wait for timeout and try half-open
    IO.puts("\nWaiting for timeout...")
    Process.sleep(2500)
    
    result = VsmMcp.Resilience.CircuitBreaker.call(breaker, fn ->
      IO.puts("Half-open test: Success ✓")
      :ok
    end)
    IO.puts("Half-open result: #{inspect(result)}")
    
    # Get statistics
    stats = VsmMcp.Resilience.CircuitBreaker.get_stats(breaker)
    IO.puts("\nCircuit breaker statistics:")
    IO.inspect(stats, pretty: true)
  end
  
  defp demo_retry_logic do
    IO.puts("\n📊 Demo 2: Retry Logic with Exponential Backoff")
    IO.puts("─" <> String.duplicate("─", 49))
    
    attempt_counter = :counters.new(1, [])
    
    IO.puts("Simulating transient failures...")
    result = VsmMcp.Resilience.Retry.with_retry(
      fn ->
        attempt = :counters.add(attempt_counter, 1, 1)
        IO.puts("  Attempt #{attempt}")
        
        if attempt < 3 do
          IO.puts("    ✗ Transient failure")
          raise "Temporary error"
        else
          IO.puts("    ✓ Success!")
          {:ok, "Finally succeeded"}
        end
      end,
      max_retries: 5,
      initial_delay: 500,
      backoff_factor: 2,
      on_retry: fn attempt, _error, delay ->
        IO.puts("    ↻ Retrying after #{delay}ms (attempt #{attempt})")
      end
    )
    
    IO.puts("\nFinal result: #{inspect(result)}")
    
    # Demo with permanent failure
    IO.puts("\nSimulating permanent failure...")
    result = VsmMcp.Resilience.Retry.with_retry(
      fn ->
        IO.puts("  ✗ Permanent failure")
        raise "This always fails"
      end,
      max_retries: 2,
      initial_delay: 100,
      on_failure: fn error, attempts ->
        IO.puts("\n⚠️  Permanent failure after #{attempts} attempts: #{inspect(error)}")
      end
    )
    
    IO.puts("Result: #{inspect(result)}")
  end
  
  defp demo_dead_letter_queue do
    IO.puts("\n📊 Demo 3: Dead Letter Queue")
    IO.puts("─" <> String.duplicate("─", 49))
    
    # Start DLQ
    {:ok, _dlq} = VsmMcp.Resilience.DeadLetterQueue.start_link(name: :demo_dlq)
    
    # Add some failed items
    IO.puts("Adding failed operations to DLQ...")
    
    VsmMcp.Resilience.DeadLetterQueue.add(:demo_dlq, {
      fn -> IO.puts("Operation 1") end,
      {:error, :timeout},
      3
    })
    
    VsmMcp.Resilience.DeadLetterQueue.add(:demo_dlq, {
      fn -> IO.puts("Operation 2") end,
      {:error, :connection_refused},
      5
    })
    
    VsmMcp.Resilience.DeadLetterQueue.add(:demo_dlq, {
      fn -> {:ok, "Operation 3 can succeed"} end,
      {:error, :temporary_failure},
      2
    })
    
    # List items
    items = VsmMcp.Resilience.DeadLetterQueue.list_all(:demo_dlq)
    IO.puts("\nDLQ contents (#{length(items)} items):")
    Enum.each(items, fn item ->
      IO.puts("  - ID: #{item.id}")
      IO.puts("    Error: #{inspect(item.error_type)}")
      IO.puts("    Timestamp: #{item.timestamp}")
      IO.puts("    Retries: #{item.retries}")
    end)
    
    # Get statistics
    stats = VsmMcp.Resilience.DeadLetterQueue.stats(:demo_dlq)
    IO.puts("\nDLQ Statistics:")
    IO.inspect(stats, pretty: true)
    
    # Retry an item
    if item = List.first(items) do
      IO.puts("\nRetrying item #{item.id}...")
      result = VsmMcp.Resilience.DeadLetterQueue.retry_item(:demo_dlq, item.id)
      IO.puts("Retry result: #{inspect(result)}")
    end
  end
  
  defp demo_full_integration do
    IO.puts("\n📊 Demo 4: Full Integration - LLM with Resilience")
    IO.puts("─" <> String.duplicate("─", 49))
    
    # Start resilience supervisor
    {:ok, _} = VsmMcp.Resilience.Supervisor.start_link([])
    
    # Configure mock LLM service
    config = [
      provider: :mock,
      config: %{
        api_key: "mock-key",
        circuit_breaker_threshold: 3,
        enable_dlq: true
      }
    ]
    
    {:ok, _} = VsmMcp.LLM.Integration.start_link(config)
    
    # Simulate various scenarios
    scenarios = [
      {"Successful request", fn -> {:ok, "AI response"} end},
      {"Transient failure (will retry)", fn -> 
        if :rand.uniform() > 0.7, do: {:ok, "Success after retry"}, else: raise "Temporary error"
      end},
      {"Rate limited", fn -> {:error, {:rate_limited, 60}} end},
      {"Server error", fn -> {:error, {:server_error, 500, "Internal server error"}} end}
    ]
    
    Enum.each(scenarios, fn {name, mock_fn} ->
      IO.puts("\n▶ Scenario: #{name}")
      
      # Mock the API call
      :meck.new(VsmMcp.LLM.API, [:passthrough])
      :meck.expect(VsmMcp.LLM.API, :request, fn _, _, _, _ -> mock_fn.() end)
      
      result = VsmMcp.LLM.Integration.process_query("Test query")
      IO.puts("  Result: #{inspect(result)}")
      
      :meck.unload(VsmMcp.LLM.API)
    end)
    
    # Show health status
    IO.puts("\n📊 System Health Check:")
    health = VsmMcp.LLM.API.health_check(:mock)
    IO.inspect(health, pretty: true)
  end
end

# Run the demo
ResilienceDemo.run()