"""
Tool registry for managing and discovering available tools.
"""
from typing import Dict, List, Optional
from tools.base import BaseTool


class ToolRegistry:
    """
    Singleton registry for all available tools.

    Provides centralized tool management, discovery, and retrieval.
    Tools must be registered before they can be used.
    """

    _instance: Optional["ToolRegistry"] = None
    _tools: Dict[str, BaseTool] = {}

    def __new__(cls):
        """Singleton pattern - ensure only one registry exists."""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._tools = {}
        return cls._instance

    def register_tool(self, tool: BaseTool) -> None:
        """
        Register a tool in the registry.

        Args:
            tool: The tool instance to register

        Raises:
            ValueError: If a tool with the same name is already registered
        """
        if tool.name in self._tools:
            raise ValueError(f"Tool '{tool.name}' is already registered")

        self._tools[tool.name] = tool

    def unregister_tool(self, tool_name: str) -> None:
        """
        Remove a tool from the registry.

        Args:
            tool_name: Name of the tool to remove
        """
        if tool_name in self._tools:
            del self._tools[tool_name]

    def get_tool(self, tool_name: str) -> Optional[BaseTool]:
        """
        Retrieve a tool by name.

        Args:
            tool_name: Name of the tool to retrieve

        Returns:
            The tool instance, or None if not found
        """
        return self._tools.get(tool_name)

    def list_tools(self) -> List[str]:
        """
        Get a list of all registered tool names.

        Returns:
            List of tool names
        """
        return list(self._tools.keys())

    def get_all_tools(self) -> Dict[str, BaseTool]:
        """
        Get all registered tools.

        Returns:
            Dictionary mapping tool names to tool instances
        """
        return self._tools.copy()

    def get_tool_schemas(self) -> List[Dict]:
        """
        Get schemas for all registered tools.

        Useful for generating API documentation or provider tool definitions.

        Returns:
            List of tool schema dictionaries with name, description, and parameters
        """
        schemas = []
        for tool_name, tool in self._tools.items():
            schemas.append({
                "name": tool.name,
                "description": tool.description,
                "parameters": tool.parameters_schema
            })
        return schemas

    def clear(self) -> None:
        """
        Clear all registered tools.
        Primarily used for testing.
        """
        self._tools.clear()


# Global registry instance
_registry = ToolRegistry()


def get_registry() -> ToolRegistry:
    """
    Get the global tool registry instance.

    Returns:
        The singleton ToolRegistry instance
    """
    return _registry
