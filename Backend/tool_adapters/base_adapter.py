"""
Base tool adapter protocol for provider-specific tool calling translation.
"""
from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional
from tools.base import BaseTool


class BaseToolAdapter(ABC):
    """
    Abstract base class for tool adapters.

    Each AI provider (OpenAI, Anthropic, etc.) has its own format for
    function/tool calling. Adapters translate our generic tool definitions
    to provider-specific formats and parse provider responses back to
    a common format.
    """

    @abstractmethod
    def format_tools(self, tools: List[BaseTool]) -> List[Dict[str, Any]]:
        """
        Convert BaseTool instances to provider-specific tool definitions.

        Args:
            tools: List of BaseTool instances to convert

        Returns:
            List of tool definitions in provider-specific format

        Example (OpenAI):
            [
                {
                    "type": "function",
                    "function": {
                        "name": "tool_name",
                        "description": "...",
                        "parameters": {...}
                    }
                }
            ]

        Example (Anthropic):
            [
                {
                    "name": "tool_name",
                    "description": "...",
                    "input_schema": {...}
                }
            ]
        """
        pass

    @abstractmethod
    def parse_tool_calls(self, response: Any) -> List[Dict[str, Any]]:
        """
        Extract tool calls from provider response.

        Args:
            response: Provider-specific response object

        Returns:
            List of tool calls in standardized format:
            [
                {
                    "id": "call_id",  # Optional, provider-specific
                    "tool_name": "name_of_tool",
                    "parameters": {...}
                }
            ]
        """
        pass

    @abstractmethod
    def format_tool_results(
        self,
        tool_results: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """
        Format tool execution results for sending back to the provider.

        Args:
            tool_results: List of tool execution results in format:
                [
                    {
                        "tool_call_id": "call_id",  # Optional
                        "tool_name": "name",
                        "result": {...}
                    }
                ]

        Returns:
            List of formatted results in provider-specific format
        """
        pass

    @abstractmethod
    def supports_streaming(self) -> bool:
        """
        Whether this adapter supports streaming tool calls.

        Returns:
            True if streaming is supported, False otherwise
        """
        pass

    @property
    @abstractmethod
    def provider_name(self) -> str:
        """
        The name of the provider this adapter is for.

        Returns:
            Provider name (e.g., "openai", "anthropic")
        """
        pass
