from fastapi import status


class SanctuaryException(Exception):
    def __init__(
        self,
        detail: str,
        error_code: str,
        status_code: int = status.HTTP_400_BAD_REQUEST
    ):
        self.detail = detail
        self.error_code = error_code
        self.status_code = status_code
        super().__init__(detail)


class AuthenticationFailedException(SanctuaryException):
    def __init__(self, detail: str = "Authentication failed."):
        super().__init__(
            detail=detail,
            error_code="AUTH_FAILED",
            status_code=status.HTTP_401_UNAUTHORIZED
        )


class ForbiddenException(SanctuaryException):
    def __init__(self, detail: str = "Access denied."):
        super().__init__(
            detail=detail,
            error_code="FORBIDDEN",
            status_code=status.HTTP_403_FORBIDDEN
        )


class ProfileNotFoundException(SanctuaryException):
    def __init__(self, detail: str = "Sanctuary profile does not exist."):
        super().__init__(
            detail=detail,
            error_code="PROFILE_NOT_FOUND",
            status_code=status.HTTP_404_NOT_FOUND
        )


class PolicyViolationException(SanctuaryException):
    def __init__(self, detail: str):
        super().__init__(
            detail=detail,
            error_code="POLICY_VIOLATION",
            status_code=getattr(status, "HTTP_422_UNPROCESSABLE_CONTENT", 422)
        )


class RateLimitException(SanctuaryException):
    def __init__(self, detail: str = "Rate limit exceeded. Please be mindful."):
        super().__init__(
            detail=detail,
            error_code="RATE_LIMIT_EXCEEDED",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS
        )
