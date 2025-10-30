#!/usr/bin/env python3
#
#  main.py
#  Athena Backend - FastAPI Server
#
#  Created by Cursor on 10/30/25.
#

import os
import asyncio
from typing import Dict
from fastapi import FastAPI, HTTPException, Header
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
import json

from models.schemas import (
    ChatRequest,
    ChatResponse,
    ErrorResponse,
    HealthResponse,
    ModelsResponse,
    ModelInfo,
    StreamChunk
)
from providers.base import BaseProvider
from providers.openai_provider import OpenAIProvider
from providers.anthropic_provider import AnthropicProvider


# Initialize FastAPI app
app = FastAPI(
    title="Athena AI Service",
    description="Backend service for Athena AI Assistant",
    version="0.1.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict this
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Provider registry
_providers: Dict[str, BaseProvider] = {}


def get_provider(provider_name: str, api_key: str) -> BaseProvider:
    """Get or create provider instance"""
    
    # Create cache key
    cache_key = f"{provider_name}:{api_key[:8]}"
    
    # Return cached provider if available
    if cache_key in _providers:
        return _providers[cache_key]
    
    # Create new provider
    if provider_name == "openai":
        provider = OpenAIProvider(api_key=api_key)
    elif provider_name == "anthropic":
        provider = AnthropicProvider(api_key=api_key)
    else:
        raise HTTPException(status_code=400, detail=f"Unknown provider: {provider_name}")
    
    # Cache provider
    _providers[cache_key] = provider
    
    return provider


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        version="0.1.0",
        providers_available=["openai", "anthropic"]
    )


@app.get("/models", response_model=ModelsResponse)
async def list_models():
    """List available models from all providers"""
    models = []
    
    # OpenAI models
    models.extend([
        ModelInfo(
            id="gpt-5-nano-2025-08-07",
            provider="openai",
            name="GPT-5 Nano",
            context_window=128000,
            supports_streaming=True
        ),
        ModelInfo(
            id="gpt-4-turbo-preview",
            provider="openai",
            name="GPT-4 Turbo",
            context_window=128000,
            supports_streaming=True
        )
    ])
    
    # Anthropic models
    models.extend([
        ModelInfo(
            id="claude-haiku-4-5-20251001",
            provider="anthropic",
            name="Claude Haiku 4.5",
            context_window=200000,
            supports_streaming=True
        ),
        ModelInfo(
            id="claude-3-opus-20240229",
            provider="anthropic",
            name="Claude 3 Opus",
            context_window=200000,
            supports_streaming=True
        )
    ])
    
    return ModelsResponse(models=models)


@app.post("/chat", response_model=ChatResponse)
async def chat_completion(
    request: ChatRequest,
    x_api_key: str = Header(..., alias="X-API-Key")
):
    """
    Non-streaming chat completion endpoint
    
    Headers:
        X-API-Key: Provider API key
    """
    try:
        # Get provider
        provider = get_provider(request.provider, x_api_key)
        
        # Call provider
        response = await provider.chat(
            messages=request.messages,
            model=request.model,
            temperature=request.temperature,
            max_tokens=request.max_tokens,
            top_p=request.top_p
        )
        
        return response
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error="Chat completion failed",
                detail=str(e),
                provider=request.provider
            ).dict()
        )


@app.post("/chat/stream")
async def chat_completion_stream(
    request: ChatRequest,
    x_api_key: str = Header(..., alias="X-API-Key")
):
    """
    Streaming chat completion endpoint
    
    Headers:
        X-API-Key: Provider API key
    
    Returns:
        Server-Sent Events stream of chat chunks
    """
    
    async def event_stream():
        try:
            # Get provider
            provider = get_provider(request.provider, x_api_key)
            
            # Stream response
            async for chunk in provider.stream(
                messages=request.messages,
                model=request.model,
                temperature=request.temperature,
                max_tokens=request.max_tokens,
                top_p=request.top_p
            ):
                # Format as SSE
                data = json.dumps(chunk.dict())
                yield f"data: {data}\n\n"
                
                # Small delay to prevent overwhelming the client
                await asyncio.sleep(0.01)
            
            # Send done signal
            yield "data: [DONE]\n\n"
            
        except Exception as e:
            error = ErrorResponse(
                error="Streaming failed",
                detail=str(e),
                provider=request.provider
            )
            yield f"data: {json.dumps({'error': error.dict()})}\n\n"
    
    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no"
        }
    )


@app.post("/test-connection")
async def test_connection(
    provider: str,
    x_api_key: str = Header(..., alias="X-API-Key")
):
    """
    Test API key validity for a provider
    
    Headers:
        X-API-Key: Provider API key
    """
    try:
        # Get provider
        test_provider = get_provider(provider, x_api_key)
        
        # Try a minimal request
        from models.schemas import ChatMessage, MessageRole
        test_messages = [
            ChatMessage(role=MessageRole.USER, content="Hello")
        ]
        
        # Get default model for provider
        if provider == "openai":
            test_model = "gpt-5-nano-2025-08-07"
        elif provider == "anthropic":
            test_model = "claude-haiku-4-5-20251001"
        else:
            raise HTTPException(status_code=400, detail=f"Unknown provider: {provider}")
        
        # Make test request with minimal tokens
        await test_provider.chat(
            messages=test_messages,
            model=test_model,
            max_tokens=5
        )
        
        return {
            "status": "success",
            "message": f"{provider.capitalize()} API key is valid",
            "provider": provider
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=401,
            detail=ErrorResponse(
                error="Invalid API key",
                detail=str(e),
                provider=provider
            ).dict()
        )


if __name__ == "__main__":
    import uvicorn
    
    port = int(os.getenv("PORT", "8000"))
    
    print(f"Starting Athena AI Service on port {port}...")
    print("Available providers: OpenAI, Anthropic")
    print("\nEndpoints:")
    print(f"  - GET  http://localhost:{port}/health")
    print(f"  - GET  http://localhost:{port}/models")
    print(f"  - POST http://localhost:{port}/chat")
    print(f"  - POST http://localhost:{port}/chat/stream")
    print(f"  - POST http://localhost:{port}/test-connection")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info"
    )

