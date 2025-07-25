defmodule VsmMcp.Resilience.CircuitBreakerTest do
  use ExUnit.Case, async: true
  
  alias VsmMcp.Resilience.CircuitBreaker
  
  setup do
    {:ok, breaker} = CircuitBreaker.start_link(
      name: :"test_breaker_#{:rand.uniform(1000)}",
      config: %{
        failure_threshold: 3,
        success_threshold: 2,
        timeout: 100  # Short timeout for tests
      }
    )
    
    {:ok, breaker: breaker}
  end
  
  describe "circuit breaker states" do
    test "starts in closed state", %{breaker: breaker} do
      assert CircuitBreaker.get_state(breaker) == :closed
    end
    
    test "remains closed on successful calls", %{breaker: breaker} do
      assert {:ok, :success} = CircuitBreaker.call(breaker, fn -> :success end)
      assert {:ok, :success} = CircuitBreaker.call(breaker, fn -> :success end)
      assert CircuitBreaker.get_state(breaker) == :closed
    end
    
    test "opens after reaching failure threshold", %{breaker: breaker} do
      # Fail 3 times
      for _ <- 1..3 do
        assert {:error, :boom} = CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      assert CircuitBreaker.get_state(breaker) == :open
    end
    
    test "rejects calls when open", %{breaker: breaker} do
      # Open the circuit
      for _ <- 1..3 do
        CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      # Should reject without executing function
      assert {:error, :circuit_open} = CircuitBreaker.call(breaker, fn -> :should_not_run end)
    end
    
    test "transitions to half-open after timeout", %{breaker: breaker} do
      # Open the circuit
      for _ <- 1..3 do
        CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      # Wait for timeout
      Process.sleep(150)
      
      # Next call should execute (half-open)
      assert {:ok, :success} = CircuitBreaker.call(breaker, fn -> :success end)
    end
    
    test "closes from half-open after success threshold", %{breaker: breaker} do
      # Open the circuit
      for _ <- 1..3 do
        CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      # Wait for timeout
      Process.sleep(150)
      
      # Succeed twice (success threshold)
      assert {:ok, :success} = CircuitBreaker.call(breaker, fn -> :success end)
      assert {:ok, :success} = CircuitBreaker.call(breaker, fn -> :success end)
      
      assert CircuitBreaker.get_state(breaker) == :closed
    end
    
    test "returns to open from half-open on failure", %{breaker: breaker} do
      # Open the circuit
      for _ <- 1..3 do
        CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      # Wait for timeout
      Process.sleep(150)
      
      # Fail in half-open state
      assert {:error, :boom} = CircuitBreaker.call(breaker, fn -> raise "boom" end)
      
      assert CircuitBreaker.get_state(breaker) == :open
    end
  end
  
  describe "error handling" do
    test "handles different error types", %{breaker: breaker} do
      # Exception
      assert {:error, {RuntimeError, "boom"}} = CircuitBreaker.call(breaker, fn -> raise "boom" end)
      
      # Throw
      assert {:error, {:throw, :boom}} = CircuitBreaker.call(breaker, fn -> throw :boom end)
      
      # Exit
      assert {:error, {:exit, :boom}} = CircuitBreaker.call(breaker, fn -> exit(:boom) end)
    end
    
    test "respects error_types config" do
      {:ok, breaker} = CircuitBreaker.start_link(
        name: :selective_breaker,
        config: %{
          failure_threshold: 2,
          error_types: [RuntimeError]
        }
      )
      
      # ArgumentError should not trip the breaker
      for _ <- 1..3 do
        CircuitBreaker.call(breaker, fn -> raise ArgumentError, "boom" end)
      end
      assert CircuitBreaker.get_state(breaker) == :closed
      
      # RuntimeError should trip the breaker
      for _ <- 1..2 do
        CircuitBreaker.call(breaker, fn -> raise RuntimeError, "boom" end)
      end
      assert CircuitBreaker.get_state(breaker) == :open
    end
  end
  
  describe "statistics" do
    test "tracks call statistics", %{breaker: breaker} do
      # Make some calls
      CircuitBreaker.call(breaker, fn -> :success end)
      CircuitBreaker.call(breaker, fn -> raise "boom" end)
      CircuitBreaker.call(breaker, fn -> :success end)
      
      stats = CircuitBreaker.get_stats(breaker)
      
      assert stats.total_calls == 3
      assert stats.successful_calls == 2
      assert stats.failed_calls == 1
      assert stats.current_state == :closed
    end
    
    test "tracks state transitions", %{breaker: breaker} do
      # Open the circuit
      for _ <- 1..3 do
        CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      stats = CircuitBreaker.get_stats(breaker)
      
      assert length(stats.state_transitions) > 0
      assert hd(stats.state_transitions).to == :open
      assert hd(stats.state_transitions).reason == :threshold_exceeded
    end
  end
  
  describe "manual control" do
    test "can manually reset circuit", %{breaker: breaker} do
      # Open the circuit
      for _ <- 1..3 do
        CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      assert CircuitBreaker.get_state(breaker) == :open
      
      # Manual reset
      assert :ok = CircuitBreaker.reset(breaker)
      assert CircuitBreaker.get_state(breaker) == :closed
    end
  end
  
  describe "telemetry" do
    test "emits telemetry events", %{breaker: breaker} do
      self_pid = self()
      
      # Attach handler
      :telemetry.attach(
        "test-handler",
        [:vsm_mcp, :circuit_breaker, :state_change],
        fn _event, _measurements, metadata, _config ->
          send(self_pid, {:telemetry, metadata})
        end,
        nil
      )
      
      # Trigger state change
      for _ <- 1..3 do
        CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      assert_receive {:telemetry, %{state: :open}}
      
      :telemetry.detach("test-handler")
    end
  end
end