defmodule VsmMcp.Systems.System4Test do
  use ExUnit.Case
  alias VsmMcp.Systems.System4

  setup do
    {:ok, pid} = System4.start_link([])
    %{pid: pid}
  end

  describe "environmental scanning" do
    test "handles scan_environment", %{pid: pid} do
      scan_data = %{
        opportunities: ["new_api", "cloud_migration"],
        threats: ["competitor_launch"],
        trends: ["serverless", "ai_integration"]
      }
      
      assert {:ok, :scanned} = System4.scan_environment(pid, scan_data)
      status = System4.get_status(pid)
      
      assert status.opportunities == ["new_api", "cloud_migration"]
      assert status.threats == ["competitor_launch"]
      assert status.environmental_variety > 0
    end

    test "calculates environmental variety", %{pid: pid} do
      scan_data = %{
        opportunities: ["opp1", "opp2", "opp3"],
        threats: ["threat1", "threat2"],
        trends: ["trend1", "trend2", "trend3", "trend4"]
      }
      
      System4.scan_environment(pid, scan_data)
      status = System4.get_status(pid)
      
      # 3 opportunities + 2 threats + 4 trends = 9 factors
      expected_variety = :math.log2(9)
      assert_in_delta status.environmental_variety, expected_variety, 0.1
    end

    test "handles analyze_gap", %{pid: pid} do
      # Set up environmental data
      System4.scan_environment(pid, %{
        opportunities: ["api", "cloud"],
        threats: ["competition"],
        trends: ["ai", "edge"]
      })
      
      current_capabilities = ["http", "json", "database"]
      
      {:ok, analysis} = System4.analyze_gap(pid, current_capabilities)
      
      assert is_map(analysis)
      assert Map.has_key?(analysis, :missing_capabilities)
      assert Map.has_key?(analysis, :gap_severity)
      assert Map.has_key?(analysis, :recommendations)
    end

    test "detects variety mismatch", %{pid: pid} do
      # Create significant environmental complexity
      System4.scan_environment(pid, %{
        opportunities: Enum.map(1..10, &"opportunity_#{&1}"),
        threats: Enum.map(1..5, &"threat_#{&1}"),
        trends: Enum.map(1..8, &"trend_#{&1}")
      })
      
      # Minimal capabilities
      {:ok, analysis} = System4.analyze_gap(pid, ["basic_capability"])
      
      assert analysis.gap_severity == :critical
      assert length(analysis.recommendations) > 0
    end
  end

  describe "adaptation planning" do
    test "handles plan_adaptation", %{pid: pid} do
      gap_analysis = %{
        missing_capabilities: ["ai_integration", "cloud_scaling"],
        gap_severity: :high
      }
      
      assert {:ok, :planned} = System4.plan_adaptation(pid, gap_analysis)
      status = System4.get_status(pid)
      
      assert Map.has_key?(status.adaptation_plans, :current)
      assert status.adaptations_planned == 1
    end

    test "tracks market intelligence", %{pid: pid} do
      # Multiple environmental scans
      for i <- 1..3 do
        System4.scan_environment(pid, %{
          opportunities: ["opp_#{i}"],
          threats: ["threat_#{i}"],
          trends: ["trend_#{i}"]
        })
        Process.sleep(10) # Ensure different timestamps
      end
      
      status = System4.get_status(pid)
      assert status.last_scan_time != nil
      assert length(status.scan_history) == 3
    end
  end

  describe "future modeling" do
    test "projects future variety requirements", %{pid: pid} do
      # Current state
      System4.scan_environment(pid, %{
        opportunities: ["current_opp"],
        threats: ["current_threat"],
        trends: ["growing_trend", "emerging_tech"]
      })
      
      {:ok, projection} = System4.project_future(pid, :three_months)
      
      assert is_map(projection)
      assert Map.has_key?(projection, :projected_variety)
      assert Map.has_key?(projection, :confidence)
      assert projection.projected_variety >= 0
    end
  end

  describe "telemetry events" do
    test "emits telemetry on environmental scan", %{pid: pid} do
      :telemetry.attach(
        "test-scan",
        [:vsm_mcp, :system4, :scan],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      scan_data = %{
        opportunities: ["opp1"],
        threats: ["threat1"],
        trends: ["trend1"]
      }
      System4.scan_environment(pid, scan_data)

      assert_receive {:telemetry, [:vsm_mcp, :system4, :scan], measurements, metadata}
      assert measurements.factors_count == 3
      assert metadata.result == :ok

      :telemetry.detach("test-scan")
    end
  end
end