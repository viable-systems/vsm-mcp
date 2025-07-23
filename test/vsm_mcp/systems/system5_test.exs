defmodule VsmMcp.Systems.System5Test do
  use ExUnit.Case
  alias VsmMcp.Systems.System5

  setup do
    {:ok, pid} = System5.start_link([])
    %{pid: pid}
  end

  describe "policy and identity" do
    test "handles set_policy", %{pid: pid} do
      policy = %{
        purpose: "Maintain requisite variety through autonomous capability acquisition",
        principles: ["autonomy", "adaptability", "efficiency"],
        constraints: ["ethical_ai", "resource_limits"]
      }
      
      assert :ok = System5.set_policy(pid, policy)
      status = System5.get_status(pid)
      
      assert status.current_policy == policy
      assert status.policy_changes == 1
    end

    test "handles make_decision", %{pid: pid} do
      # Set policy first
      System5.set_policy(pid, %{
        purpose: "Maximize system effectiveness",
        principles: ["efficiency", "reliability"],
        constraints: ["budget", "compliance"]
      })
      
      context = %{
        situation: "New capability required",
        options: ["buy_service", "build_internal", "partner"],
        constraints: ["limited_budget", "time_pressure"]
      }
      
      {:ok, decision} = System5.make_decision(pid, context)
      
      assert is_map(decision)
      assert Map.has_key?(decision, :choice)
      assert Map.has_key?(decision, :rationale)
      assert Map.has_key?(decision, :confidence)
    end

    test "tracks decision history", %{pid: pid} do
      # Make multiple decisions
      for i <- 1..3 do
        context = %{
          situation: "Decision #{i}",
          options: ["option_a", "option_b"],
          constraints: []
        }
        System5.make_decision(pid, context)
      end
      
      status = System5.get_status(pid)
      assert status.decisions_made == 3
      assert length(status.decision_history) == 3
    end

    test "maintains identity consistency", %{pid: pid} do
      # Set identity
      identity = %{
        name: "VSM-MCP System",
        version: "1.0.0",
        capabilities: ["autonomous_learning", "mcp_integration"],
        values: ["transparency", "effectiveness"]
      }
      
      assert :ok = System5.define_identity(pid, identity)
      status = System5.get_status(pid)
      
      assert status.identity == identity
    end
  end

  describe "strategic guidance" do
    test "handles strategic_review", %{pid: pid} do
      metrics = %{
        system_performance: 0.85,
        variety_ratio: 0.78,
        adaptation_success: 0.90,
        resource_utilization: 0.72
      }
      
      {:ok, review} = System5.strategic_review(pid, metrics)
      
      assert is_map(review)
      assert Map.has_key?(review, :assessment)
      assert Map.has_key?(review, :recommendations)
      assert Map.has_key?(review, :priority_actions)
    end

    test "adjusts policy based on performance", %{pid: pid} do
      # Set initial policy
      System5.set_policy(pid, %{
        purpose: "Maintain stability",
        principles: ["conservative_growth"],
        constraints: ["risk_averse"]
      })
      
      # Poor performance metrics
      metrics = %{
        system_performance: 0.45,
        variety_ratio: 0.40,
        adaptation_success: 0.30
      }
      
      {:ok, review} = System5.strategic_review(pid, metrics)
      
      assert review.assessment == :critical
      assert Enum.any?(review.recommendations, &String.contains?(&1, "policy"))
    end
  end

  describe "meta-level coordination" do
    test "coordinates with all systems", %{pid: pid} do
      system_states = %{
        system1: %{status: :operational, variety: 10.5},
        system2: %{status: :coordinating, effectiveness: 0.92},
        system3: %{status: :optimizing, control: 0.88},
        system4: %{status: :scanning, gap: :moderate}
      }
      
      {:ok, coordination} = System5.coordinate_systems(pid, system_states)
      
      assert is_map(coordination)
      assert Map.has_key?(coordination, :directives)
      assert Map.has_key?(coordination, :balance_assessment)
    end

    test "handles emergency intervention", %{pid: pid} do
      emergency = %{
        type: :variety_collapse,
        severity: :critical,
        affected_systems: [:system1, :system2],
        metrics: %{variety_ratio: 0.25}
      }
      
      {:ok, intervention} = System5.emergency_intervention(pid, emergency)
      
      assert intervention.immediate_actions != []
      assert intervention.policy_override != nil
      assert intervention.recovery_plan != nil
    end
  end

  describe "telemetry events" do
    test "emits telemetry on decisions", %{pid: pid} do
      :telemetry.attach(
        "test-decision",
        [:vsm_mcp, :system5, :decision],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      context = %{
        situation: "Test decision",
        options: ["a", "b"],
        constraints: []
      }
      System5.make_decision(pid, context)

      assert_receive {:telemetry, [:vsm_mcp, :system5, :decision], measurements, metadata}
      assert measurements.decision_time > 0
      assert metadata.situation == "Test decision"

      :telemetry.detach("test-decision")
    end
  end
end