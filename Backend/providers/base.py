#
#  base.py
#  Athena Backend - Base Provider Protocol
#
#  Created by Cursor on 10/30/25.
#

from abc import ABC, abstractmethod
from typing import List, AsyncIterator, Optional
from models.schemas import ChatMessage, ChatResponse, StreamChunk


class BaseProvider(ABC):
    """Abstract base class for AI providers"""
    
    def __init__(self, api_key: str):
        self.api_key = api_key
    
    @abstractmethod
    async def chat(
        self,
        messages: List[ChatMessage],
        model: str,
        temperature: float = 0.7,
        max_tokens: int = 2048,
        top_p: float = 1.0,
        **kwargs
    ) -> ChatResponse:
        """Non-streaming chat completion"""
        pass
    
    @abstractmethod
    async def stream(
        self,
        messages: List[ChatMessage],
        model: str,
        temperature: float = 0.7,
        max_tokens: int = 2048,
        top_p: float = 1.0,
        **kwargs
    ) -> AsyncIterator[StreamChunk]:
        """Streaming chat completion"""
        pass
    
    @abstractmethod
    def get_models(self) -> List[str]:
        """Get available models for this provider"""
        pass
    
    @property
    @abstractmethod
    def provider_name(self) -> str:
        """Provider name identifier"""
        pass

