defmodule VsmMcp.Systems.System1Test do
  use ExUnit.Case
  alias VsmMcp.Systems.System1

  setup do
    {:ok, _pid} = System1.start_link([])
    :ok
  end

  describe "operational execution" do
    test "executes operations successfully" do
      operation = %{
        type: :process_data,
        data: "test data",
        params: %{}
      }
      
      assert {:ok, result} = System1.execute_operation(operation)
      assert result.operation == operation
      assert result.duration >= 0
    end

    test "tracks operation metrics" do
      # Execute multiple operations
      for i <- 1..3 do
        operation = %{type: :process, id: i}
        System1.execute_operation(operation)
      end
      
      status = System1.get_status()
      assert status.metrics.operations_count >= 3
      assert status.metrics.success_rate > 0
    end

    test "handles different operation types" do
      operations = [
        %{type: :read, resource: "file.txt"},
        %{type: :write, data: "content"},
        %{type: :compute, expression: "2 + 2"}
      ]
      
      for op <- operations do
        assert {:ok, _result} = System1.execute_operation(op)
      end
    end
  end

  describe "capability management" do
    test "adds new capabilities" do
      initial_status = System1.get_status()
      initial_count = length(initial_status.capabilities)
      
      System1.add_capability(%{
        name: "new_capability",
        type: :processing,
        handler: fn data -> {:ok, data} end
      })
      
      # Give it time to process the cast
      Process.sleep(50)
      
      final_status = System1.get_status()
      assert length(final_status.capabilities) > initial_count
    end

    test "reports current capabilities" do
      status = System1.get_status()
      
      assert Map.has_key?(status, :capabilities)
      assert Map.has_key?(status, :metrics)
      assert is_list(status.capabilities)
    end
  end

  describe "operational variety" do
    test "calculates variety based on capabilities and operations" do
      # Add some capabilities
      capabilities = [
        %{name: "read", operations: 5},
        %{name: "write", operations: 3},
        %{name: "transform", operations: 8}
      ]
      
      for cap <- capabilities do
        System1.add_capability(cap)
      end
      
      Process.sleep(50)
      status = System1.get_status()
      
      # Variety should be reflected in status
      assert status.operational_variety > 0
    end
  end

  describe "system status" do
    test "provides comprehensive status information" do
      status = System1.get_status()
      
      assert Map.has_key?(status, :operations)
      assert Map.has_key?(status, :capabilities)
      assert Map.has_key?(status, :metrics)
      assert Map.has_key?(status, :operational_variety)
      
      assert status.metrics.operations_count >= 0
      assert status.metrics.success_rate >= 0 and status.metrics.success_rate <= 1
    end

    test "tracks operation history" do
      # Execute some operations
      operations = [
        %{type: :test1, timestamp: System.system_time()},
        %{type: :test2, timestamp: System.system_time()},
        %{type: :test3, timestamp: System.system_time()}
      ]
      
      for op <- operations do
        System1.execute_operation(op)
      end
      
      status = System1.get_status()
      assert length(status.operations) >= 3
    end
  end
end