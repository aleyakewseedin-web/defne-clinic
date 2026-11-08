"""One error format for the whole API (SRS: FR-4.2, FR-9.5, FR-9.9).

Every error body looks like this:

    {
      "code": "validation_failed",            # stable, for the program and translations
      "message": "Please correct the highlighted fields.",   # plain language fallback
      "fields": [{"field": "phone", "message": "Enter a valid phone number."}]   # optional
    }

The HTTP status says the kind of problem (400/422 invalid input, 401 not logged in,
403 not allowed, 404 not found, 409 conflict, 500 server error).
"""
from typing import Optional

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

FieldErrors = list[dict[str, str]]


def error_body(code: str, message: str, fields: Optional[FieldErrors] = None) -> dict:
    body: dict = {"code": code, "message": message}
    if fields:
        body["fields"] = fields
    return body


class ApiError(Exception):
    """Raise this anywhere in the API to return a formatted error."""

    def __init__(
        self,
        status_code: int,
        code: str,
        message: str,
        fields: Optional[FieldErrors] = None,
    ):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.fields = fields


# Ready-made errors for the rules in the SRS -------------------------------

def slot_taken() -> ApiError:
    return ApiError(409, "slot_taken", "This time is already taken for that staff member.")


def outside_hours() -> ApiError:
    return ApiError(422, "outside_hours", "This time is outside the clinic or staff working hours.")


def staff_on_leave() -> ApiError:
    return ApiError(422, "staff_on_leave", "This staff member is not available on that day.")


def not_allowed() -> ApiError:
    return ApiError(403, "forbidden", "You are not allowed to do this.")


# Handlers ------------------------------------------------------------------

_STATUS_CODES = {
    401: ("not_authenticated", "Please log in to continue."),
    403: ("forbidden", "You are not allowed to do this."),
    404: ("not_found", "We could not find what you asked for."),
    405: ("method_not_allowed", "This action is not supported."),
}


def _json(status_code: int, body: dict) -> JSONResponse:
    return JSONResponse(status_code=status_code, content=body)


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def handle_api_error(_: Request, exc: ApiError):
        return _json(exc.status_code, error_body(exc.code, exc.message, exc.fields))

    @app.exception_handler(RequestValidationError)
    async def handle_validation(_: Request, exc: RequestValidationError):
        fields: FieldErrors = []
        for err in exc.errors():
            path = [str(p) for p in err["loc"] if p not in ("body", "query", "path")]
            fields.append({"field": ".".join(path), "message": str(err["msg"])})
        return _json(
            422,
            error_body("validation_failed", "Please correct the highlighted fields.", fields),
        )

    @app.exception_handler(StarletteHTTPException)
    async def handle_http(_: Request, exc: StarletteHTTPException):
        code, message = _STATUS_CODES.get(exc.status_code, ("http_error", "The request could not be completed."))
        if isinstance(exc.detail, str) and exc.status_code not in _STATUS_CODES:
            message = exc.detail
        return _json(exc.status_code, error_body(code, message))

    @app.exception_handler(Exception)
    async def handle_unexpected(_: Request, __: Exception):
        return _json(500, error_body("internal_error", "Something went wrong. Please try again."))
