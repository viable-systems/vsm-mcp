import Config

# For development, we enable more verbose logging
config :logger, level: :debug

# Start MCP server in development
config :vsm_mcp,
  start_mcp_server: true,
  
  # Faster intervals for development
  variety_check_interval: 10_000,
  consciousness: [
    reflection_interval: 60_000,
    learning_rate: 0.2,
    memory_limit: 100
  ]