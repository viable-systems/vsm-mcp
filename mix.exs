defmodule VsmMcp.MixProject do
  use Mix.Project

  def project do
    [
      app: :vsm_mcp,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools, :crypto, :ssl, :inets],
      mod: {VsmMcp.Application, []}
    ]
  end

  defp deps do
    [
      # Core dependencies
      {:jason, "~> 1.4"},
      {:httpoison, "~> 2.0"},
      {:websocket_client, "~> 1.5"},
      {:plug_cowboy, "~> 2.6"},
      
      # Telemetry and monitoring
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      
      # Process management
      {:poolboy, "~> 1.5"},
      {:gen_state_machine, "~> 3.0"},
      
      # Testing and development
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:mock, "~> 0.3.7", only: :test},
      
      # Additional utilities
      {:uuid, "~> 1.1"},
      {:nimble_options, "~> 1.0"},
      {:decorator, "~> 1.4"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      groups_for_modules: [
        "VSM Systems": [
          VsmMcp.Systems.System1,
          VsmMcp.Systems.System2,
          VsmMcp.Systems.System3,
          VsmMcp.Systems.System4,
          VsmMcp.Systems.System5
        ],
        "MCP Protocol": [
          VsmMcp.MCP.Protocol,
          VsmMcp.MCP.Client,
          VsmMcp.MCP.Server
        ],
        "Variety Management": [
          VsmMcp.Variety.Analyst,
          VsmMcp.Variety.Acquisition
        ],
        "Consciousness": [
          VsmMcp.Consciousness.Interface,
          VsmMcp.Consciousness.MetaCognition
        ]
      ]
    ]
  end
end