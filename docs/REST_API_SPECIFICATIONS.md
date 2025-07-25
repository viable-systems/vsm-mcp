# VSM-MCP REST API Specifications

## Overview

This document provides comprehensive specifications for the VSM-MCP daemon REST API endpoints, including detailed request/response schemas, authentication, error handling, and implementation patterns.

## Base Configuration

```
Base URL: http://localhost:4000/api/v1
Content-Type: application/json
Authentication: Bearer token (when enabled)
```

## 1. System Control Endpoints

### 1.1 System Status

```http
GET /api/v1/status
```

**Description**: Get comprehensive system status including all VSM systems, variety metrics, and component health.

**Response Schema**:
```json
{
  "status": "success",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "daemon": {
      "status": "running|starting|stopping|stopped",
      "uptime_seconds": 86400,
      "version": "0.1.0",
      "process_id": 12345,
      "memory_usage_mb": 128.5,
      "cpu_usage_percent": 15.2
    },
    "vsm_systems": {
      "system1": {
        "status": "active|inactive|error",
        "operations_count": 1250,
        "success_rate": 0.98,
        "average_duration_ms": 45,
        "capabilities": ["process", "transform", "capability_acquisition"],
        "mcp_servers": 3
      },
      "system2": {
        "status": "active",
        "coordination_points": 45,
        "active_coordinators": 8,
        "load_balance_efficiency": 0.87
      },
      "system3": {
        "status": "active",
        "audit_cycles": 12,
        "compliance_score": 0.92,
        "last_audit": "2024-01-01T00:00:00Z"
      },
      "system4": {
        "status": "active",
        "scans_completed": 8,
        "threats_detected": 2,
        "opportunities_identified": 5,
        "last_scan": "2024-01-01T00:00:00Z"
      },
      "system5": {
        "status": "active",
        "decisions_made": 23,
        "policy_updates": 3,
        "strategic_adjustments": 1
      }
    },
    "variety": {
      "current_ratio": 0.85,
      "required_variety": 120.5,
      "available_variety": 102.4,
      "gap_count": 3,
      "threshold": 0.7,
      "trend": "increasing|decreasing|stable",
      "last_assessed": "2024-01-01T00:00:00Z",
      "gaps": [
        {
          "type": "capability",
          "description": "Missing document generation",
          "severity": "medium",
          "estimated_impact": 0.15
        }
      ]
    },
    "mcp_servers": {
      "active_count": 5,
      "total_registered": 8,
      "inactive_count": 3,
      "health_status": {
        "healthy": 4,
        "degraded": 1,
        "unhealthy": 0,
        "unknown": 3
      },
      "last_discovery": "2024-01-01T00:00:00Z"
    },
    "consciousness": {
      "level": "aware",
      "last_reflection": "2024-01-01T00:00:00Z",
      "insights_count": 47,
      "learning_progress": 0.73
    }
  },
  "metadata": {
    "request_id": "req_status_001",
    "processing_time_ms": 45,
    "cache_status": "hit|miss",
    "version": "v1"
  }
}
```

### 1.2 Health Check

```http
GET /api/v1/health
```

**Description**: Lightweight health check for load balancers and monitoring systems.

**Response Schema**:
```json
{
  "status": "healthy|degraded|unhealthy",
  "timestamp": "2024-01-01T00:00:00Z",
  "checks": {
    "database": "healthy",
    "mcp_servers": "healthy", 
    "vsm_systems": "healthy",
    "external_dependencies": "degraded"
  },
  "uptime_seconds": 86400
}
```

### 1.3 Control Operations

```http
POST /api/v1/control/{action}
```

**Supported Actions**: `start`, `stop`, `restart`, `reload`

**Request Schema**:
```json
{
  "services": ["all", "vsm_systems", "mcp_servers", "monitoring"],
  "options": {
    "graceful": true,
    "timeout_seconds": 30,
    "force": false
  }
}
```

**Response Schema**:
```json
{
  "status": "success",
  "data": {
    "action": "restart",
    "services_affected": ["system1", "system2"],
    "execution_time_ms": 2500,
    "results": [
      {
        "service": "system1",
        "status": "success",
        "message": "Service restarted successfully"
      }
    ]
  }
}
```

