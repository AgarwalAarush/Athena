"""
OpenAI-specific tool adapter for function calling.
"""
from typing import Any, Dict, List
from tool_adapters.base_adapter import BaseToolAdapter
from tools.base import BaseTool


class OpenAIAdapter(BaseToolAdapter):
    """
    Adapter for OpenAI's function calling format.

    OpenAI uses a specific format for tools/functions:
    - Tools are defined with "type": "function" wrapper
    - Function includes name, description, and parameters (JSON Schema)
    - Tool calls include an ID, function name, and arguments
    - Results reference the tool_call_id
    """

    @property
    def provider_name(self) -> str:
        return "openai"

    def format_tools(self, tools: List[BaseTool]) -> List[Dict[str, Any]]:
        """
        Convert BaseTool instances to OpenAI function calling format.

        OpenAI format:
        {
            "type": "function",
            "function": {
                "name": "...",
                "description": "...",
                "parameters": {...}  # JSON Schema
            }
        }
        """
        formatted_tools = []

        for tool in tools:
            formatted_tools.append({
                "type": "function",
                "function": {
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": tool.parameters_schema
                }
            })

        return formatted_tools

    def parse_tool_calls(self, response: Any) -> List[Dict[str, Any]]:
        """
        Extract tool calls from OpenAI chat completion response.

        OpenAI response structure:
        response.choices[0].message.tool_calls = [
            {
                "id": "call_xyz123",
                "type": "function",
                "function": {
                    "name": "tool_name",
                    "arguments": "{...}"  # JSON string
                }
            }
        ]
        """
        tool_calls = []

        # Check if response has tool calls
        if not hasattr(response, 'choices') or len(response.choices) == 0:
            return tool_calls

        message = response.choices[0].message

        if not hasattr(message, 'tool_calls') or message.tool_calls is None:
            return tool_calls

        # Parse each tool call
        for tool_call in message.tool_calls:
            import json

            # Parse arguments from JSON string
            try:
                arguments = json.loads(tool_call.function.arguments)
            except json.JSONDecodeError:
                # If parsing fails, use empty dict
                arguments = {}

            tool_calls.append({
                "id": tool_call.id,
                "tool_name": tool_call.function.name,
                "parameters": arguments
            })

        return tool_calls

    def format_tool_results(
        self,
        tool_results: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """
        Format tool execution results for OpenAI.

        OpenAI expects tool results as messages with role="tool":
        {
            "role": "tool",
            "tool_call_id": "call_xyz123",
            "content": "..."  # JSON string of result
        }
        """
        import json

        formatted_results = []

        for result in tool_results:
            # Convert result to JSON string
            content = json.dumps(result.get("result", {}))

            formatted_results.append({
                "role": "tool",
                "tool_call_id": result.get("tool_call_id", ""),
                "content": content
            })

        return formatted_results

    def supports_streaming(self) -> bool:
        """OpenAI supports streaming tool calls."""
        return True

    def parse_streaming_tool_calls(self, delta: Any) -> Dict[str, Any]:
        """
        Parse tool calls from streaming delta (OpenAI specific).

        Args:
            delta: The delta object from a streaming response

        Returns:
            Dictionary with partial tool call information
        """
        if not hasattr(delta, 'tool_calls') or delta.tool_calls is None:
            return {}

        # OpenAI sends tool calls incrementally
        # We'll collect them and return the current state
        tool_calls_data = []

        for tool_call in delta.tool_calls:
            call_data = {
                "index": tool_call.index if hasattr(tool_call, 'index') else 0
            }

            if hasattr(tool_call, 'id') and tool_call.id:
                call_data["id"] = tool_call.id

            if hasattr(tool_call, 'function'):
                function_data = {}
                if hasattr(tool_call.function, 'name') and tool_call.function.name:
                    function_data["name"] = tool_call.function.name
                if hasattr(tool_call.function, 'arguments') and tool_call.function.arguments:
                    function_data["arguments"] = tool_call.function.arguments

                call_data["function"] = function_data

            tool_calls_data.append(call_data)

        return {
            "tool_calls": tool_calls_data
        }
