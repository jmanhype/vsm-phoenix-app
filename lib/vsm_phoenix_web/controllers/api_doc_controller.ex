defmodule VsmPhoenixWeb.ApiDocController do
  use VsmPhoenixWeb, :controller
  
  # OpenAPI 3.0 Specification for VSM Phoenix Phase 2
  @openapi_spec %{
    openapi: "3.0.0",
    info: %{
      title: "VSM Phoenix Phase 2 API",
      version: "2.0.0",
      description: """
      Comprehensive API documentation for VSM Phoenix Phase 2 features including:
      - GoldRush Pattern Matching Engine
      - LLM Integration Services
      - Advanced Security Configuration
      - WebSocket Event Subscriptions
      - Cybernetic System Management
      """,
      contact: %{
        name: "VSM Phoenix Team",
        email: "support@vsmphoenix.io"
      }
    },
    servers: [
      %{
        url: "http://localhost:4000",
        description: "Development server"
      },
      %{
        url: "https://api.vsmphoenix.io",
        description: "Production server"
      }
    ],
    tags: [
      %{name: "VSM Core", description: "Core VSM system operations"},
      %{name: "GoldRush", description: "Pattern matching and event processing"},
      %{name: "LLM", description: "Language model integration"},
      %{name: "Security", description: "Authentication and authorization"},
      %{name: "WebSocket", description: "Real-time event subscriptions"},
      %{name: "Agents", description: "S1 Agent management"},
      %{name: "MCP", description: "Model Context Protocol integration"}
    ],
    paths: goldrush_paths() 
      |> Map.merge(llm_paths())
      |> Map.merge(security_paths())
      |> Map.merge(websocket_paths())
      |> Map.merge(vsm_core_paths())
      |> Map.merge(agent_paths()),
    components: %{
      schemas: schemas(),
      securitySchemes: %{
        BearerAuth: %{
          type: "http",
          scheme: "bearer",
          bearerFormat: "JWT"
        },
        ApiKeyAuth: %{
          type: "apiKey",
          in: "header",
          name: "X-API-Key"
        }
      }
    }
  }

  # Render interactive API explorer
  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, swagger_ui_html())
  end

  # Return OpenAPI JSON specification
  def openapi(conn, _params) do
    json(conn, @openapi_spec)
  end

  # Return API examples
  def examples(conn, %{"endpoint" => endpoint}) do
    examples = get_examples(endpoint)
    json(conn, examples)
  end

  # Private functions

  defp swagger_ui_html do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>VSM Phoenix API Documentation</title>
      <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui.css" />
      <style>
        html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin:0; background: #fafafa; }
        .topbar { display: none; }
        .swagger-ui .info { margin: 50px 0; }
        .swagger-ui .scheme-container { background: #f5f5f5; padding: 15px 0; }
      </style>
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-bundle.js"></script>
      <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-standalone-preset.js"></script>
      <script>
        window.onload = function() {
          window.ui = SwaggerUIBundle({
            url: "/api/docs/openapi.json",
            dom_id: '#swagger-ui',
            deepLinking: true,
            presets: [
              SwaggerUIBundle.presets.apis,
              SwaggerUIStandalonePreset
            ],
            plugins: [
              SwaggerUIBundle.plugins.DownloadUrl
            ],
            layout: "StandaloneLayout",
            defaultModelsExpandDepth: 1,
            defaultModelExpandDepth: 1,
            docExpansion: "list",
            filter: true,
            showExtensions: true,
            showCommonExtensions: true,
            tryItOutEnabled: true,
            onComplete: function() {
              console.log("Swagger UI loaded successfully");
            }
          });
        };
      </script>
    </body>
    </html>
    """
  end

  defp goldrush_paths do
    %{
      "/api/goldrush/patterns" => %{
        get: %{
          tags: ["GoldRush"],
          summary: "List all patterns",
          description: "Retrieve all registered GoldRush patterns",
          operationId: "listPatterns",
          responses: %{
            "200" => %{
              description: "List of patterns",
              content: %{
                "application/json" => %{
                  schema: %{
                    type: "array",
                    items: %{"$ref" => "#/components/schemas/Pattern"}
                  }
                }
              }
            }
          }
        },
        post: %{
          tags: ["GoldRush"],
          summary: "Create a new pattern",
          description: "Register a new GoldRush pattern for event matching",
          operationId: "createPattern",
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{"$ref" => "#/components/schemas/PatternInput"}
              }
            }
          },
          responses: %{
            "201" => %{
              description: "Pattern created successfully",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/Pattern"}
                }
              }
            }
          }
        }
      },
      "/api/goldrush/events" => %{
        post: %{
          tags: ["GoldRush"],
          summary: "Submit an event",
          description: "Submit an event for pattern matching and processing",
          operationId: "submitEvent",
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{"$ref" => "#/components/schemas/EventInput"}
              }
            }
          },
          responses: %{
            "200" => %{
              description: "Event processed successfully",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/EventResult"}
                }
              }
            }
          }
        }
      },
      "/api/goldrush/query" => %{
        post: %{
          tags: ["GoldRush"],
          summary: "Execute complex query",
          description: "Execute a complex query against the event stream",
          operationId: "complexQuery",
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{"$ref" => "#/components/schemas/QueryInput"}
              }
            }
          },
          responses: %{
            "200" => %{
              description: "Query results",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/QueryResult"}
                }
              }
            }
          }
        }
      }
    }
  end

  defp llm_paths do
    %{
      "/api/llm/chat" => %{
        post: %{
          tags: ["LLM"],
          summary: "Chat with LLM",
          description: "Send a message to the language model and receive a response",
          operationId: "chatWithLLM",
          security: [%{BearerAuth: []}],
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{"$ref" => "#/components/schemas/ChatRequest"}
              }
            }
          },
          responses: %{
            "200" => %{
              description: "Chat response",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/ChatResponse"}
                }
              }
            }
          }
        }
      },
      "/api/llm/models" => %{
        get: %{
          tags: ["LLM"],
          summary: "List available models",
          description: "Get a list of available language models",
          operationId: "listModels",
          responses: %{
            "200" => %{
              description: "List of models",
              content: %{
                "application/json" => %{
                  schema: %{
                    type: "array",
                    items: %{"$ref" => "#/components/schemas/Model"}
                  }
                }
              }
            }
          }
        }
      },
      "/api/llm/embeddings" => %{
        post: %{
          tags: ["LLM"],
          summary: "Generate embeddings",
          description: "Generate embeddings for given text",
          operationId: "generateEmbeddings",
          security: [%{BearerAuth: []}],
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{"$ref" => "#/components/schemas/EmbeddingRequest"}
              }
            }
          },
          responses: %{
            "200" => %{
              description: "Embeddings generated",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/EmbeddingResponse"}
                }
              }
            }
          }
        }
      }
    }
  end

  defp security_paths do
    %{
      "/api/auth/login" => %{
        post: %{
          tags: ["Security"],
          summary: "User login",
          description: "Authenticate user and receive access token",
          operationId: "login",
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{"$ref" => "#/components/schemas/LoginRequest"}
              }
            }
          },
          responses: %{
            "200" => %{
              description: "Login successful",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/LoginResponse"}
                }
              }
            }
          }
        }
      },
      "/api/auth/refresh" => %{
        post: %{
          tags: ["Security"],
          summary: "Refresh token",
          description: "Refresh an expired access token",
          operationId: "refreshToken",
          security: [%{BearerAuth: []}],
          responses: %{
            "200" => %{
              description: "Token refreshed",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/TokenResponse"}
                }
              }
            }
          }
        }
      },
      "/api/auth/permissions" => %{
        get: %{
          tags: ["Security"],
          summary: "Get user permissions",
          description: "Retrieve current user's permissions",
          operationId: "getPermissions",
          security: [%{BearerAuth: []}],
          responses: %{
            "200" => %{
              description: "User permissions",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/PermissionsResponse"}
                }
              }
            }
          }
        }
      }
    }
  end

  defp websocket_paths do
    %{
      "/api/ws/subscribe" => %{
        post: %{
          tags: ["WebSocket"],
          summary: "Subscribe to events",
          description: "Create a WebSocket subscription for real-time events",
          operationId: "subscribeToEvents",
          security: [%{BearerAuth: []}],
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{"$ref" => "#/components/schemas/SubscriptionRequest"}
              }
            }
          },
          responses: %{
            "200" => %{
              description: "Subscription created",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/SubscriptionResponse"}
                }
              }
            }
          }
        }
      },
      "/api/ws/channels" => %{
        get: %{
          tags: ["WebSocket"],
          summary: "List available channels",
          description: "Get a list of available WebSocket channels",
          operationId: "listChannels",
          responses: %{
            "200" => %{
              description: "List of channels",
              content: %{
                "application/json" => %{
                  schema: %{
                    type: "array",
                    items: %{"$ref" => "#/components/schemas/Channel"}
                  }
                }
              }
            }
          }
        }
      }
    }
  end

  defp vsm_core_paths do
    %{
      "/api/vsm/status" => %{
        get: %{
          tags: ["VSM Core"],
          summary: "Get system status",
          description: "Retrieve the overall VSM system status",
          operationId: "getSystemStatus",
          responses: %{
            "200" => %{
              description: "System status",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/SystemStatus"}
                }
              }
            }
          }
        }
      },
      "/api/vsm/system/{level}" => %{
        get: %{
          tags: ["VSM Core"],
          summary: "Get system level status",
          description: "Retrieve status for a specific VSM system level (1-5)",
          operationId: "getSystemLevelStatus",
          parameters: [
            %{
              name: "level",
              in: "path",
              required: true,
              schema: %{type: "integer", minimum: 1, maximum: 5}
            }
          ],
          responses: %{
            "200" => %{
              description: "System level status",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/SystemLevelStatus"}
                }
              }
            }
          }
        }
      },
      "/api/vsm/algedonic/{signal}" => %{
        post: %{
          tags: ["VSM Core"],
          summary: "Send algedonic signal",
          description: "Send an algedonic signal (pain/pleasure) to the system",
          operationId: "sendAlgedonicSignal",
          parameters: [
            %{
              name: "signal",
              in: "path",
              required: true,
              schema: %{type: "string", enum: ["pain", "pleasure"]}
            }
          ],
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{"$ref" => "#/components/schemas/AlgedonicSignal"}
              }
            }
          },
          responses: %{
            "200" => %{
              description: "Signal processed",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/AlgedonicResponse"}
                }
              }
            }
          }
        }
      }
    }
  end

  defp agent_paths do
    %{
      "/api/vsm/agents" => %{
        get: %{
          tags: ["Agents"],
          summary: "List all agents",
          description: "Retrieve all active S1 agents",
          operationId: "listAgents",
          responses: %{
            "200" => %{
              description: "List of agents",
              content: %{
                "application/json" => %{
                  schema: %{
                    type: "array",
                    items: %{"$ref" => "#/components/schemas/Agent"}
                  }
                }
              }
            }
          }
        },
        post: %{
          tags: ["Agents"],
          summary: "Create new agent",
          description: "Spawn a new S1 agent",
          operationId: "createAgent",
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{"$ref" => "#/components/schemas/AgentInput"}
              }
            }
          },
          responses: %{
            "201" => %{
              description: "Agent created",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/Agent"}
                }
              }
            }
          }
        }
      },
      "/api/vsm/agents/{id}/command" => %{
        post: %{
          tags: ["Agents"],
          summary: "Execute agent command",
          description: "Send a command to a specific agent",
          operationId: "executeAgentCommand",
          parameters: [
            %{
              name: "id",
              in: "path",
              required: true,
              schema: %{type: "string"}
            }
          ],
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{"$ref" => "#/components/schemas/AgentCommand"}
              }
            }
          },
          responses: %{
            "200" => %{
              description: "Command executed",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/CommandResult"}
                }
              }
            }
          }
        }
      }
    }
  end

  defp schemas do
    %{
      Pattern: %{
        type: "object",
        properties: %{
          id: %{type: "string"},
          name: %{type: "string"},
          pattern: %{type: "string"},
          actions: %{type: "array", items: %{type: "string"}},
          created_at: %{type: "string", format: "date-time"}
        }
      },
      PatternInput: %{
        type: "object",
        required: ["name", "pattern", "actions"],
        properties: %{
          name: %{type: "string"},
          pattern: %{type: "string"},
          actions: %{type: "array", items: %{type: "string"}}
        }
      },
      EventInput: %{
        type: "object",
        required: ["type", "data"],
        properties: %{
          type: %{type: "string"},
          data: %{type: "object"},
          metadata: %{type: "object"}
        }
      },
      EventResult: %{
        type: "object",
        properties: %{
          matched_patterns: %{type: "array", items: %{type: "string"}},
          actions_triggered: %{type: "array", items: %{type: "string"}},
          processing_time_ms: %{type: "number"}
        }
      },
      ChatRequest: %{
        type: "object",
        required: ["message"],
        properties: %{
          message: %{type: "string"},
          model: %{type: "string", default: "gpt-4"},
          temperature: %{type: "number", default: 0.7},
          max_tokens: %{type: "integer", default: 1000},
          context: %{type: "array", items: %{type: "object"}}
        }
      },
      ChatResponse: %{
        type: "object",
        properties: %{
          response: %{type: "string"},
          model: %{type: "string"},
          usage: %{
            type: "object",
            properties: %{
              prompt_tokens: %{type: "integer"},
              completion_tokens: %{type: "integer"},
              total_tokens: %{type: "integer"}
            }
          }
        }
      },
      LoginRequest: %{
        type: "object",
        required: ["email", "password"],
        properties: %{
          email: %{type: "string", format: "email"},
          password: %{type: "string", minLength: 8}
        }
      },
      LoginResponse: %{
        type: "object",
        properties: %{
          access_token: %{type: "string"},
          refresh_token: %{type: "string"},
          expires_in: %{type: "integer"},
          user: %{
            type: "object",
            properties: %{
              id: %{type: "string"},
              email: %{type: "string"},
              name: %{type: "string"}
            }
          }
        }
      },
      SubscriptionRequest: %{
        type: "object",
        required: ["channels"],
        properties: %{
          channels: %{type: "array", items: %{type: "string"}},
          filters: %{type: "object"}
        }
      },
      SubscriptionResponse: %{
        type: "object",
        properties: %{
          subscription_id: %{type: "string"},
          ws_url: %{type: "string"},
          channels: %{type: "array", items: %{type: "string"}}
        }
      },
      SystemStatus: %{
        type: "object",
        properties: %{
          status: %{type: "string", enum: ["healthy", "degraded", "critical"]},
          systems: %{
            type: "object",
            properties: %{
              s1: %{type: "object"},
              s2: %{type: "object"},
              s3: %{type: "object"},
              s4: %{type: "object"},
              s5: %{type: "object"}
            }
          },
          timestamp: %{type: "string", format: "date-time"}
        }
      },
      Agent: %{
        type: "object",
        properties: %{
          id: %{type: "string"},
          name: %{type: "string"},
          type: %{type: "string"},
          status: %{type: "string"},
          capabilities: %{type: "array", items: %{type: "string"}},
          created_at: %{type: "string", format: "date-time"}
        }
      },
      AgentCommand: %{
        type: "object",
        required: ["command"],
        properties: %{
          command: %{type: "string"},
          args: %{type: "array", items: %{type: "string"}},
          timeout: %{type: "integer", default: 30000}
        }
      }
    }
  end

  defp get_examples(endpoint) do
    case endpoint do
      "goldrush_patterns" -> %{
        curl: """
        # List all patterns
        curl -X GET http://localhost:4000/api/goldrush/patterns

        # Create a new pattern
        curl -X POST http://localhost:4000/api/goldrush/patterns \\
          -H "Content-Type: application/json" \\
          -d '{
            "name": "user_login_pattern",
            "pattern": "event.type == 'user.login' && event.data.success == true",
            "actions": ["log_successful_login", "update_last_login"]
          }'
        """,
        javascript: """
        // Using fetch API
        const createPattern = async () => {
          const response = await fetch('http://localhost:4000/api/goldrush/patterns', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              name: 'user_login_pattern',
              pattern: "event.type == 'user.login' && event.data.success == true",
              actions: ['log_successful_login', 'update_last_login']
            })
          });
          return response.json();
        };
        """,
        elixir: """
        # Using HTTPoison
        HTTPoison.post!(
          "http://localhost:4000/api/goldrush/patterns",
          Jason.encode!(%{
            name: "user_login_pattern",
            pattern: "event.type == 'user.login' && event.data.success == true",
            actions: ["log_successful_login", "update_last_login"]
          }),
          [{"Content-Type", "application/json"}]
        )
        """
      }
      
      "llm_chat" -> %{
        curl: """
        # Send a chat message
        curl -X POST http://localhost:4000/api/llm/chat \\
          -H "Content-Type: application/json" \\
          -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \\
          -d '{
            "message": "Explain the Viable System Model",
            "model": "gpt-4",
            "temperature": 0.7,
            "max_tokens": 500
          }'
        """,
        javascript: """
        // Chat with LLM
        const chatWithLLM = async (message) => {
          const response = await fetch('http://localhost:4000/api/llm/chat', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ' + accessToken
            },
            body: JSON.stringify({
              message,
              model: 'gpt-4',
              temperature: 0.7
            })
          });
          return response.json();
        };
        """,
        python: """
        import requests

        def chat_with_llm(message, access_token):
            response = requests.post(
                'http://localhost:4000/api/llm/chat',
                headers={
                    'Content-Type': 'application/json',
                    'Authorization': f'Bearer {access_token}'
                },
                json={
                    'message': message,
                    'model': 'gpt-4',
                    'temperature': 0.7
                }
            )
            return response.json()
        """
      }
      
      "websocket" -> %{
        javascript: """
        // WebSocket subscription example
        const subscribeToEvents = async () => {
          // First, create subscription
          const response = await fetch('http://localhost:4000/api/ws/subscribe', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ' + accessToken
            },
            body: JSON.stringify({
              channels: ['system.alerts', 'vsm.updates'],
              filters: { severity: 'high' }
            })
          });
          
          const { ws_url, subscription_id } = await response.json();
          
          // Connect to WebSocket
          const ws = new WebSocket(ws_url);
          
          ws.onopen = () => {
            console.log('Connected to VSM WebSocket');
            ws.send(JSON.stringify({
              type: 'authenticate',
              subscription_id
            }));
          };
          
          ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            console.log('Received event:', data);
          };
          
          return ws;
        };
        """,
        elixir: """
        # Phoenix Channel client example
        {:ok, socket} = Phoenix.Channels.GenSocketClient.start_link(
          Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,
          "ws://localhost:4000/socket/websocket"
        )

        {:ok, _ref} = Phoenix.Channels.GenSocketClient.join(socket, "vsm:updates", %{})

        # Handle incoming messages
        receive do
          {:channel_event, "vsm:updates", "new_event", payload} ->
            IO.inspect(payload, label: "Received VSM event")
        end
        """
      }
      
      _ -> %{
        message: "No examples available for this endpoint"
      }
    end
  end
end