## 2. VSM Systems Management

### 2.1 List All Systems

```http
GET /api/v1/vsm/systems
```

**Query Parameters**:
- `status`: Filter by status (`active`, `inactive`, `error`)
- `include_metrics`: Include detailed metrics (default: false)
- `include_capabilities`: Include capability lists (default: false)

### 2.2 System Details

```http
GET /api/v1/vsm/systems/{system_id}
```

**Path Parameters**:
- `system_id`: One of `system1`, `system2`, `system3`, `system4`, `system5`

**Response Schema**:
```json
{
  "status": "success",
  "data": {
    "id": "system1",
    "name": "Operations System",
    "description": "Primary operational activities and value production",
    "status": "active",
    "capabilities": [
      {
        "type": "process",
        "name": "Data Processing",
        "enabled": true,
        "performance_score": 0.92
      }
    ],
    "metrics": {
      "operations_per_hour": 450,
      "success_rate": 0.98,
      "average_response_time_ms": 45,
      "error_rate": 0.02,
      "resource_utilization": 0.67
    },
    "mcp_servers": [
      {
        "id": "mcp_001",
        "name": "document-generator",
        "status": "active",
        "capabilities": ["document_creation", "pdf_generation"]
      }
    ],
    "recent_operations": [
      {
        "timestamp": "2024-01-01T00:00:00Z",
        "type": "process",
        "duration_ms": 34,
        "status": "success"
      }
    ]
  }
}
```

### 2.3 Execute System Action

```http
POST /api/v1/vsm/systems/{system_id}/action
```

**Request Schema**:
```json
{
  "action": "execute_operation|audit|scan|coordinate|decide",
  "parameters": {
    "operation_type": "process",
    "data": "input_data",
    "options": {
      "priority": "high|medium|low",
      "timeout_ms": 30000,
      "use_mcp": true
    }
  }
}
```

## 3. Variety Management

### 3.1 Current Variety Analysis

```http
GET /api/v1/vsm/variety
```

**Response Schema**:
```json
{
  "status": "success",
  "data": {
    "analysis": {
      "timestamp": "2024-01-01T00:00:00Z",
      "variety_ratio": 0.85,
      "required_variety": 120.5,
      "available_variety": 102.4,
      "effectiveness_score": 0.78
    },
    "breakdown": {
      "internal_capabilities": 45.2,
      "mcp_server_capabilities": 35.8,
      "llm_capabilities": 21.4
    },
    "trends": {
      "last_hour": {
        "change": 0.03,
        "direction": "increasing"
      },
      "last_day": {
        "change": 0.12,
        "direction": "increasing"
      },
      "last_week": {
        "change": -0.05,
        "direction": "decreasing"
      }
    },
    "gaps": [
      {
        "id": "gap_001",
        "type": "capability",
        "description": "Missing advanced document generation",
        "severity": "medium",
        "impact_score": 0.15,
        "recommended_solutions": [
          {
            "type": "mcp_server",
            "name": "advanced-document-generator",
            "confidence": 0.87,
            "estimated_effort": "low"
          }
        ]
      }
    ],
    "opportunities": [
      {
        "id": "opp_001",
        "type": "enhancement",
        "description": "Optimize existing image processing",
        "potential_benefit": 0.08,
        "implementation_cost": "medium"
      }
    ]
  }
}
```

### 3.2 Trigger Variety Recalculation

```http
POST /api/v1/vsm/variety/recalculate
```

**Request Schema**:
```json
{
  "options": {
    "force": false,
    "include_external_scan": true,
    "deep_analysis": false,
    "mcp_discovery": true
  }
}
```

### 3.3 Capability Gap Analysis

```http
GET /api/v1/vsm/variety/gaps
```

**Query Parameters**:
- `severity`: Filter by severity (`low`, `medium`, `high`, `critical`)
- `type`: Filter by gap type (`capability`, `performance`, `security`)
- `limit`: Maximum number of gaps to return (default: 50)

