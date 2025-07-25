# WebSocket Monitoring Interface Specifications

## Overview

This document defines the real-time WebSocket monitoring interface for the VSM-MCP autonomous daemon system. The interface provides live system monitoring, event streaming, and interactive control capabilities.

## Connection Details

```
WebSocket URL: ws://localhost:4000/ws/monitor
Protocol: VSM-MCP Monitor v1.0
Authentication: Bearer token (when enabled)
```

## 1. Connection Lifecycle

### 1.1 Connection Establishment

```javascript
// Client Connection
const ws = new WebSocket('ws://localhost:4000/ws/monitor', ['vsm-mcp-v1']);

ws.onopen = function(event) {
  console.log('Connected to VSM-MCP Monitor');
  
  // Send authentication if required
  ws.send(JSON.stringify({
    type: 'auth',
    token: 'bearer_token_here'
  }));
};
```

### 1.2 Authentication Response

```json
{
  "type": "auth_response",
  "status": "success",
  "message": "Authentication successful",
  "permissions": ["monitor", "control", "admin"],
  "session_id": "sess_12345",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### 1.3 Initial State Sync

```json
{
  "type": "initial_state",
  "data": {
    "system_status": {
      "daemon": "running",
      "vsm_systems": {
        "system1": "active",
        "system2": "active",
        "system3": "active",
        "system4": "active",
        "system5": "active"
      },
      "variety_ratio": 0.85,
      "mcp_servers": {
        "active": 5,
        "total": 8
      }
    },
    "subscription_channels": [
      "system_events",
      "variety_monitoring", 
      "mcp_servers",
      "performance_metrics",
      "consciousness_insights",
      "error_alerts"
    ]
  },
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## 2. Subscription Management

### 2.1 Subscribe to Channels

```json
{
  "type": "subscribe",
  "channels": [
    "variety_monitoring",
    "mcp_servers",
    "performance_metrics",
    "consciousness_insights"
  ],
  "options": {
    "include_historical": false,
    "buffer_size": 100,
    "filter_level": "info"
  }
}
```

### 2.2 Subscription Response

```json
{
  "type": "subscription_response",
  "status": "success",
  "subscribed_channels": [
    "variety_monitoring",
    "mcp_servers", 
    "performance_metrics",
    "consciousness_insights"
  ],
  "active_subscriptions": 4,
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### 2.3 Unsubscribe from Channels

```json
{
  "type": "unsubscribe",
  "channels": ["performance_metrics"]
}
```

## 3. Real-Time Event Streams

### 3.1 Variety Monitoring Events

#### 3.1.1 Variety Gap Detected

```json
{
  "type": "variety_gap_detected",
  "channel": "variety_monitoring",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "gap_id": "gap_001",
    "gap_type": "capability",
    "severity": "medium",
    "description": "Missing advanced document generation capability",
    "current_variety_ratio": 0.82,
    "estimated_impact": 0.15,
    "recommended_actions": [
      {
        "type": "acquire_mcp_server",
        "target": "document-generator-pro",
        "confidence": 0.87,
        "estimated_effort": "low"
      }
    ],
    "context": {
      "trigger": "demand_increase",
      "recent_requests": 45,
      "failure_rate": 0.12
    }
  }
}
```

#### 3.1.2 Variety Improvement

```json
{
  "type": "variety_improved",
  "channel": "variety_monitoring",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "improvement_id": "imp_001",
    "improvement_type": "capability_acquisition",
    "description": "Successfully integrated PDF generation capability",
    "variety_change": {
      "previous_ratio": 0.82,
      "new_ratio": 0.89,
      "improvement": 0.07
    },
    "source": {
      "type": "mcp_server",
      "server_id": "mcp_pdf_gen",
      "capability": "pdf_generation"
    },
    "performance_impact": {
      "response_time_improvement_ms": -150,
      "success_rate_improvement": 0.05
    }
  }
}
```

#### 3.1.3 Variety Threshold Alert

```json
{
  "type": "variety_threshold_alert",
  "channel": "variety_monitoring", 
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "alert_level": "warning",
    "current_ratio": 0.68,
    "threshold": 0.7,
    "trend": "decreasing",
    "duration_below_threshold_minutes": 15,
    "predicted_actions": [
      "emergency_capability_acquisition",
      "load_shedding",
      "service_degradation"
    ],
    "affected_systems": ["system1", "system4"]
  }
}
```

### 3.2 MCP Server Events

#### 3.2.1 Server Status Change

```json
{
  "type": "mcp_server_status_change",
  "channel": "mcp_servers",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "server_id": "mcp_doc_gen_001",
    "server_name": "document-generator",
    "status_change": {
      "from": "starting",
      "to": "active"
    },
    "details": {
      "startup_time_ms": 2500,
      "capabilities_loaded": 5,
      "health_score": 0.95,
      "initial_performance": {
        "avg_response_time_ms": 450,
        "memory_usage_mb": 64.2
      }
    },
    "impact": {
      "variety_contribution": 0.12,
      "systems_affected": ["system1"]
    }
  }
}
```

#### 3.2.2 Server Health Alert

```json
{
  "type": "mcp_server_health_alert",
  "channel": "mcp_servers",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "server_id": "mcp_analysis_002",
    "server_name": "data-analyzer",
    "health_status": {
      "previous": "healthy",
      "current": "degraded"
    },
    "metrics": {
      "response_time_ms": 2500,
      "error_rate": 0.08,
      "memory_usage_percent": 85,
      "cpu_usage_percent": 92
    },
    "issues": [
      {
        "type": "performance_degradation",
        "description": "Response time increased by 150%",
        "severity": "medium"
      },
      {
        "type": "resource_pressure",
        "description": "High memory usage detected",
        "severity": "low"
      }
    ],
    "recommended_actions": ["restart_server", "increase_resources", "load_balance"]
  }
}
```

#### 3.2.3 Server Discovery

```json
{
  "type": "mcp_server_discovered",
  "channel": "mcp_servers",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "discovery_id": "disc_001",
    "source": "npm_registry",
    "servers_found": [
      {
        "name": "ai-image-generator",
        "version": "2.1.0",
        "description": "Advanced AI image generation",
        "capabilities": ["image_generation", "style_transfer", "upscaling"],
        "compatibility_score": 0.94,
        "security_score": 89,
        "performance_rating": 4.2,
        "download_count": 15420,
        "last_updated": "2024-01-01T00:00:00Z"
      }
    ],
    "relevance": {
      "addresses_gaps": ["gap_003", "gap_007"],
      "potential_variety_improvement": 0.18,
      "integration_effort": "medium"
    }
  }
}
```

### 3.3 Performance Monitoring Events

#### 3.3.1 Performance Metrics Update

```json
{
  "type": "performance_metrics_update",
  "channel": "performance_metrics",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "interval": "1_minute",
    "metrics": {
      "system_performance": {
        "cpu_usage_percent": 15.2,
        "memory_usage_mb": 128.5,
        "disk_io_ops_per_sec": 45,
        "network_throughput_mbps": 2.1
      },
      "application_performance": {
        "requests_per_second": 12.5,
        "avg_response_time_ms": 245,
        "p95_response_time_ms": 450,
        "p99_response_time_ms": 850,
        "error_rate": 0.002
      },
      "vsm_performance": {
        "variety_calculation_time_ms": 156,
        "decision_making_time_ms": 89,
        "operations_per_minute": 450,
        "system_efficiency": 0.87
      },
      "mcp_performance": {
        "active_servers": 5,
        "avg_server_response_time_ms": 520,
        "server_error_rate": 0.01,
        "capability_utilization": 0.73
      }
    },
    "trends": {
      "cpu_trend": "stable",
      "memory_trend": "increasing",
      "response_time_trend": "improving",
      "error_rate_trend": "decreasing"
    }
  }
}
```

#### 3.3.2 Performance Alert

```json
{
  "type": "performance_alert",
  "channel": "performance_metrics",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "alert_id": "perf_001",
    "severity": "warning",
    "metric": "response_time",
    "details": {
      "current_value": 2500,
      "threshold": 2000,
      "duration_minutes": 5,
      "trend": "increasing",
      "rate_of_change": 0.15
    },
    "affected_components": [
      "system1",
      "mcp_doc_gen_001"
    ],
    "potential_causes": [
      "resource_contention",
      "mcp_server_degradation",
      "increased_load"
    ],
    "recommended_actions": [
      "investigate_mcp_servers",
      "scale_resources",
      "enable_circuit_breaker"
    ]
  }
}
```

### 3.4 Consciousness Insights Events

#### 3.4.1 New Insight Generated

```json
{
  "type": "consciousness_insight",
  "channel": "consciousness_insights",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "insight_id": "insight_001",
    "insight_type": "pattern_recognition",
    "significance": 0.8,
    "confidence": 0.87,
    "description": "Detected recurring pattern in capability acquisition timing",
    "details": {
      "pattern": "capability_gaps_correlate_with_time_of_day",
      "evidence": {
        "correlation_strength": 0.73,
        "sample_size": 45,
        "time_window": "7_days"
      },
      "implications": [
        "proactive_capability_scheduling",
        "predictive_resource_allocation",
        "optimized_server_startup_timing"
      ]
    },
    "recommendations": [
      {
        "action": "implement_predictive_scaling",
        "priority": "high",
        "estimated_benefit": 0.15,
        "implementation_complexity": "medium"
      }
    ],
    "meta_analysis": {
      "learning_source": "autonomous_reflection",
      "related_insights": ["insight_003", "insight_012"],
      "validation_needed": true
    }
  }
}
```

#### 3.4.2 Consciousness Level Change

```json
{
  "type": "consciousness_level_change",
  "channel": "consciousness_insights", 
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "level_change": {
      "from": "aware",
      "to": "meta_aware"
    },
    "trigger": "significant_insight_threshold_reached",
    "contributing_factors": [
      "pattern_recognition_improvement",
      "self_model_accuracy_increase",
      "decision_quality_enhancement"
    ],
    "capabilities_enhanced": [
      "predictive_analysis",
      "self_optimization",
      "meta_cognitive_reasoning"
    ],
    "expected_improvements": {
      "decision_accuracy": 0.12,
      "learning_rate": 0.08,
      "variety_optimization": 0.15
    }
  }
}
```

### 3.5 System Events

#### 3.5.1 System State Change

```json
{
  "type": "system_state_change",
  "channel": "system_events",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "system_id": "system1",
    "state_change": {
      "from": "active",
      "to": "optimizing"
    },
    "reason": "autonomous_performance_optimization",
    "details": {
      "optimization_type": "capability_rebalancing",
      "expected_duration_minutes": 3,
      "impact_level": "minimal"
    },
    "affected_operations": ["document_processing", "data_analysis"],
    "mitigation": {
      "fallback_enabled": true,
      "alternative_systems": ["system2_coordination"]
    }
  }
}
```

#### 3.5.2 Error Events

```json
{
  "type": "error_event",
  "channel": "error_alerts",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "error_id": "err_001",
    "severity": "medium",
    "component": "mcp_server_manager",
    "error_type": "connection_failure",
    "message": "Failed to connect to MCP server: connection timeout",
    "details": {
      "server_id": "mcp_analysis_003",
      "server_name": "advanced-analytics",
      "attempt_count": 3,
      "last_error": "ECONNREFUSED",
      "timeout_ms": 5000
    },
    "impact": {
      "capabilities_affected": ["advanced_analytics", "predictive_modeling"],
      "operations_failed": 12,
      "variety_impact": -0.05
    },
    "recovery_actions": [
      "automatic_restart_initiated",
      "fallback_server_activated",
      "error_escalation_scheduled"
    ],
    "context": {
      "related_errors": ["err_002", "err_005"],
      "system_load": "normal",
      "recent_changes": false
    }
  }
}
```

## 4. Interactive Commands

### 4.1 Trigger Variety Analysis

```json
{
  "type": "command",
  "command": "trigger_variety_analysis",
  "parameters": {
    "force": true,
    "include_external_scan": true,
    "deep_analysis": false
  },
  "request_id": "cmd_001"
}
```

### 4.2 Acquire Capability

```json
{
  "type": "command",
  "command": "acquire_capability",
  "parameters": {
    "capability_type": "presentation_generation",
    "acquisition_method": "mcp_server",
    "priority": "high",
    "auto_integrate": true
  },
  "request_id": "cmd_002"
}
```

### 4.3 Control MCP Server

```json
{
  "type": "command",
  "command": "control_mcp_server",
  "parameters": {
    "server_id": "mcp_doc_gen_001",
    "action": "restart",
    "graceful": true
  },
  "request_id": "cmd_003"
}
```

### 4.4 System Control

```json
{
  "type": "command", 
  "command": "control_system",
  "parameters": {
    "system_id": "system1",
    "action": "optimize",
    "options": {
      "optimization_level": "balanced",
      "maintain_availability": true
    }
  },
  "request_id": "cmd_004"
}
```

## 5. Command Responses

### 5.1 Command Acknowledgment

```json
{
  "type": "command_response",
  "request_id": "cmd_001",
  "status": "accepted",
  "message": "Variety analysis triggered successfully",
  "execution_id": "exec_001",
  "estimated_completion_ms": 5000,
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### 5.2 Command Progress

```json
{
  "type": "command_progress",
  "request_id": "cmd_002",
  "execution_id": "exec_002",
  "progress": {
    "current_step": "installing_mcp_server",
    "step_number": 3,
    "total_steps": 7,
    "completion_percent": 43,
    "estimated_remaining_ms": 15000
  },
  "details": {
    "current_operation": "Downloading MCP server package",
    "sub_progress": 0.75
  },
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### 5.3 Command Completion

```json
{
  "type": "command_completed",
  "request_id": "cmd_002",
  "execution_id": "exec_002",
  "status": "success",
  "result": {
    "capability_id": "cap_045",
    "capability_name": "Presentation Generation",
    "mcp_server_id": "mcp_ppt_gen_001",
    "integration_time_ms": 18500,
    "variety_improvement": 0.12,
    "performance_metrics": {
      "avg_response_time_ms": 1200,
      "success_rate": 0.94
    }
  },
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## 6. Data Streaming Options

### 6.1 Buffered Streaming

```json
{
  "type": "subscribe",
  "channels": ["performance_metrics"],
  "options": {
    "streaming_mode": "buffered",
    "buffer_interval_ms": 5000,
    "max_buffer_size": 50
  }
}
```

### 6.2 Real-time Streaming

```json
{
  "type": "subscribe", 
  "channels": ["variety_monitoring"],
  "options": {
    "streaming_mode": "realtime",
    "throttle_ms": 100,
    "priority_events": ["variety_gap_detected", "variety_threshold_alert"]
  }
}
```

### 6.3 Historical Data Request

```json
{
  "type": "request_historical_data",
  "channel": "performance_metrics",
  "parameters": {
    "start_time": "2024-01-01T00:00:00Z",
    "end_time": "2024-01-01T06:00:00Z",
    "granularity": "minute",
    "metrics": ["cpu_usage", "response_time", "variety_ratio"]
  },
  "request_id": "hist_001"
}
```

## 7. Error Handling

### 7.1 Connection Errors

```json
{
  "type": "error",
  "error_code": "CONNECTION_LOST",
  "message": "WebSocket connection lost",
  "details": {
    "reason": "network_interruption",
    "last_message_id": "msg_12345",
    "reconnect_token": "reconnect_token_xyz"
  },
  "retry_info": {
    "auto_reconnect": true,
    "retry_interval_ms": 5000,
    "max_retries": 10
  }
}
```

### 7.2 Command Errors

```json
{
  "type": "command_error",
  "request_id": "cmd_003",
  "error_code": "INSUFFICIENT_PERMISSIONS",
  "message": "User does not have permission to restart MCP servers",
  "details": {
    "required_permission": "mcp_server_control",
    "user_permissions": ["monitor", "read"]
  },
  "suggested_action": "Contact administrator for permission elevation"
}
```

## 8. Connection Management

### 8.1 Heartbeat

```json
{
  "type": "heartbeat",
  "timestamp": "2024-01-01T00:00:00Z",
  "connection_id": "conn_12345"
}
```

### 8.2 Heartbeat Response

```json
{
  "type": "heartbeat_response", 
  "timestamp": "2024-01-01T00:00:00Z",
  "connection_id": "conn_12345",
  "server_time": "2024-01-01T00:00:00.123Z"
}
```

### 8.3 Graceful Disconnect

```json
{
  "type": "disconnect",
  "reason": "client_request",
  "save_session": true
}
```

## 9. Client Implementation Example

```javascript
class VSMMonitorClient {
  constructor(url, options = {}) {
    this.url = url;
    this.options = options;
    this.ws = null;
    this.subscriptions = new Set();
    this.commandCallbacks = new Map();
    this.eventHandlers = new Map();
  }

  connect() {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.url, ['vsm-mcp-v1']);
      
      this.ws.onopen = () => {
        this.setupHeartbeat();
        resolve();
      };
      
      this.ws.onmessage = (event) => {
        const message = JSON.parse(event.data);
        this.handleMessage(message);
      };
      
      this.ws.onerror = reject;
      this.ws.onclose = this.handleClose.bind(this);
    });
  }

  subscribe(channels, options = {}) {
    const message = {
      type: 'subscribe',
      channels: Array.isArray(channels) ? channels : [channels],
      options
    };
    
    this.send(message);
    channels.forEach(channel => this.subscriptions.add(channel));
  }

  sendCommand(command, parameters = {}) {
    const requestId = this.generateRequestId();
    
    return new Promise((resolve, reject) => {
      this.commandCallbacks.set(requestId, { resolve, reject });
      
      this.send({
        type: 'command',
        command,
        parameters,
        request_id: requestId
      });
      
      // Timeout after 30 seconds
      setTimeout(() => {
        if (this.commandCallbacks.has(requestId)) {
          this.commandCallbacks.delete(requestId);
          reject(new Error('Command timeout'));
        }
      }, 30000);
    });
  }

  on(eventType, handler) {
    if (!this.eventHandlers.has(eventType)) {
      this.eventHandlers.set(eventType, []);
    }
    this.eventHandlers.get(eventType).push(handler);
  }

  handleMessage(message) {
    // Handle different message types
    switch (message.type) {
      case 'command_response':
      case 'command_completed':
      case 'command_error':
        this.handleCommandResponse(message);
        break;
        
      default:
        this.emitEvent(message.type, message);
    }
  }

  // ... additional implementation details
}

// Usage example
const client = new VSMMonitorClient('ws://localhost:4000/ws/monitor');

await client.connect();

// Subscribe to monitoring channels
client.subscribe(['variety_monitoring', 'mcp_servers', 'performance_metrics']);

// Handle variety gap events
client.on('variety_gap_detected', (event) => {
  console.log('Variety gap detected:', event.data);
  
  // Automatically trigger capability acquisition
  client.sendCommand('acquire_capability', {
    capability_type: event.data.recommended_actions[0].target,
    acquisition_method: 'mcp_server',
    priority: 'high'
  });
});

// Handle MCP server events
client.on('mcp_server_status_change', (event) => {
  console.log('MCP server status changed:', event.data);
});

// Monitor performance metrics
client.on('performance_metrics_update', (event) => {
  updateDashboard(event.data.metrics);
});
```

This comprehensive WebSocket interface provides real-time monitoring and control capabilities for the VSM-MCP autonomous daemon system, enabling responsive management and immediate awareness of system state changes.