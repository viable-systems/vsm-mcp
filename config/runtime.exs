import Config

# Runtime configuration for production deployments
if config_env() == :prod do
  # Configure MCP server from environment
  if System.get_env("MCP_TRANSPORT") do
    config :vsm_mcp, :mcp_server,
      transport: String.to_atom(System.get_env("MCP_TRANSPORT") || "stdio"),
      port: String.to_integer(System.get_env("MCP_PORT") || "4000")
  end
  
  # Configure variety checking interval
  if System.get_env("VARIETY_CHECK_INTERVAL") do
    config :vsm_mcp,
      variety_check_interval: String.to_integer(System.get_env("VARIETY_CHECK_INTERVAL"))
  end
end