## 4. Capability Management

### 4.1 List Capabilities

```http
GET /api/v1/capabilities
```

**Response Schema**:
```json
{
  "status": "success",
  "data": {
    "capabilities": [
      {
        "id": "cap_001",
        "name": "Document Generation",
        "type": "operational",
        "source": "mcp_server",
        "source_id": "mcp_document_gen",
        "status": "active",
        "performance_metrics": {
          "success_rate": 0.96,
          "average_response_time_ms": 850,
          "usage_count": 245
        },
        "tags": ["document", "pdf", "office"],
        "last_used": "2024-01-01T00:00:00Z",
        "created_at": "2024-01-01T00:00:00Z"
      }
    ],
    "summary": {
      "total_count": 42,
      "active_count": 38,
      "inactive_count": 4,
      "sources": {
        "internal": 15,
        "mcp_server": 23,
        "llm_generated": 4
      }
    }
  }
}
```

### 4.2 Acquire New Capability

```http
POST /api/v1/capabilities/acquire
```

**Request Schema**:
```json
{
  "capability": {
    "name": "PowerPoint Generation",
    "description": "Generate PowerPoint presentations",
    "tags": ["presentation", "office", "slides"],
    "requirements": {
      "input_formats": ["json", "markdown"],
      "output_formats": ["pptx"],
      "max_file_size_mb": 50
    }
  },
  "acquisition_strategy": {
    "preferred_method": "mcp_server",
    "fallback_methods": ["npm_package", "llm_generation"],
    "max_acquisition_time_ms": 300000,
    "auto_integrate": true
  },
  "options": {
    "priority": "high",
    "sandbox_test": true,
    "security_scan": true
  }
}
```

**Response Schema**:
```json
{
  "status": "success",
  "data": {
    "acquisition_id": "acq_001",
    "status": "in_progress|completed|failed",
    "capability_id": "cap_042",
    "method_used": "mcp_server",
    "progress": {
      "current_step": "installing_server",
      "steps_completed": 3,
      "total_steps": 7,
      "estimated_completion_ms": 45000
    },
    "results": {
      "server_id": "mcp_ppt_gen",
      "installation_path": "/opt/mcp/ppt-generator",
      "capabilities_added": ["create_presentation", "add_slide", "export_pptx"],
      "security_score": 85,
      "performance_benchmark": {
        "avg_response_time_ms": 1200,
        "success_rate": 0.94
      }
    }
  }
}
```

### 4.3 Remove Capability

```http
DELETE /api/v1/capabilities/{capability_id}
```

**Query Parameters**:
- `force`: Force removal even if in use (default: false)
- `cleanup`: Clean up associated resources (default: true)

## 5. MCP Server Management

### 5.1 List MCP Servers

```http
GET /api/v1/mcp/servers
```

**Response Schema**:
```json
{
  "status": "success",
  "data": {
    "servers": [
      {
        "id": "mcp_001",
        "name": "document-generator",
        "description": "Advanced document and report generation",
        "version": "1.2.3",
        "status": "active|inactive|starting|stopping|error",
        "health": "healthy|degraded|unhealthy",
        "connection": {
          "type": "stdio|tcp|websocket",
          "pid": 12345,
          "port": 3001,
          "last_heartbeat": "2024-01-01T00:00:00Z"
        },
        "capabilities": [
          {
            "name": "create_document",
            "description": "Create documents in various formats",
            "input_schema": {/* JSON Schema */},
            "usage_count": 145
          }
        ],
        "metrics": {
          "uptime_seconds": 86400,
          "requests_handled": 1250,
          "average_response_time_ms": 450,
          "error_rate": 0.02,
          "memory_usage_mb": 64.5
        },
        "installation": {
          "method": "npm",
          "path": "/opt/mcp/document-generator",
          "installed_at": "2024-01-01T00:00:00Z",
          "auto_installed": true
        }
      }
    ],
    "summary": {
      "total_count": 8,
      "active_count": 5,
      "health_distribution": {
        "healthy": 4,
        "degraded": 1,
        "unhealthy": 0
      }
    }
  }
}
```

