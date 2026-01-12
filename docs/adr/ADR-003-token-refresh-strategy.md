# ADR-003: Token Refresh Strategy

## Status

Accepted

## Context

Boardroom Journal uses OAuth authentication with JWT tokens. We needed a token lifecycle strategy that:
- Provides smooth user experience (no unexpected logouts)
- Maintains security (short-lived access tokens)
- Works across app restarts and background/foreground transitions
- Handles network failures gracefully

## Decision

Use **proactive token refresh** with short access tokens and longer refresh tokens.

### Token Lifetimes

| Token Type | Expiry | Storage |
|------------|--------|---------|
| Access Token | 15 minutes | Secure storage (Keychain/Keystore) |
| Refresh Token | 30 days | Secure storage (Keychain/Keystore) |

### Refresh Strategy

1. **Proactive refresh**: When access token has < 5 minutes remaining, automatically refresh before making API calls.
2. **Reactive refresh**: If API returns 401, attempt refresh and retry the request.
3. **Background refresh**: On app launch, check token expiry and refresh if needed.
4. **Graceful degradation**: If refresh fails, continue in local-only mode; prompt re-auth when connectivity returns.

### Implementation

```dart
class AuthService {
  Timer? _refreshTimer;

  Future<void> _scheduleTokenRefresh(Duration expiresIn) {
    final refreshTime = expiresIn - Duration(minutes: 5);
    _refreshTimer = Timer(refreshTime, _refreshTokens);
  }
}
```

### Alternatives Considered

1. **Longer access tokens (1 hour+)**: Rejected - reduces security; if token is stolen, longer exposure window.
2. **Refresh on every request**: Rejected - unnecessary API calls; adds latency.
3. **Refresh only on 401**: Rejected - causes user-visible delays when token expires; poor UX.

## Consequences

### Positive
- Seamless UX - users never see token expiration
- Strong security - short access token exposure window
- Resilient - handles network failures gracefully
- Efficient - refreshes only when needed

### Negative
- More complex than simple long-lived tokens
- Requires timer management (potential memory leaks if not disposed)
- Background refresh requires careful handling on iOS

### Implementation Notes
- `lib/services/auth/auth_service.dart`: Token refresh logic
- `lib/services/auth/token_storage.dart`: Secure storage wrapper
- `backend/lib/services/auth_service.dart`: Server-side token generation

## References

- PRD Section 3D: Security Specifications
- OAuth 2.0 Best Practices (RFC 6749)
