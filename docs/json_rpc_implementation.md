# Bulletproof JSON-RPC 2.0 Implementation for VSM-MCP

This document describes the comprehensive JSON-RPC 2.0 implementation for the VSM-MCP system, designed to provide robust, compliant, and fault-tolerant message handling.

## Architecture Overview

The implementation consists of several key components:

1. **JsonRpc Module** - Core JSON-RPC message handling
2. **Protocol Handler** - Message routing and processing
3. **Transport Layer** - Communication channel management
4. **ID Management** - Request/response correlation system

## Core Features

### 1. Message Types Support

The implementation supports all JSON-RPC 2.0 message types:

- **Requests** - Method calls expecting responses
- **Responses** - Success or error responses to requests
- **Notifications** - One-way method calls (no response expected)
- **Batch Requests** - Multiple messages in a single request

### 2. Bulletproof Error Handling

#### Standard JSON-RPC Errors
- **Parse Error (-32700)** - Invalid JSON received
- **Invalid Request (-32600)** - Invalid JSON-RPC request
- **Method Not Found (-32601)** - Requested method doesn't exist
- **Invalid Params (-32602)** - Invalid method parameters
- **Internal Error (-32603)** - Server internal error

#### MCP-Specific Errors
- **Connection Error (-32001)** - Transport connection issues
- **Timeout Error (-32002)** - Request timeout exceeded
- **Resource Not Found (-32003)** - Requested resource unavailable
- **Tool Not Found (-32004)** - Requested tool unavailable
- **Invalid Capabilities (-32005)** - Capability negotiation failed

### 3. Request/Response Correlation

Robust ID management system that:
- Auto-generates unique IDs for requests
- Maintains pending request registry
- Handles request timeouts
- Correlates responses with original requests
- Manages request cancellation

### 4. Message Validation

Comprehensive validation including:
- JSON-RPC version compliance
- Required field presence
- Data type validation
- Message structure verification
- Batch message validation

## API Reference

### Core Functions

#### `build_jsonrpc_request/3`
Creates a proper JSON-RPC 2.0 request message.

```elixir
# Auto-generate ID
request = JsonRpc.build_jsonrpc_request("tools/list", %{})

# Specify ID
request = JsonRpc.build_jsonrpc_request("tools/list", %{}, 42)
```

#### `build_jsonrpc_response/2`
Creates a successful response message.

```elixir
response = JsonRpc.build_jsonrpc_response(%{tools: []}, 42)
```

#### `build_jsonrpc_error/3`
Creates an error response message.

```elixir
error = JsonRpc.build_jsonrpc_error(-32601, "Method not found", 42, %{method: "unknown"})
```

#### `build_jsonrpc_notification/2`
Creates a notification message (no response expected).

```elixir
notification = JsonRpc.build_jsonrpc_notification("progress", %{value: 50, total: 100})
```

#### `parse_jsonrpc_message/1`
Parses and validates incoming JSON-RPC messages.

```elixir
case JsonRpc.parse_jsonrpc_message(json_string) do
  {:ok, %Request{} = request} -> handle_request(request)
  {:ok, %Response{} = response} -> handle_response(response)
  {:ok, %Notification{} = notification} -> handle_notification(notification)
  {:ok, %Batch{} = batch} -> handle_batch(batch)
  {:error, reason} -> handle_parse_error(reason)
end
```

#### `encode_jsonrpc_message/1`
Encodes messages to JSON strings.

```elixir
{:ok, json} = JsonRpc.encode_jsonrpc_message(message)
```

#### `validate_jsonrpc_message/1`
Validates message structure and content.

```elixir
case JsonRpc.validate_jsonrpc_message(message) do
  {:ok, validated_message} -> process_message(validated_message)
  {:error, reason} -> handle_validation_error(reason)
end
```

#### `correlate_response/2`
Correlates responses with pending requests.

```elixir
case JsonRpc.correlate_response(response, pending_requests) do
  {:ok, {request_info, remaining_requests}} -> 
    handle_correlated_response(request_info)
  {:error, reason} -> 
    handle_correlation_error(reason)
end
```

### Utility Functions

- `generate_id/0` - Generates unique request IDs
- `is_request?/1` - Checks if message is a request
- `is_response?/1` - Checks if message is a response
- `is_notification?/1` - Checks if message is a notification
- `is_batch?/1` - Checks if message is a batch
- `get_message_id/1` - Extracts ID from message

### Standard Error Builders

- `parse_error/1` - Creates parse error response
- `invalid_request/1` - Creates invalid request error
- `method_not_found/2` - Creates method not found error
- `invalid_params/1` - Creates invalid params error
- `internal_error/2` - Creates internal error response

### MCP-Specific Error Builders

