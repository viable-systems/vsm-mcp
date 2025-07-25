defmodule VsmMcp.Resilience.RetryTest do
  use ExUnit.Case, async: true
  
  alias VsmMcp.Resilience.Retry
  
  describe "successful execution" do
    test "returns result on first success" do
      assert {:ok, :success} = Retry.with_retry(fn -> :success end)
    end
    
    test "does not retry on immediate success" do
      counter = :counters.new(1, [])
      
      result = Retry.with_retry(fn ->
        :counters.add(counter, 1, 1)
        :success
      end)
      
      assert {:ok, :success} = result
      assert :counters.get(counter, 1) == 1
    end
  end
  
  describe "retry behavior" do
    test "retries on failure up to max_retries" do
      counter = :counters.new(1, [])
      
      result = Retry.with_retry(
        fn ->
          count = :counters.add(counter, 1, 1)
          if count < 3 do
            raise "boom"
          else
            :success
          end
        end,
        max_retries: 3,
        initial_delay: 10
      )
      
      assert {:ok, :success} = result
      assert :counters.get(counter, 1) == 3
    end
    
    test "fails after max_retries exceeded" do
      counter = :counters.new(1, [])
      
      result = Retry.with_retry(
        fn ->
          :counters.add(counter, 1, 1)
          raise "always fails"
        end,
        max_retries: 2,
        initial_delay: 10
      )
      
      assert {:error, {RuntimeError, "always fails"}} = result
      assert :counters.get(counter, 1) == 3  # initial + 2 retries
    end
  end
  
  describe "exponential backoff" do
    test "increases delay exponentially" do
      delays = []
      
      Retry.with_retry(
        fn -> raise "boom" end,
        max_retries: 3,
        initial_delay: 100,
        backoff_factor: 2,
        jitter: false,
        on_retry: fn _attempt, _error, delay ->
          send(self(), {:delay, delay})
        end
      )
      
      assert_receive {:delay, 100}
      assert_receive {:delay, 200}
      assert_receive {:delay, 400}
    end
    
    test "respects max_delay" do
      Retry.with_retry(
        fn -> raise "boom" end,
        max_retries: 5,
        initial_delay: 100,
        max_delay: 300,
        backoff_factor: 2,
        jitter: false,
        on_retry: fn _attempt, _error, delay ->
          assert delay <= 300
        end
      )
    end
    
    test "adds jitter when enabled" do
      delays = for _ <- 1..5 do
        Retry.with_retry(
          fn -> raise "boom" end,
          max_retries: 1,
          initial_delay: 1000,
          jitter: true,
          on_retry: fn _attempt, _error, delay ->
            send(self(), {:delay, delay})
          end
        )
        
        assert_receive {:delay, delay}
        delay
      end
      
      # With jitter, delays should vary
      assert length(Enum.uniq(delays)) > 1
      
      # But stay within expected range (±25%)
      Enum.each(delays, fn delay ->
        assert delay >= 750
        assert delay <= 1250
      end)
    end
  end
  
  describe "selective retry" do
    test "only retries specified error types" do
      counter = :counters.new(1, [])
      
      result = Retry.with_retry(
        fn ->
          :counters.add(counter, 1, 1)
          raise ArgumentError, "not retryable"
        end,
        max_retries: 3,
        retry_on: [RuntimeError],
        initial_delay: 10
      )
      
      assert {:error, {ArgumentError, "not retryable"}} = result
      assert :counters.get(counter, 1) == 1  # No retries
    end
    
    test "retries matching error types" do
      counter = :counters.new(1, [])
      
      result = Retry.with_retry(
        fn ->
          count = :counters.add(counter, 1, 1)
          if count < 3 do
            raise RuntimeError, "retryable"
          else
            :success
          end
        end,
        max_retries: 3,
        retry_on: [RuntimeError],
        initial_delay: 10
      )
      
      assert {:ok, :success} = result
      assert :counters.get(counter, 1) == 3
    end
  end
  
  describe "callbacks" do
    test "calls on_retry callback" do
      retry_count = :counters.new(1, [])
      
      Retry.with_retry(
        fn -> raise "boom" end,
        max_retries: 2,
        initial_delay: 10,
        on_retry: fn attempt, error, delay ->
          :counters.add(retry_count, 1, 1)
          send(self(), {:retry, attempt, error, delay})
        end
      )
      
      assert_receive {:retry, 1, {RuntimeError, "boom"}, _}
      assert_receive {:retry, 2, {RuntimeError, "boom"}, _}
      assert :counters.get(retry_count, 1) == 2
    end
    
    test "calls on_failure callback" do
      Retry.with_retry(
        fn -> raise "permanent failure" end,
        max_retries: 1,
        initial_delay: 10,
        on_failure: fn error, attempts ->
          send(self(), {:failed, error, attempts})
        end
      )
      
      assert_receive {:failed, {RuntimeError, "permanent failure"}, 2}
    end
  end
  
  describe "dead letter queue integration" do
    test "sends to DLQ on permanent failure" do
      # Mock DLQ
      test_pid = self()
      dlq = spawn(fn ->
        receive do
          {:"$gen_cast", {:add, item}} ->
            send(test_pid, {:dlq_item, item})
        end
      end)
      
      fun = fn -> raise "permanent" end
      
      Retry.with_retry_and_dlq(fun, dlq, max_retries: 1, initial_delay: 10)
      
      assert_receive {:dlq_item, {^fun, {RuntimeError, "permanent"}, 2}}
    end
  end
  
  describe "delay calculation" do
    test "calculates exponential backoff correctly" do
      config = %{
        initial_delay: 100,
        max_delay: 10_000,
        backoff_factor: 2,
        jitter: false
      }
      
      assert Retry.calculate_delay(0, config) == 100
      assert Retry.calculate_delay(1, config) == 200
      assert Retry.calculate_delay(2, config) == 400
      assert Retry.calculate_delay(3, config) == 800
      
      # Should cap at max_delay
      assert Retry.calculate_delay(10, config) == 10_000
    end
  end
end