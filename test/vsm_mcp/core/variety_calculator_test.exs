defmodule VsmMcp.Core.VarietyCalculatorTest do
  use ExUnit.Case
  alias VsmMcp.Core.VarietyCalculator

  describe "variety calculations" do
    test "calculates operational variety from real metrics" do
      metrics = %{
        cpu_cores: 8,
        memory_mb: 1024,
        processes: 100,
        capabilities: ["read", "write", "compute", "analyze"],
        modules: 50
      }
      
      variety = VarietyCalculator.calculate_operational_variety(metrics)
      
      assert is_float(variety)
      assert variety > 0
      # With these metrics, variety should be reasonable
      assert variety > 10 and variety < 50
    end

    test "calculates environmental variety" do
      factors = %{
        external_apis: 5,
        data_sources: 10,
        user_requests: 1000,
        threat_vectors: 20,
        opportunities: 15
      }
      
      variety = VarietyCalculator.calculate_environmental_variety(factors)
      
      assert is_float(variety)
      assert variety > 0
    end

    test "determines variety gap" do
      operational = 25.5
      environmental = 30.2
      
      gap = VarietyCalculator.calculate_gap(operational, environmental)
      
      assert gap.deficit == 4.7
      assert gap.ratio < 1.0
      assert gap.status == :insufficient
    end

    test "identifies sufficient variety" do
      operational = 35.5
      environmental = 30.2
      
      gap = VarietyCalculator.calculate_gap(operational, environmental)
      
      assert gap.surplus > 0
      assert gap.ratio > 1.0
      assert gap.status == :sufficient
    end

    test "calculates system variety from capabilities" do
      capabilities = [
        %{name: "http_client", operations: 5},
        %{name: "json_parser", operations: 3},
        %{name: "database", operations: 10},
        %{name: "cache", operations: 4}
      ]
      
      variety = VarietyCalculator.capability_variety(capabilities)
      
      assert is_float(variety)
      # 4 capabilities with 22 total operations
      expected = :math.log2(4 * 22)
      assert_in_delta variety, expected, 0.1
    end

    test "handles empty metrics gracefully" do
      assert VarietyCalculator.calculate_operational_variety(%{}) == 0.0
      assert VarietyCalculator.calculate_environmental_variety(%{}) == 0.0
    end

    test "tracks variety over time" do
      history = [
        %{time: 1, operational: 20.0, environmental: 25.0},
        %{time: 2, operational: 22.0, environmental: 26.0},
        %{time: 3, operational: 24.0, environmental: 27.0}
      ]
      
      trend = VarietyCalculator.analyze_trend(history)
      
      assert trend.operational_trend == :increasing
      assert trend.environmental_trend == :increasing
      assert trend.gap_trend == :improving
    end
  end

  describe "requisite variety analysis" do
    test "recommends capability acquisition when gap exists" do
      current_state = %{
        operational_variety: 20.0,
        environmental_variety: 30.0,
        capabilities: ["basic_ops"]
      }
      
      recommendations = VarietyCalculator.recommend_actions(current_state)
      
      assert :acquire_capabilities in recommendations.actions
      assert recommendations.priority == :high
      assert recommendations.target_variety > 30.0
    end

    test "recommends optimization when variety is sufficient" do
      current_state = %{
        operational_variety: 35.0,
        environmental_variety: 30.0,
        capabilities: ["advanced_ops", "ml", "distributed"]
      }
      
      recommendations = VarietyCalculator.recommend_actions(current_state)
      
      assert :optimize_efficiency in recommendations.actions
      assert recommendations.priority == :low
    end
  end

  describe "variety composition" do
    test "decomposes variety by source" do
      system_state = %{
        units: [
          %{name: "unit1", variety: 5.0},
          %{name: "unit2", variety: 7.0},
          %{name: "unit3", variety: 3.0}
        ],
        coordination_variety: 2.0,
        control_variety: 3.0
      }
      
      composition = VarietyCalculator.decompose_variety(system_state)
      
      assert composition.unit_variety == 15.0
      assert composition.system_variety == 5.0
      assert composition.total_variety == 20.0
      assert Map.has_key?(composition.breakdown, :percentage_by_source)
    end
  end
end