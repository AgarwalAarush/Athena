# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Python FastAPI backend service** for Athena AI Assistant - a macOS floating utility window chat application. The backend provides a unified HTTP API for multiple AI providers (OpenAI, Anthropic) with both streaming and non-streaming chat completions.

## Commands

### Development

```bash
# Install dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Run development server
python main.py
# Server runs on http://localhost:8000 by default
# Port can be configured via PORT environment variable
```

### Testing

```bash
# Health check
curl http://localhost:8000/health

# List available models
curl http://localhost:8000/models

# Test API key validity
curl -X POST http://localhost:8000/test-connection \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"provider": "openai"}'

# Non-streaming chat
curl -X POST http://localhost:8000/chat \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "openai",
    "model": "gpt-5-nano-2025-08-07",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## Architecture

### Provider System

The backend uses a **provider abstraction pattern** that makes adding new AI providers straightforward:

1. **BaseProvider** (`providers/base.py`): Abstract protocol defining required methods
   - `chat()`: Non-streaming completion
   - `stream()`: Streaming completion with AsyncIterator
   - `get_models()`: List available models
   - `provider_name`: Provider identifier property

2. **Provider Implementations**:
   - `OpenAIProvider` (`providers/openai_provider.py`): OpenAI GPT models
   - `AnthropicProvider` (`providers/anthropic_provider.py`): Claude models
   - Future: `OllamaProvider` for local models

3. **Provider Registry** (`main.py`):
   - Providers are cached by `{provider_name}:{api_key_prefix}` to reuse client instances
   - Retrieved via `get_provider(provider_name, api_key)` helper function

### Request/Response Flow

1. Client sends request to FastAPI endpoint with `X-API-Key` header
2. `get_provider()` returns cached or creates new provider instance with API key
3. Provider translates request to vendor-specific format
4. Provider handles response streaming or completion
5. Response formatted as standardized `ChatResponse` or `StreamChunk` models

### Streaming Implementation

- **Non-streaming** (`/chat`): Standard HTTP POST returning `ChatResponse`
- **Streaming** (`/chat/stream`): Server-Sent Events (SSE) format
  - Each chunk: `data: {json}\n\n`
  - Final signal: `data: [DONE]\n\n`
  - 10ms delay between chunks to prevent overwhelming client
  - Headers: `Cache-Control: no-cache`, `Connection: keep-alive`, `X-Accel-Buffering: no`

## Important Implementation Details

### Anthropic System Messages

Anthropic API requires system messages to be sent separately from chat messages. The `AnthropicProvider` extracts system messages from the message list and passes them via the `system` parameter (see `anthropic_provider.py:38-61`).

### OpenAI Message Format

OpenAI accepts system/user/assistant messages in a unified array. No special handling needed beyond role conversion (see `openai_provider.py:38-42`).

### Provider Caching

The `_providers` dictionary in `main.py:48` caches provider instances to avoid recreating API clients for every request. Cache key includes first 8 characters of API key to support multiple accounts.

### Error Handling

All endpoints wrap provider calls in try/except blocks and return structured `ErrorResponse` with HTTP status codes. The `/test-connection` endpoint specifically uses 401 for invalid API keys.

## Data Models

All request/response schemas are defined in `models/schemas.py` using Pydantic:

- `ChatRequest`: Incoming chat request with provider, model, messages, and parameters
- `ChatResponse`: Completed chat response with content, role, finish_reason, and usage
- `StreamChunk`: Streaming delta with optional finish_reason
- `ChatMessage`: Individual message with role and content
- `MessageRole`: Enum (USER, ASSISTANT, SYSTEM)
- `ErrorResponse`: Structured error with detail and provider context
- `HealthResponse`: Service health status
- `ModelInfo`: Model metadata
- `ModelsResponse`: List of available models

## Adding a New Provider

To add a new AI provider (e.g., Ollama):

1. Create `providers/ollama_provider.py`
2. Inherit from `BaseProvider`
3. Implement required methods: `chat()`, `stream()`, `get_models()`, `provider_name`
4. Add provider instantiation in `main.py:get_provider()` (around line 62)
5. Update `health_check()` to include new provider in `providers_available` list
6. Add model definitions to `/models` endpoint

## Integration with Swift Frontend

The Swift app (`Athena` macOS application) communicates with this backend via:

- `AIService.swift`: HTTP client for backend communication
- `NetworkClient.swift`: Generic HTTP/SSE streaming support
- API keys passed via `X-API-Key` header (retrieved from macOS Keychain)
- Streaming responses consumed as SSE and displayed in real-time

The backend is designed to run locally during development. Future production builds will embed the Python service in the .app bundle.

## Configuration

- **Port**: Default 8000, configurable via `PORT` environment variable
- **Host**: Binds to `0.0.0.0` to allow Swift app connection
- **CORS**: Currently allows all origins (`allow_origins=["*"]`) - restrict in production
- **API Keys**: Never stored server-side, always passed per-request via headers

## Current Models

### OpenAI
- `gpt-5-nano-2025-08-07` (default)
- `gpt-4-turbo-preview`
- `gpt-4`
- `gpt-3.5-turbo`

### Anthropic
- `claude-haiku-4-5-20251001` (default)
- `claude-3-opus-20240229`
- `claude-3-sonnet-20240229`
- `claude-3-haiku-20240307`

## Dependencies

- **FastAPI**: Web framework with async support
- **Uvicorn**: ASGI server with HTTP/2 and WebSocket support
- **Pydantic**: Request/response validation
- **OpenAI SDK**: `openai` package for GPT models
- **Anthropic SDK**: `anthropic` package for Claude models
- **HTTPX**: Async HTTP client (dependency of FastAPI/SDKs)
- **python-dotenv**: Environment variable loading (optional)
