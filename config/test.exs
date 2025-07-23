import Config

# We don't run the MCP server during test
config :vsm_mcp,
  start_mcp_server: false,
  
  # Faster intervals for testing
  variety_check_interval: 100,
  consciousness: [
    reflection_interval: 1000,
    learning_rate: 0.5,
    memory_limit: 10
  ]

# Print only warnings and errors during test
config :logger, level: :warning