### 5.2 Register New MCP Server

```http
POST /api/v1/mcp/servers
```

**Request Schema**:
```json
{
  "server": {
    "name": "custom-ai-server",
    "description": "Custom AI processing server",
    "installation": {
      "method": "npm|github|local",
      "source": "npm:custom-ai-server@latest",
      "auto_install": true
    },
    "connection": {
      "type": "stdio",
      "command": "npx custom-ai-server",
      "args": ["--mode", "production"],
      "env": {
        "API_KEY": "${CUSTOM_AI_API_KEY}"
      }
    },
    "health_check": {
      "enabled": true,
      "interval_ms": 30000,
      "timeout_ms": 5000
    }
  },
  "options": {
    "auto_start": true,
    "security_scan": true,
    "sandbox_test": true
  }
}
```

### 5.3 Server Control Operations

```http
POST /api/v1/mcp/servers/{server_id}/{action}
```

**Supported Actions**: `start`, `stop`, `restart`, `health-check`

### 5.4 Call Server Tool

```http
POST /api/v1/mcp/servers/{server_id}/tools/call
```

**Request Schema**:
```json
{
  "tool": {
    "name": "create_document",
    "arguments": {
      "title": "Monthly Report",
      "content": "Report content here...",
      "format": "pdf",
      "options": {
        "include_charts": true,
        "template": "corporate"
      }
    }
  },
  "options": {
    "timeout_ms": 30000,
    "retry_count": 3,
    "stream_response": false
  }
}
```

## 6. Monitoring and Metrics

### 6.1 System Metrics

```http
GET /api/v1/metrics
```

**Query Parameters**:
- `type`: Metric type (`variety`, `performance`, `health`, `all`)
- `timeframe`: Time range (`1h`, `24h`, `7d`, `30d`)
- `granularity`: Data granularity (`minute`, `hour`, `day`)

**Response Schema**:
```json
{
  "status": "success",
  "data": {
    "timeframe": "24h",
    "granularity": "hour",
    "metrics": {
      "variety": {
        "current": 0.85,
        "average": 0.82,
        "min": 0.75,
        "max": 0.89,
        "trend": "increasing",
        "data_points": [
          {
            "timestamp": "2024-01-01T00:00:00Z",
            "value": 0.85
          }
        ]
      },
      "performance": {
        "response_time": {
          "average_ms": 245,
          "p95_ms": 450,
          "p99_ms": 850
        },
        "throughput": {
          "requests_per_second": 12.5,
          "operations_per_minute": 450
        },
        "resource_usage": {
          "cpu_percent": 15.2,
          "memory_mb": 128.5,
          "disk_io_mb_per_sec": 2.1
        }
      },
      "health": {
        "service_availability": 0.998,
        "error_rate": 0.002,
        "mcp_server_health": 0.95
      }
    }
  }
}
```

### 6.2 Event Stream

```http
GET /api/v1/events
```

**Query Parameters**:
- `types`: Event types to include (comma-separated)
- `since`: Start timestamp (ISO 8601)
- `limit`: Maximum events to return
- `stream`: Enable Server-Sent Events (default: false)

## 7. Consciousness Interface

### 7.1 Consciousness State

```http
GET /api/v1/consciousness
```

**Response Schema**:
```json
{
  "status": "success",
  "data": {
    "consciousness_level": "aware",
    "meta_cognition": {
      "self_awareness_score": 0.78,
      "reflection_quality": 0.85,
      "learning_effectiveness": 0.72
    },
    "current_focus": [
      "variety_optimization",
      "mcp_server_integration", 
      "performance_monitoring"
    ],
    "recent_insights": [
      {
        "timestamp": "2024-01-01T00:00:00Z",
        "type": "pattern_recognition",
        "significance": 0.8,
        "description": "Identified recurring pattern in capability gaps",
        "implications": ["proactive_acquisition", "predictive_scaling"]
      }
    ],
    "decision_patterns": {
      "risk_tolerance": 0.65,
      "optimization_preference": "balanced",
      "learning_priority": "high"
    },
    "self_model": {
      "accuracy": 0.83,
      "last_updated": "2024-01-01T00:00:00Z",
      "confidence": 0.79
    }
  }
}
```

