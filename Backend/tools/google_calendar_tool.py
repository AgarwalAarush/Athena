"""
Google Calendar integration tool.
"""
from datetime import datetime
from typing import Any, Dict, Optional
from tools.base import BaseTool

try:
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
except ImportError:
    # Dependencies not installed - will fail at runtime if used
    pass


class GoogleCalendarTool(BaseTool):
    """
    Tool for interacting with Google Calendar API.

    Supports listing, creating, updating, and deleting calendar events.
    Requires Google access token passed via context.
    """

    @property
    def name(self) -> str:
        return "google_calendar"

    @property
    def description(self) -> str:
        return (
            "Interact with Google Calendar to list, create, update, and delete events. "
            "Supports searching events by date range, creating new events with attendees, "
            "updating existing events, and deleting events."
        )

    @property
    def parameters_schema(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["list_events", "create_event", "update_event", "delete_event", "search_events"],
                    "description": "The calendar action to perform"
                },
                "time_min": {
                    "type": "string",
                    "description": "Start time for listing/searching events (ISO 8601 format, e.g., '2024-01-01T00:00:00Z')"
                },
                "time_max": {
                    "type": "string",
                    "description": "End time for listing/searching events (ISO 8601 format)"
                },
                "max_results": {
                    "type": "integer",
                    "description": "Maximum number of events to return (default: 10, max: 250)",
                    "default": 10
                },
                "event_id": {
                    "type": "string",
                    "description": "ID of the event (required for update_event and delete_event)"
                },
                "summary": {
                    "type": "string",
                    "description": "Event title/summary (required for create_event)"
                },
                "description": {
                    "type": "string",
                    "description": "Event description/details"
                },
                "start_time": {
                    "type": "string",
                    "description": "Event start time (ISO 8601 format, required for create_event)"
                },
                "end_time": {
                    "type": "string",
                    "description": "Event end time (ISO 8601 format, required for create_event)"
                },
                "attendees": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "List of attendee email addresses"
                },
                "location": {
                    "type": "string",
                    "description": "Event location"
                },
                "query": {
                    "type": "string",
                    "description": "Search query for finding events"
                },
                "calendar_id": {
                    "type": "string",
                    "description": "Calendar ID (default: 'primary')",
                    "default": "primary"
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
        Execute a Google Calendar operation.

        Args:
            parameters: Action-specific parameters
            context: Must include "google_access_token"

        Returns:
            Result dictionary with success status and data/error
        """
        # Validate context
        if not context or "google_access_token" not in context:
            return {
                "success": False,
                "error": "Google access token required in context"
            }

        # Validate parameters
        if not self.validate_parameters(parameters):
            return {
                "success": False,
                "error": "Invalid parameters"
            }

        action = parameters["action"]

        try:
            # Build Google Calendar service
            credentials = Credentials(token=context["google_access_token"])
            service = build("calendar", "v3", credentials=credentials)

            # Route to appropriate handler
            if action == "list_events":
                return await self._list_events(service, parameters)
            elif action == "create_event":
                return await self._create_event(service, parameters)
            elif action == "update_event":
                return await self._update_event(service, parameters)
            elif action == "delete_event":
                return await self._delete_event(service, parameters)
            elif action == "search_events":
                return await self._search_events(service, parameters)
            else:
                return {
                    "success": False,
                    "error": f"Unknown action: {action}"
                }

        except HttpError as e:
            return {
                "success": False,
                "error": f"Google Calendar API error: {str(e)}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Unexpected error: {str(e)}"
            }

    async def _list_events(self, service, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """List calendar events within a time range."""
        calendar_id = parameters.get("calendar_id", "primary")
        max_results = parameters.get("max_results", 10)
        time_min = parameters.get("time_min")
        time_max = parameters.get("time_max")

        # Build query parameters
        query_params = {
            "calendarId": calendar_id,
            "maxResults": min(max_results, 250),
            "singleEvents": True,
            "orderBy": "startTime"
        }

        if time_min:
            query_params["timeMin"] = time_min
        if time_max:
            query_params["timeMax"] = time_max

        # Execute request
        events_result = service.events().list(**query_params).execute()
        events = events_result.get("items", [])

        # Format response
        formatted_events = []
        for event in events:
            formatted_events.append({
                "id": event["id"],
                "summary": event.get("summary", "No title"),
                "start": event["start"].get("dateTime", event["start"].get("date")),
                "end": event["end"].get("dateTime", event["end"].get("date")),
                "description": event.get("description", ""),
                "location": event.get("location", ""),
                "attendees": [a["email"] for a in event.get("attendees", [])]
            })

        return {
            "success": True,
            "result": {
                "events": formatted_events,
                "count": len(formatted_events)
            }
        }

    async def _create_event(self, service, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new calendar event."""
        calendar_id = parameters.get("calendar_id", "primary")

        # Build event body
        event_body = {
            "summary": parameters["summary"],
            "start": {"dateTime": parameters["start_time"]},
            "end": {"dateTime": parameters["end_time"]}
        }

        # Add optional fields
        if "description" in parameters:
            event_body["description"] = parameters["description"]
        if "location" in parameters:
            event_body["location"] = parameters["location"]
        if "attendees" in parameters:
            event_body["attendees"] = [{"email": email} for email in parameters["attendees"]]

        # Create event
        event = service.events().insert(
            calendarId=calendar_id,
            body=event_body
        ).execute()

        return {
            "success": True,
            "result": {
                "event_id": event["id"],
                "html_link": event.get("htmlLink"),
                "summary": event.get("summary")
            }
        }

    async def _update_event(self, service, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Update an existing calendar event."""
        if "event_id" not in parameters:
            return {
                "success": False,
                "error": "event_id required for update_event"
            }

        calendar_id = parameters.get("calendar_id", "primary")
        event_id = parameters["event_id"]

        # Get existing event
        event = service.events().get(
            calendarId=calendar_id,
            eventId=event_id
        ).execute()

        # Update fields
        if "summary" in parameters:
            event["summary"] = parameters["summary"]
        if "description" in parameters:
            event["description"] = parameters["description"]
        if "location" in parameters:
            event["location"] = parameters["location"]
        if "start_time" in parameters:
            event["start"] = {"dateTime": parameters["start_time"]}
        if "end_time" in parameters:
            event["end"] = {"dateTime": parameters["end_time"]}
        if "attendees" in parameters:
            event["attendees"] = [{"email": email} for email in parameters["attendees"]]

        # Update event
        updated_event = service.events().update(
            calendarId=calendar_id,
            eventId=event_id,
            body=event
        ).execute()

        return {
            "success": True,
            "result": {
                "event_id": updated_event["id"],
                "summary": updated_event.get("summary"),
                "updated": updated_event.get("updated")
            }
        }

    async def _delete_event(self, service, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Delete a calendar event."""
        if "event_id" not in parameters:
            return {
                "success": False,
                "error": "event_id required for delete_event"
            }

        calendar_id = parameters.get("calendar_id", "primary")
        event_id = parameters["event_id"]

        # Delete event
        service.events().delete(
            calendarId=calendar_id,
            eventId=event_id
        ).execute()

        return {
            "success": True,
            "result": {
                "event_id": event_id,
                "message": "Event deleted successfully"
            }
        }

    async def _search_events(self, service, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Search for events matching a query."""
        calendar_id = parameters.get("calendar_id", "primary")
        max_results = parameters.get("max_results", 10)
        query = parameters.get("query", "")

        # Build query parameters
        query_params = {
            "calendarId": calendar_id,
            "maxResults": min(max_results, 250),
            "singleEvents": True,
            "orderBy": "startTime"
        }

        if query:
            query_params["q"] = query

        if "time_min" in parameters:
            query_params["timeMin"] = parameters["time_min"]
        if "time_max" in parameters:
            query_params["timeMax"] = parameters["time_max"]

        # Execute search
        events_result = service.events().list(**query_params).execute()
        events = events_result.get("items", [])

        # Format response
        formatted_events = []
        for event in events:
            formatted_events.append({
                "id": event["id"],
                "summary": event.get("summary", "No title"),
                "start": event["start"].get("dateTime", event["start"].get("date")),
                "end": event["end"].get("dateTime", event["end"].get("date")),
                "description": event.get("description", ""),
                "location": event.get("location", "")
            })

        return {
            "success": True,
            "result": {
                "events": formatted_events,
                "count": len(formatted_events),
                "query": query
            }
        }
