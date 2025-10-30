"""
Base tool protocol defining the interface all tools must implement.
"""
from abc import ABC, abstractmethod
from typing import Any, Dict, Optional


class BaseTool(ABC):
    """
    Abstract base class for all tools.

    Similar to BaseProvider, this defines the contract that all tool
    implementations must follow.
    """

    @property
    @abstractmethod
    def name(self) -> str:
        """
        The unique identifier for this tool.
        Used by AI providers and the registry to reference the tool.
        """
        pass

    @property
    @abstractmethod
    def description(self) -> str:
        """
        Human-readable description of what this tool does.
        Sent to AI models to help them decide when to use the tool.
        """
        pass

    @property
    @abstractmethod
    def parameters_schema(self) -> Dict[str, Any]:
        """
        JSON Schema defining the parameters this tool accepts.

        Format follows JSON Schema specification:
        {
            "type": "object",
            "properties": {
                "param_name": {
                    "type": "string",
                    "description": "What this parameter does"
                }
            },
            "required": ["param_name"]
        }
        """
        pass

    @abstractmethod
    async def execute(
        self,
        parameters: Dict[str, Any],
        context: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Execute the tool with the given parameters.

        Args:
            parameters: The parameters for this tool invocation (validated against schema)
            context: Optional context including auth tokens, user preferences, etc.
                    Common keys:
                    - "google_access_token": For Google API access
                    - "user_id": For user-specific operations
                    - "api_key": For third-party API access

        Returns:
            Dictionary containing:
            - "success": bool indicating if execution succeeded
            - "result": The actual result data (if successful)
            - "error": Error message (if failed)
        """
        pass

    def validate_parameters(self, parameters: Dict[str, Any]) -> bool:
        """
        Validate parameters against the schema.

        Default implementation does basic required field checking.
        Override for more complex validation.
        """
        schema = self.parameters_schema
        required = schema.get("required", [])

        # Check all required fields are present
        for field in required:
            if field not in parameters:
                return False

        return True
