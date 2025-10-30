#
#  schemas.py
#  Athena Backend - Request/Response Models
#
#  Created by Cursor on 10/30/25.
#

from pydantic import BaseModel, Field
from typing import List, Optional, Literal
from enum import Enum


class MessageRole(str, Enum):
    """Message role enumeration"""
    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"


class ChatMessage(BaseModel):
    """Individual chat message"""
    role: MessageRole
    content: str


class ChatRequest(BaseModel):
    """Request for chat completion"""
    provider: Literal["openai", "anthropic"]
    model: str
    messages: List[ChatMessage]
    temperature: float = Field(default=0.7, ge=0.0, le=2.0)
    max_tokens: int = Field(default=2048, ge=1, le=100000)
    top_p: float = Field(default=1.0, ge=0.0, le=1.0)
    stream: bool = False


class ChatResponse(BaseModel):
    """Response from chat completion"""
    content: str
    role: MessageRole = MessageRole.ASSISTANT
    finish_reason: Optional[str] = None
    usage: Optional[dict] = None


class StreamChunk(BaseModel):
    """Streaming response chunk"""
    delta: str
    finish_reason: Optional[str] = None


class ErrorResponse(BaseModel):
    """Error response"""
    error: str
    detail: Optional[str] = None
    provider: Optional[str] = None


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    version: str
    providers_available: List[str]


class ModelInfo(BaseModel):
    """Model information"""
    id: str
    provider: str
    name: str
    context_window: int
    supports_streaming: bool


class ModelsResponse(BaseModel):
    """Available models response"""
    models: List[ModelInfo]

