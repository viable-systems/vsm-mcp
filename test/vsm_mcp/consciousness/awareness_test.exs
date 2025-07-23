defmodule VsmMcp.Consciousness.AwarenessTest do
  use ExUnit.Case
  alias VsmMcp.Consciousness.Awareness

  setup do
    {:ok, pid} = Awareness.start_link([])
    %{pid: pid}
  end

  describe "state awareness" do
    test "tracks system state changes", %{pid: pid} do
      initial_state = %{
        operational_variety: 20.0,
        environmental_variety: 25.0,
        active_capabilities: ["read", "write"]
      }
      
      assert :ok = Awareness.update_state(pid, initial_state)
      
      current = Awareness.get_current_awareness(pid)
      assert current.state == initial_state
      assert current.timestamp != nil
    end

    test "detects significant state changes", %{pid: pid} do
      # Set initial state
      Awareness.update_state(pid, %{variety_ratio: 0.8})
      
      # Update with significant change
      Awareness.update_state(pid, %{variety_ratio: 0.5})
      
      changes = Awareness.get_significant_changes(pid)
      assert length(changes) > 0
      assert hd(changes).field == :variety_ratio
      assert hd(changes).magnitude == :high
    end

    test "maintains state history", %{pid: pid} do
      # Multiple state updates
      for i <- 1..5 do
        Awareness.update_state(pid, %{iteration: i})
        Process.sleep(10)
      end
      
      history = Awareness.get_state_history(pid)
      assert length(history) == 5
      assert List.last(history).state.iteration == 5
    end
  end

  describe "environmental awareness" do
    test "monitors environmental factors", %{pid: pid} do
      factors = %{
        external_requests: 100,
        resource_pressure: :high,
        threat_level: :moderate
      }
      
      Awareness.update_environment(pid, factors)
      
      current = Awareness.get_environmental_awareness(pid)
      assert current.factors == factors
      assert current.assessment != nil
    end

    test "identifies environmental threats", %{pid: pid} do
      Awareness.update_environment(pid, %{
        threat_level: :critical,
        resource_availability: :low,
        demand_spike: true
      })
      
      threats = Awareness.get_active_threats(pid)
      assert length(threats) > 0
      assert Enum.any?(threats, & &1.severity == :critical)
    end
  end

  describe "self-awareness" do
    test "tracks capability awareness", %{pid: pid} do
      capabilities = [
        %{name: "file_ops", status: :active, performance: 0.95},
        %{name: "network_ops", status: :degraded, performance: 0.60},
        %{name: "compute_ops", status: :active, performance: 0.88}
      ]
      
      Awareness.update_capabilities(pid, capabilities)
      
      awareness = Awareness.get_capability_awareness(pid)
      assert length(awareness.active) == 2
      assert length(awareness.degraded) == 1
      assert awareness.overall_health > 0.7
    end

    test "detects capability gaps", %{pid: pid} do
      current = ["read", "write", "parse"]
      required = ["read", "write", "parse", "analyze", "transform"]
      
      Awareness.analyze_capability_gaps(pid, current, required)
      
      gaps = Awareness.get_capability_gaps(pid)
      assert gaps.missing == ["analyze", "transform"]
      assert gaps.coverage == 0.6
    end
  end

  describe "attention mechanism" do
    test "focuses attention on critical areas", %{pid: pid} do
      # Create multiple concerns
      Awareness.report_concern(pid, :performance, %{metric: "latency", value: 500})
      Awareness.report_concern(pid, :resources, %{metric: "memory", value: 0.95})
      Awareness.report_concern(pid, :security, %{metric: "threats", value: 2})
      
      focus = Awareness.get_attention_focus(pid)
      
      # Should prioritize resource concern (95% memory)
      assert hd(focus).area == :resources
      assert hd(focus).priority == :critical
    end

    test "shifts attention based on urgency", %{pid: pid} do
      # Initial focus
      Awareness.report_concern(pid, :performance, %{severity: :low})
      initial_focus = Awareness.get_attention_focus(pid)
      
      # Urgent issue appears
      Awareness.report_concern(pid, :security, %{severity: :critical, immediate: true})
      new_focus = Awareness.get_attention_focus(pid)
      
      assert hd(new_focus).area == :security
      assert hd(initial_focus).area != hd(new_focus).area
    end
  end

  describe "awareness integration" do
    test "provides holistic system awareness", %{pid: pid} do
      # Update various aspects
      Awareness.update_state(pid, %{health: :good})
      Awareness.update_environment(pid, %{load: :moderate})
      Awareness.update_capabilities(pid, [%{name: "core", status: :active}])
      
      holistic = Awareness.get_holistic_awareness(pid)
      
      assert Map.has_key?(holistic, :internal_state)
      assert Map.has_key?(holistic, :environmental_state)
      assert Map.has_key?(holistic, :capability_state)
      assert Map.has_key?(holistic, :overall_assessment)
    end

    test "generates awareness summary", %{pid: pid} do
      # Populate awareness data
      Awareness.update_state(pid, %{variety_ratio: 0.75})
      Awareness.report_concern(pid, :variety, %{gap: 0.25})
      
      summary = Awareness.generate_summary(pid)
      
      assert String.contains?(summary, "variety")
      assert String.contains?(summary, "75%") or String.contains?(summary, "0.75")
    end
  end
end