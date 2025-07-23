defmodule VsmMcp.Systems.System2Test do
  use ExUnit.Case
  alias VsmMcp.Systems.System2

  setup do
    {:ok, pid} = System2.start_link([])
    %{pid: pid}
  end

  describe "coordination and conflict resolution" do
    test "handles register_conflict", %{pid: pid} do
      conflict = %{
        type: :resource_contention,
        units: ["unit_1", "unit_2"],
        resource: "database_connection"
      }
      
      assert :ok = System2.register_conflict(pid, conflict)
      status = System2.get_status(pid)
      
      assert length(status.active_conflicts) == 1
      assert hd(status.active_conflicts).type == :resource_contention
    end

    test "handles resolve_conflict", %{pid: pid} do
      conflict = %{
        type: :resource_contention,
        units: ["unit_1", "unit_2"],
        resource: "database_connection"
      }
      
      System2.register_conflict(pid, conflict)
      assert {:ok, :resolved} = System2.resolve_conflict(pid, :resource_contention)
      
      status = System2.get_status(pid)
      assert Enum.empty?(status.active_conflicts)
      assert status.resolutions_count == 1
    end

    test "tracks coordination effectiveness", %{pid: pid} do
      # Register and resolve multiple conflicts
      for i <- 1..5 do
        conflict = %{
          type: :"conflict_#{i}",
          units: ["unit_a", "unit_b"],
          resource: "shared_resource"
        }
        System2.register_conflict(pid, conflict)
        System2.resolve_conflict(pid, :"conflict_#{i}")
      end
      
      status = System2.get_status(pid)
      assert status.resolutions_count == 5
      assert status.coordination_effectiveness == 100.0
    end

    test "handles coordinate_units", %{pid: pid} do
      units = ["unit_1", "unit_2", "unit_3"]
      assert {:ok, :coordinated} = System2.coordinate_units(pid, units)
      
      status = System2.get_status(pid)
      assert status.coordination_count == 1
    end

    test "handles non-existent conflict resolution", %{pid: pid} do
      assert {:error, :conflict_not_found} = 
        System2.resolve_conflict(pid, :nonexistent_conflict)
    end
  end

  describe "coordination patterns" do
    test "tracks frequent conflict patterns", %{pid: pid} do
      # Create repeated conflicts
      for _ <- 1..3 do
        conflict = %{
          type: :resource_contention,
          units: ["unit_1", "unit_2"],
          resource: "cpu"
        }
        System2.register_conflict(pid, conflict)
      end
      
      status = System2.get_status(pid)
      assert length(status.active_conflicts) == 3
      # In real implementation, this would track patterns
    end
  end

  describe "telemetry events" do
    test "emits telemetry on conflict resolution", %{pid: pid} do
      :telemetry.attach(
        "test-coordination",
        [:vsm_mcp, :system2, :coordination],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      units = ["unit_1", "unit_2"]
      System2.coordinate_units(pid, units)

      assert_receive {:telemetry, [:vsm_mcp, :system2, :coordination], measurements, metadata}
      assert measurements.units_count == 2
      assert metadata.result == :ok

      :telemetry.detach("test-coordination")
    end
  end
end