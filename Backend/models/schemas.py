#
#  schemas.py
#  Athena Backend - Request/Response Models
#
#  Created by Cursor on 10/30/25.
#

from pydantic import BaseModel, Field
from typing import List, Optional, Literal, Dict, Any
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
    # Tool calling parameters
    tools: Optional[List[str]] = Field(default=None, description="List of tool names to make available")
    tool_choice: Optional[str] = Field(default="auto", description="Tool choice: 'auto', 'none', or specific tool name")
    tool_context: Optional[Dict[str, Any]] = Field(default=None, description="Context for tool execution (auth tokens, etc.)")


class ChatResponse(BaseModel):
    """Response from chat completion"""
    content: str
    role: MessageRole = MessageRole.ASSISTANT
    finish_reason: Optional[str] = None
    usage: Optional[dict] = None
    tool_calls: Optional[List[Dict[str, Any]]] = Field(default=None, description="Tool calls made by the assistant")


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


# Tool calling models

class ToolDefinition(BaseModel):
    """Tool definition schema"""
    name: str
    description: str
    parameters: Dict[str, Any]


class ToolCall(BaseModel):
    """Representation of a tool call"""
    id: Optional[str] = None
    tool_name: str
    parameters: Dict[str, Any]


class ToolCallRequest(BaseModel):
    """Request to execute a specific tool"""
    tool_name: str
    parameters: Dict[str, Any]
    context: Optional[Dict[str, Any]] = Field(default=None, description="Context for tool execution (auth tokens, etc.)")


class ToolCallResponse(BaseModel):
    """Response from tool execution"""
    success: bool
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    tool_name: str


class ToolsListResponse(BaseModel):
    """List of available tools"""
    tools: List[ToolDefinition]
    count: int


class TestConnectionRequest(BaseModel):
    """Request to test API connection"""
    provider: Literal["openai", "anthropic"]


class TestConnectionResponse(BaseModel):
    """Response from connection test"""
    success: bool
    provider: str
    message: str