### 7.2 Trigger Reflection

```http
POST /api/v1/consciousness/reflect
```

**Request Schema**:
```json
{
  "context": {
    "focus_area": "variety_management|performance|decision_making",
    "depth": "shallow|moderate|deep",
    "include_recent_events": true
  },
  "options": {
    "store_insights": true,
    "update_self_model": true,
    "generate_recommendations": true
  }
}
```

### 7.3 Query Consciousness

```http
POST /api/v1/consciousness/query
```

**Request Schema**:
```json
{
  "query": {
    "type": "capability_assessment|decision_support|self_evaluation",
    "question": "What capabilities should we prioritize acquiring next?",
    "context": {
      "current_variety_ratio": 0.85,
      "recent_performance": "stable",
      "business_priorities": ["efficiency", "scalability"]
    }
  }
}
```

## 8. Configuration Management

### 8.1 Get Configuration

```http
GET /api/v1/config
```

**Query Parameters**:
- `section`: Configuration section (`daemon`, `monitoring`, `mcp_servers`, `security`)
- `include_schema`: Include configuration schema (default: false)

### 8.2 Update Configuration

```http
PUT /api/v1/config
```

**Request Schema**:
```json
{
  "configuration": {
    "daemon": {
      "http_port": 4000,
      "log_level": "info"
    },
    "monitoring": {
      "variety_check_interval_ms": 60000,
      "alert_thresholds": {
        "variety_ratio_min": 0.7
      }
    }
  },
  "options": {
    "validate_only": false,
    "restart_affected_services": true,
    "backup_current": true
  }
}
```

## 9. Error Handling

### 9.1 Standard Error Response

```json
{
  "status": "error",
  "timestamp": "2024-01-01T00:00:00Z",
  "error": {
    "code": "CAPABILITY_ACQUISITION_FAILED",
    "message": "Failed to acquire document generation capability",
    "details": "MCP server installation failed: npm package not found",
    "suggestion": "Check package name and registry availability"
  },
  "metadata": {
    "request_id": "req_error_001",
    "correlation_id": "corr_123456"
  }
}
```

### 9.2 Error Codes

- `SYSTEM_UNAVAILABLE`: System is starting or stopping
- `CAPABILITY_ACQUISITION_FAILED`: Failed to acquire requested capability
- `MCP_SERVER_ERROR`: MCP server operation failed
- `VARIETY_CALCULATION_FAILED`: Variety analysis failed
- `CONFIGURATION_INVALID`: Invalid configuration provided
- `AUTHENTICATION_FAILED`: Authentication required or failed
- `RATE_LIMIT_EXCEEDED`: Too many requests
- `RESOURCE_NOT_FOUND`: Requested resource not found
- `VALIDATION_ERROR`: Request validation failed
- `INTERNAL_ERROR`: Unexpected internal error

## 10. Authentication & Authorization

### 10.1 Bearer Token Authentication

```http
Authorization: Bearer <token>
```

### 10.2 API Key Authentication

```http
X-API-Key: <api_key>
```

### 10.3 Role-Based Access Control

**Roles**:
- `admin`: Full system access
- `operator`: System monitoring and basic control
- `viewer`: Read-only access
- `service`: Service-to-service communication

## 11. Rate Limiting

**Default Limits**:
- General endpoints: 100 requests/minute
- Capability acquisition: 10 requests/minute
- Status endpoints: 1000 requests/minute
- Health check: No limit

**Headers**:
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
```

## 12. Pagination

**Query Parameters**:
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20, max: 100)
- `sort`: Sort field
- `order`: Sort order (`asc`, `desc`)

**Response Headers**:
```http
X-Total-Count: 150
X-Page-Count: 8
X-Current-Page: 1
X-Per-Page: 20
```

This comprehensive REST API specification provides a complete interface for managing and monitoring the autonomous VSM-MCP daemon system, enabling full control over all system components, real-time monitoring, and autonomous capability management.