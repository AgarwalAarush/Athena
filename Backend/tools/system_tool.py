"""
System operations tool for macOS.
Handles file operations, system controls (brightness, volume), and app management.
"""
import os
import subprocess
import shutil
from pathlib import Path
from typing import Any, Dict, Optional, List
from tools.base import BaseTool


class SystemTool(BaseTool):
    """
    Tool for performing system operations on macOS.

    Supports:
    - File operations: create, read, edit, delete, list files
    - System controls: brightness, volume control
    - App management: open, close, list running apps
    """

    @property
    def name(self) -> str:
        return "system"

    @property
    def description(self) -> str:
        return (
            "Perform system operations including file management (create, read, edit, delete files), "
            "system controls (brightness, volume), and application management (open, close, list apps). "
            "All file paths should be absolute paths."
        )

    @property
    def parameters_schema(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": [
                        "create_file", "read_file", "edit_file", "delete_file", "list_files",
                        "set_brightness", "get_brightness", "set_volume", "get_volume",
                        "open_app", "close_app", "list_running_apps", "activate_app"
                    ],
                    "description": "The system action to perform"
                },
                # File operation parameters
                "file_path": {
                    "type": "string",
                    "description": "Absolute path to the file (required for file operations)"
                },
                "content": {
                    "type": "string",
                    "description": "File content (for create_file and edit_file)"
                },
                "directory": {
                    "type": "string",
                    "description": "Directory path (for list_files)"
                },
                "pattern": {
                    "type": "string",
                    "description": "File pattern to match (e.g., '*.txt' for list_files)"
                },
                # System control parameters
                "brightness": {
                    "type": "number",
                    "description": "Brightness level (0.0 to 1.0 for set_brightness)",
                    "minimum": 0.0,
                    "maximum": 1.0
                },
                "volume": {
                    "type": "number",
                    "description": "Volume level (0 to 100 for set_volume)",
                    "minimum": 0,
                    "maximum": 100
                },
                # App management parameters
                "app_name": {
                    "type": "string",
                    "description": "Application name (for open_app, close_app, activate_app)"
                }
            },
            "required": ["action"]
        }

    async def execute(
        self,
        parameters: Dict[str, Any],
        context: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Execute a system operation.

        Args:
            parameters: Action-specific parameters
            context: Optional context (not currently used for system operations)

        Returns:
            Result dictionary with success status and data/error
        """
        action = parameters["action"]

        try:
            # Route to appropriate handler
            if action == "create_file":
                return await self._create_file(parameters)
            elif action == "read_file":
                return await self._read_file(parameters)
            elif action == "edit_file":
                return await self._edit_file(parameters)
            elif action == "delete_file":
                return await self._delete_file(parameters)
            elif action == "list_files":
                return await self._list_files(parameters)
            elif action == "set_brightness":
                return await self._set_brightness(parameters)
            elif action == "get_brightness":
                return await self._get_brightness(parameters)
            elif action == "set_volume":
                return await self._set_volume(parameters)
            elif action == "get_volume":
                return await self._get_volume(parameters)
            elif action == "open_app":
                return await self._open_app(parameters)
            elif action == "close_app":
                return await self._close_app(parameters)
            elif action == "list_running_apps":
                return await self._list_running_apps(parameters)
            elif action == "activate_app":
                return await self._activate_app(parameters)
            else:
                return {
                    "success": False,
                    "error": f"Unknown action: {action}"
                }

        except Exception as e:
            return {
                "success": False,
                "error": f"Error executing {action}: {str(e)}"
            }

    # File Operations

    async def _create_file(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new file with content."""
        if "file_path" not in parameters:
            return {"success": False, "error": "file_path required"}

        file_path = Path(parameters["file_path"])
        content = parameters.get("content", "")

        # Create parent directories if needed
        file_path.parent.mkdir(parents=True, exist_ok=True)

        # Write file
        file_path.write_text(content, encoding="utf-8")

        return {
            "success": True,
            "result": {
                "file_path": str(file_path),
                "size_bytes": file_path.stat().st_size,
                "message": "File created successfully"
            }
        }

    async def _read_file(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Read file contents."""
        if "file_path" not in parameters:
            return {"success": False, "error": "file_path required"}

        file_path = Path(parameters["file_path"])

        if not file_path.exists():
            return {"success": False, "error": f"File not found: {file_path}"}

        if not file_path.is_file():
            return {"success": False, "error": f"Not a file: {file_path}"}

        content = file_path.read_text(encoding="utf-8")

        return {
            "success": True,
            "result": {
                "file_path": str(file_path),
                "content": content,
                "size_bytes": file_path.stat().st_size
            }
        }

    async def _edit_file(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Edit/replace file contents."""
        if "file_path" not in parameters or "content" not in parameters:
            return {"success": False, "error": "file_path and content required"}

        file_path = Path(parameters["file_path"])

        if not file_path.exists():
            return {"success": False, "error": f"File not found: {file_path}"}

        # Write new content
        file_path.write_text(parameters["content"], encoding="utf-8")

        return {
            "success": True,
            "result": {
                "file_path": str(file_path),
                "size_bytes": file_path.stat().st_size,
                "message": "File edited successfully"
            }
        }

    async def _delete_file(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Delete a file."""
        if "file_path" not in parameters:
            return {"success": False, "error": "file_path required"}

        file_path = Path(parameters["file_path"])

        if not file_path.exists():
            return {"success": False, "error": f"File not found: {file_path}"}

        if file_path.is_dir():
            shutil.rmtree(file_path)
            message = "Directory deleted successfully"
        else:
            file_path.unlink()
            message = "File deleted successfully"

        return {
            "success": True,
            "result": {
                "file_path": str(file_path),
                "message": message
            }
        }

    async def _list_files(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """List files in a directory."""
        directory = Path(parameters.get("directory", "."))
        pattern = parameters.get("pattern", "*")

        if not directory.exists():
            return {"success": False, "error": f"Directory not found: {directory}"}

        if not directory.is_dir():
            return {"success": False, "error": f"Not a directory: {directory}"}

        # List files matching pattern
        files = []
        for path in directory.glob(pattern):
            files.append({
                "name": path.name,
                "path": str(path),
                "is_dir": path.is_dir(),
                "size_bytes": path.stat().st_size if path.is_file() else None,
                "modified": path.stat().st_mtime
            })

        return {
            "success": True,
            "result": {
                "directory": str(directory),
                "pattern": pattern,
                "files": files,
                "count": len(files)
            }
        }

    # System Controls

    async def _set_brightness(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Set screen brightness (macOS)."""
        if "brightness" not in parameters:
            return {"success": False, "error": "brightness required (0.0 to 1.0)"}

        brightness = parameters["brightness"]

        # Use AppleScript to set brightness
        script = f'''
        tell application "System Events"
            tell appearance preferences
                set dark mode to false
            end tell
        end tell
        do shell script "brightness {brightness}"
        '''

        try:
            subprocess.run(
                ["osascript", "-e", f"tell application \"System Events\" to set brightness to {brightness}"],
                check=True,
                capture_output=True,
                text=True
            )

            return {
                "success": True,
                "result": {
                    "brightness": brightness,
                    "message": f"Brightness set to {brightness * 100:.0f}%"
                }
            }
        except subprocess.CalledProcessError as e:
            # Try alternative method using brightness command if installed
            try:
                subprocess.run(
                    ["brightness", str(brightness)],
                    check=True,
                    capture_output=True
                )
                return {
                    "success": True,
                    "result": {
                        "brightness": brightness,
                        "message": f"Brightness set to {brightness * 100:.0f}%"
                    }
                }
            except:
                return {
                    "success": False,
                    "error": "Could not set brightness. Install 'brightness' command or grant permissions."
                }

    async def _get_brightness(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Get current screen brightness (macOS)."""
        try:
            # Try using brightness command
            result = subprocess.run(
                ["brightness", "-l"],
                capture_output=True,
                text=True,
                check=True
            )

            # Parse output (format: "display 0: brightness 0.5")
            output = result.stdout.strip()
            brightness = float(output.split("brightness")[1].strip())

            return {
                "success": True,
                "result": {
                    "brightness": brightness,
                    "percentage": brightness * 100
                }
            }
        except:
            return {
                "success": False,
                "error": "Could not get brightness. Install 'brightness' command."
            }

    async def _set_volume(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Set system volume (macOS)."""
        if "volume" not in parameters:
            return {"success": False, "error": "volume required (0 to 100)"}

        volume = parameters["volume"]

        script = f"set volume output volume {volume}"

        try:
            subprocess.run(
                ["osascript", "-e", script],
                check=True,
                capture_output=True,
                text=True
            )

            return {
                "success": True,
                "result": {
                    "volume": volume,
                    "message": f"Volume set to {volume}%"
                }
            }
        except subprocess.CalledProcessError as e:
            return {
                "success": False,
                "error": f"Could not set volume: {e.stderr}"
            }

    async def _get_volume(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Get current system volume (macOS)."""
        script = "output volume of (get volume settings)"

        try:
            result = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True,
                text=True,
                check=True
            )

            volume = int(result.stdout.strip())

            return {
                "success": True,
                "result": {
                    "volume": volume
                }
            }
        except subprocess.CalledProcessError as e:
            return {
                "success": False,
                "error": f"Could not get volume: {e.stderr}"
            }

    # App Management

    async def _open_app(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Open/launch an application."""
        if "app_name" not in parameters:
            return {"success": False, "error": "app_name required"}

        app_name = parameters["app_name"]
        script = f'tell application "{app_name}" to activate'

        try:
            subprocess.run(
                ["osascript", "-e", script],
                check=True,
                capture_output=True,
                text=True
            )

            return {
                "success": True,
                "result": {
                    "app_name": app_name,
                    "message": f"Application '{app_name}' opened"
                }
            }
        except subprocess.CalledProcessError as e:
            return {
                "success": False,
                "error": f"Could not open '{app_name}': {e.stderr}"
            }

    async def _close_app(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Close/quit an application."""
        if "app_name" not in parameters:
            return {"success": False, "error": "app_name required"}

        app_name = parameters["app_name"]
        script = f'tell application "{app_name}" to quit'

        try:
            subprocess.run(
                ["osascript", "-e", script],
                check=True,
                capture_output=True,
                text=True
            )

            return {
                "success": True,
                "result": {
                    "app_name": app_name,
                    "message": f"Application '{app_name}' closed"
                }
            }
        except subprocess.CalledProcessError as e:
            return {
                "success": False,
                "error": f"Could not close '{app_name}': {e.stderr}"
            }

    async def _activate_app(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Activate (bring to front) an application."""
        if "app_name" not in parameters:
            return {"success": False, "error": "app_name required"}

        app_name = parameters["app_name"]
        script = f'tell application "{app_name}" to activate'

        try:
            subprocess.run(
                ["osascript", "-e", script],
                check=True,
                capture_output=True,
                text=True
            )

            return {
                "success": True,
                "result": {
                    "app_name": app_name,
                    "message": f"Application '{app_name}' activated"
                }
            }
        except subprocess.CalledProcessError as e:
            return {
                "success": False,
                "error": f"Could not activate '{app_name}': {e.stderr}"
            }

    async def _list_running_apps(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """List all currently running applications."""
        script = '''
        tell application "System Events"
            get name of every application process whose background only is false
        end tell
        '''

        try:
            result = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True,
                text=True,
                check=True
            )

            # Parse comma-separated list
            apps_str = result.stdout.strip()
            apps = [app.strip() for app in apps_str.split(", ")]

            return {
                "success": True,
                "result": {
                    "apps": apps,
                    "count": len(apps)
                }
            }
        except subprocess.CalledProcessError as e:
            return {
                "success": False,
                "error": f"Could not list running apps: {e.stderr}"
            }
