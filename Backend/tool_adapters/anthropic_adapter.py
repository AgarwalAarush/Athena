"""
Anthropic-specific tool adapter for tool use.
"""
from typing import Any, Dict, List
from tool_adapters.base_adapter import BaseToolAdapter
from tools.base import BaseTool


class AnthropicAdapter(BaseToolAdapter):
    """
    Adapter for Anthropic's tool use format.

    Anthropic uses a simpler format compared to OpenAI:
    - Tools have name, description, and input_schema (JSON Schema)
    - Tool use blocks in response content
    - Results sent as tool_result content blocks
    """

    @property
    def provider_name(self) -> str:
        return "anthropic"

    def format_tools(self, tools: List[BaseTool]) -> List[Dict[str, Any]]:
        """
        Convert BaseTool instances to Anthropic tool format.

        Anthropic format:
        {
            "name": "...",
            "description": "...",
            "input_schema": {...}  # JSON Schema
        }
        """
        formatted_tools = []

        for tool in tools:
            formatted_tools.append({
                "name": tool.name,
                "description": tool.description,
                "input_schema": tool.parameters_schema
            })

        return formatted_tools

    def parse_tool_calls(self, response: Any) -> List[Dict[str, Any]]:
        """
        Extract tool calls from Anthropic response.

        Anthropic response structure:
        response.content = [
            {
                "type": "text",
                "text": "..."
            },
            {
                "type": "tool_use",
                "id": "toolu_xyz123",
                "name": "tool_name",
                "input": {...}
            }
        ]
        """
        tool_calls = []

        # Check if response has content
        if not hasattr(response, 'content'):
            return tool_calls

        # Iterate through content blocks
        for block in response.content:
            # Check if this is a tool_use block
            if hasattr(block, 'type') and block.type == 'tool_use':
                tool_calls.append({
                    "id": block.id,
                    "tool_name": block.name,
                    "parameters": block.input
                })

        return tool_calls

    def format_tool_results(
        self,
        tool_results: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """
        Format tool execution results for Anthropic.

        Anthropic expects tool results as content blocks:
        {
            "type": "tool_result",
            "tool_use_id": "toolu_xyz123",
            "content": "..."  # Can be string or structured
        }
        """
        import json

        formatted_results = []

        for result in tool_results:
            # Format result as JSON string
            content = json.dumps(result.get("result", {}))

            formatted_results.append({
                "type": "tool_result",
                "tool_use_id": result.get("tool_call_id", ""),
                "content": content
            })

        return formatted_results

    def supports_streaming(self) -> bool:
        """Anthropic supports streaming tool use."""
        return True

    def parse_streaming_tool_use(self, event: Any) -> Dict[str, Any]:
        """
        Parse tool use from streaming event (Anthropic specific).

        Anthropic streaming sends events like:
        - content_block_start: Indicates new tool_use block starting
        - content_block_delta: Partial input for tool
        - content_block_stop: Tool_use block complete

        Args:
            event: The streaming event

        Returns:
            Dictionary with tool use information
        """
        result = {}

        if not hasattr(event, 'type'):
            return result

        # Handle different event types
        if event.type == 'content_block_start':
            # New content block starting
            if hasattr(event, 'content_block'):
                block = event.content_block
                if hasattr(block, 'type') and block.type == 'tool_use':
                    result = {
                        "event": "tool_use_start",
                        "id": block.id if hasattr(block, 'id') else None,
                        "name": block.name if hasattr(block, 'name') else None
                    }

        elif event.type == 'content_block_delta':
            # Incremental update to content block
            if hasattr(event, 'delta'):
                delta = event.delta
                if hasattr(delta, 'type') and delta.type == 'input_json_delta':
                    result = {
                        "event": "tool_use_delta",
                        "partial_json": delta.partial_json if hasattr(delta, 'partial_json') else ""
                    }

        elif event.type == 'content_block_stop':
            # Content block finished
            result = {
                "event": "tool_use_stop"
            }

        return result

    def create_tool_result_message(
        self,
        tool_results: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Create a complete message with tool results for Anthropic.

        Anthropic requires tool results to be sent as a user message
        with tool_result content blocks.

        Args:
            tool_results: List of tool execution results

        Returns:
            Message dictionary with role and content
        """
        content_blocks = self.format_tool_results(tool_results)

        return {
            "role": "user",
            "content": content_blocks
        }
