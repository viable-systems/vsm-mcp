import Config

# MCP Server Configuration
# Uncomment to enable automatic MCP server startup

# config :vsm_mcp, :mcp_server,
#   transport: :stdio,      # :stdio | :tcp | :websocket
#   port: 3333,            # For TCP/WebSocket transports
#   capabilities: %{
#     tools: %{},
#     resources: %{
#       subscribe: true,
#       unsubscribe: true
#     },
#     prompts: %{},
#     completion: %{}
#   }

# MCP Client defaults
config :vsm_mcp, :mcp_client,
  default_timeout: 30_000,
  reconnect_interval: 5_000,
  max_reconnect_attempts: 10

# Transport-specific settings
config :vsm_mcp, :transports,
  tcp: [
    keepalive: true,
    nodelay: true,
    buffer_size: 65536
  ],
  websocket: [
    compress: true,
    max_frame_size: 65536
  ]