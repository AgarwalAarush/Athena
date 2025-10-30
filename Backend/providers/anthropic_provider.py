#
#  anthropic_provider.py
#  Athena Backend - Anthropic (Claude) Provider Implementation
#
#  Created by Cursor on 10/30/25.
#

from typing import List, AsyncIterator
from anthropic import AsyncAnthropic
from providers.base import BaseProvider
from models.schemas import ChatMessage, ChatResponse, StreamChunk, MessageRole


class AnthropicProvider(BaseProvider):
    """Anthropic (Claude) API provider implementation"""
    
    def __init__(self, api_key: str):
        super().__init__(api_key)
        self.client = AsyncAnthropic(api_key=api_key)
        self._models = [
            "claude-haiku-4-5-20251001",
            "claude-3-opus-20240229",
            "claude-3-sonnet-20240229",
            "claude-3-haiku-20240307"
        ]
    
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
        
        # Extract system message if present
        system_message = None
        chat_messages = []
        
        for msg in messages:
            if msg.role == MessageRole.SYSTEM:
                system_message = msg.content
            else:
                chat_messages.append({
                    "role": msg.role.value,
                    "content": msg.content
                })
        
        # Create message request
        request_params = {
            "model": model,
            "messages": chat_messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "top_p": top_p
        }
        
        if system_message:
            request_params["system"] = system_message
        
        response = await self.client.messages.create(**request_params)
        
        # Extract content from response
        content = ""
        if response.content:
            for block in response.content:
                if hasattr(block, 'text'):
                    content += block.text
        
        return ChatResponse(
            content=content,
            role=MessageRole.ASSISTANT,
            finish_reason=response.stop_reason,
            usage={
                "prompt_tokens": response.usage.input_tokens,
                "completion_tokens": response.usage.output_tokens,
                "total_tokens": response.usage.input_tokens + response.usage.output_tokens
            }
        )
    
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
        
        # Extract system message if present
        system_message = None
        chat_messages = []
        
        for msg in messages:
            if msg.role == MessageRole.SYSTEM:
                system_message = msg.content
            else:
                chat_messages.append({
                    "role": msg.role.value,
                    "content": msg.content
                })
        
        # Create streaming request
        request_params = {
            "model": model,
            "messages": chat_messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "top_p": top_p
        }
        
        if system_message:
            request_params["system"] = system_message
        
        async with self.client.messages.stream(**request_params) as stream:
            async for text in stream.text_stream:
                yield StreamChunk(delta=text, finish_reason=None)
            
            # Get final message to check stop reason
            final_message = await stream.get_final_message()
            if final_message.stop_reason:
                yield StreamChunk(delta="", finish_reason=final_message.stop_reason)
    
    def get_models(self) -> List[str]:
        """Get available models"""
        return self._models
    
    @property
    def provider_name(self) -> str:
        return "anthropic"

