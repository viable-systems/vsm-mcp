defmodule VsmMcp.Systems.System3Test do
  use ExUnit.Case
  alias VsmMcp.Systems.System3

  setup do
    {:ok, pid} = System3.start_link([])
    %{pid: pid}
  end

  describe "control and audit" do
    test "handles audit_unit", %{pid: pid} do
      audit_data = %{
        operations: 100,
        errors: 2,
        efficiency: 0.95
      }
      
      assert {:ok, :pass} = System3.audit_unit(pid, "unit_1", audit_data)
      status = System3.get_status(pid)
      
      assert status.audit_results["unit_1"] == :pass
      assert status.audits_performed == 1
    end

    test "fails audit when efficiency is low", %{pid: pid} do
      audit_data = %{
        operations: 100,
        errors: 50,
        efficiency: 0.45
      }
      
      assert {:ok, :fail} = System3.audit_unit(pid, "unit_1", audit_data)
      status = System3.get_status(pid)
      
      assert status.audit_results["unit_1"] == :fail
    end

    test "handles optimize_unit", %{pid: pid} do
      # First fail an audit
      System3.audit_unit(pid, "unit_1", %{operations: 100, errors: 50, efficiency: 0.45})
      
      optimization = %{
        strategy: :reduce_errors,
        parameters: %{error_threshold: 0.02}
      }
      
      assert {:ok, :optimized} = System3.optimize_unit(pid, "unit_1", optimization)
      status = System3.get_status(pid)
      
      assert status.optimizations["unit_1"] == optimization
      assert status.optimizations_applied == 1
    end

    test "tracks control effectiveness", %{pid: pid} do
      # Perform multiple audits
      System3.audit_unit(pid, "unit_1", %{operations: 100, errors: 2, efficiency: 0.95})
      System3.audit_unit(pid, "unit_2", %{operations: 200, errors: 5, efficiency: 0.92})
      System3.audit_unit(pid, "unit_3", %{operations: 150, errors: 50, efficiency: 0.45})
      
      status = System3.get_status(pid)
      assert status.audits_performed == 3
      assert round(status.control_effectiveness) == 67 # 2 pass, 1 fail
    end

    test "handles set_policy", %{pid: pid} do
      policy = %{
        audit_frequency: :daily,
        optimization_threshold: 0.8,
        enforcement: :strict
      }
      
      assert :ok = System3.set_policy(pid, policy)
      status = System3.get_status(pid)
      
      assert status.current_policy == policy
    end
  end

  describe "system-wide control" do
    test "calculates overall control variety", %{pid: pid} do
      # Perform various control actions
      System3.audit_unit(pid, "unit_1", %{operations: 100, errors: 2, efficiency: 0.95})
      System3.optimize_unit(pid, "unit_2", %{strategy: :improve_throughput})
      System3.set_policy(pid, %{audit_frequency: :hourly})
      
      status = System3.get_status(pid)
      assert status.control_variety > 0
      assert is_float(status.control_variety)
    end

    test "tracks failed units for intervention", %{pid: pid} do
      # Create failing units
      System3.audit_unit(pid, "unit_1", %{operations: 100, errors: 60, efficiency: 0.4})
      System3.audit_unit(pid, "unit_2", %{operations: 100, errors: 70, efficiency: 0.3})
      
      status = System3.get_status(pid)
      failed_units = Enum.filter(status.audit_results, fn {_k, v} -> v == :fail end)
      assert length(failed_units) == 2
    end
  end

  describe "telemetry events" do
    test "emits telemetry on audit", %{pid: pid} do
      :telemetry.attach(
        "test-audit",
        [:vsm_mcp, :system3, :audit],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      System3.audit_unit(pid, "unit_1", %{operations: 100, errors: 2, efficiency: 0.95})

      assert_receive {:telemetry, [:vsm_mcp, :system3, :audit], measurements, metadata}
      assert measurements.efficiency == 0.95
      assert metadata.unit == "unit_1"
      assert metadata.result == :pass

      :telemetry.detach("test-audit")
    end
  end
end