- `connection_error/2` - Creates connection error
- `timeout_error/2` - Creates timeout error
- `resource_not_found/2` - Creates resource not found error
- `tool_not_found/2` - Creates tool not found error
- `invalid_capabilities/2` - Creates capabilities error

## Usage Examples

### Basic Request/Response

```elixir
# Client side - sending request
request = JsonRpc.build_jsonrpc_request("tools/list", %{})
{:ok, json} = JsonRpc.encode_jsonrpc_message(request)
send_to_server(json)

# Server side - handling request
{:ok, parsed_request} = JsonRpc.parse_jsonrpc_message(received_json)
tools = get_available_tools()
response = JsonRpc.build_jsonrpc_response(%{tools: tools}, parsed_request.id)
{:ok, response_json} = JsonRpc.encode_jsonrpc_message(response)
send_to_client(response_json)
```

### Error Handling

```elixir
# Parse incoming message with error handling
case JsonRpc.parse_jsonrpc_message(json_string) do
  {:ok, message} ->
    process_message(message)
    
  {:error, {:parse_error, details}} ->
    error_response = JsonRpc.parse_error(nil)
    {:ok, error_json} = JsonRpc.encode_jsonrpc_message(error_response)
    send_error_response(error_json)
    
  {:error, {:invalid_request, reason}} ->
    error_response = JsonRpc.invalid_request(nil)
    send_error_response(error_response)
end
```

### Batch Processing

```elixir
# Handle batch requests
case JsonRpc.parse_jsonrpc_message(batch_json) do
  {:ok, %Batch{messages: messages}} ->
    responses = Enum.map(messages, fn
      %Request{} = req -> process_request(req)
      %Notification{} = notif -> process_notification(notif); nil
    end)
    |> Enum.filter(&(&1 != nil))
    
    batch_response = %Batch{messages: responses}
    {:ok, response_json} = JsonRpc.encode_jsonrpc_message(batch_response)
    send_batch_response(response_json)
end
```

### Request Timeout Handling

```elixir
# In the protocol handler
def handle_info({:request_timeout, request_id}, state) do
  case Map.get(state.pending_requests, request_id) do
    nil ->
      {:noreply, state}
      
    %{from: from} ->
      GenServer.reply(from, {:error, :timeout})
      new_state = %{state | 
        pending_requests: Map.delete(state.pending_requests, request_id)
      }
      {:noreply, new_state}
  end
end
```

## Integration with MCP Protocol

The JSON-RPC implementation seamlessly integrates with the MCP protocol:

1. **Tool Invocation** - `tools/call` requests with proper error handling
2. **Resource Access** - `resources/read` with resource-specific errors
3. **Capability Discovery** - `initialize` handshake with validation
4. **Progress Notifications** - One-way progress updates
5. **Cancellation Support** - Request cancellation handling

## Testing

Comprehensive test suite covers:

- Message parsing and validation
- Encoding/decoding round-trips
- Error response generation
- Batch message handling
- Edge cases and malformed input
- Request/response correlation
- Timeout handling

Run tests with:
```bash
mix test test/vsm_mcp/mcp/protocol/json_rpc_test.exs
```

## Performance Considerations

1. **ID Generation** - Uses GenServer for thread-safe ID generation
2. **Memory Management** - Proper cleanup of pending requests
3. **Error Recovery** - Graceful handling of malformed messages
4. **Timeout Management** - Configurable request timeouts
5. **Batch Optimization** - Efficient batch message processing

## Security Features

1. **Input Validation** - Strict message structure validation
2. **Error Information** - Controlled error information disclosure
3. **Request Limits** - Configurable timeout and size limits
4. **Safe Parsing** - Protected against malformed JSON attacks

## Configuration

Key configuration options:

```elixir
config :vsm_mcp, :json_rpc,
  request_timeout: 30_000,        # Default request timeout (ms)
  max_batch_size: 100,            # Maximum batch message count
  max_message_size: 1_048_576,    # Maximum message size (bytes)
  enable_strict_validation: true  # Enable strict JSON-RPC validation
```

## Compliance

This implementation is fully compliant with:

- **JSON-RPC 2.0 Specification** - Complete protocol support
- **MCP Protocol** - Model Context Protocol requirements
- **Elixir/OTP Standards** - Proper GenServer and supervision
- **Error Handling** - Comprehensive error reporting

## Future Enhancements

Planned improvements:

1. **Compression Support** - Message compression for large payloads
2. **Metrics Collection** - Performance and error metrics
3. **Rate Limiting** - Request rate limiting capabilities
4. **Message Encryption** - Optional message encryption
5. **Protocol Extensions** - Custom protocol extensions support

This bulletproof JSON-RPC implementation provides a solid foundation for reliable MCP communication with comprehensive error handling, validation, and correlation capabilities.