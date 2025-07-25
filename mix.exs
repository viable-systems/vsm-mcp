defmodule VsmMcp.MixProject do
  use Mix.Project

  def project do
    [
      app: :vsm_mcp,
      version: "0.2.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  def application do
    [
      mod: {VsmMcp.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto, :ssl, :inets]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core dependencies
      {:jason, "~> 1.4"},
      {:phoenix_pubsub, "~> 2.1"},
      {:telemetry, "~> 1.2"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry_metrics, "~> 1.0"},
      
      # HTTP and networking
      {:httpoison, "~> 2.2"},
      {:websockex, "~> 0.4.3"},
      {:ranch, "~> 2.1"},
      
      # WebSocket and real-time
      {:cowboy, "~> 2.10"},
      {:plug, "~> 1.15"},
      {:plug_cowboy, "~> 2.6"},
      
      # Database
      {:ecto, "~> 3.11"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.17"},
      
      # AI/ML Integration
      {:nx, "~> 0.6"},
      {:axon, "~> 0.6"},
      {:bumblebee, "~> 0.5", runtime: false},
      
      # Monitoring and debugging
      {:observer_cli, "~> 1.7"},
      {:recon, "~> 2.5"},
      
      # Development and testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mock, "~> 0.3", only: :test},
      {:stream_data, "~> 0.6", only: [:dev, :test]},
      
      # MCP specific (if available)
      {:temp, "~> 0.4"},
      {:uuid, "~> 1.1"},
      
      # Missing dependencies
      {:gen_stage, "~> 1.2"},
      {:poolboy, "~> 1.5"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "ARCHITECTURE.md"],
      groups_for_modules: [
        "Core": [
          VsmMcp.Core.VarietyCalculator,
          VsmMcp.Core.MCPDiscovery,
          VsmMcp.Core.TransformationEngine
        ],
        "Systems": [
          VsmMcp.Systems.System1,
          VsmMcp.Systems.System2,
          VsmMcp.Systems.System3,
          VsmMcp.Systems.System4,
          VsmMcp.Systems.System5
        ],
        "Integration": [
          VsmMcp.Integration,
          VsmMcp.Integration.CapabilityMatcher,
          VsmMcp.Integration.Installer,
          VsmMcp.Integration.ServerManager
        ],
        "Consciousness": [
          VsmMcp.ConsciousnessInterface,
          VsmMcp.ConsciousnessInterface.Awareness,
          VsmMcp.ConsciousnessInterface.DecisionTracing,
          VsmMcp.ConsciousnessInterface.Learning
        ],
        "MCP Protocol": [
          VsmMcp.MCP.Client,
          VsmMcp.MCP.Server,
          VsmMcp.MCP.Protocol.JsonRpc,
          VsmMcp.MCP.ServerManager
        ]
      ]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "test.watch": ["test.watch --stale"],
      quality: ["format", "credo --strict", "dialyzer"],
      docs: ["docs --formatter html"]
    ]
  end
end