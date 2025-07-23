# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :vsm_mcp,
  # Variety management settings
  variety_check_interval: 60_000,  # Check variety every minute
  variety_threshold: 0.7,          # Minimum acceptable variety ratio
  
  # MCP server settings
  mcp_server: [
    transport: :stdio,
    capabilities: ["vsm", "cybernetics", "autonomy", "mcp"],
    server_info: %{
      name: "VSM-MCP",
      version: "0.1.0",
      description: "Viable System Model with Model Context Protocol"
    }
  ],
  
  # Consciousness settings
  consciousness: [
    reflection_interval: 300_000,  # Reflect every 5 minutes
    learning_rate: 0.1,
    memory_limit: 1000
  ],
  
  # Integration settings
  integration: [
    sandbox_timeout: 30_000,
    max_capability_size: 100_000_000,  # 100MB
    security_threshold: 70
  ],
  
  # Optional components
  enable_event_bus: true,
  enable_pattern_engine: true,
  start_mcp_server: false

# Configure Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :module]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"