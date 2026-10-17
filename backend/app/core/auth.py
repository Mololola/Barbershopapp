import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient
from jwt.exceptions import PyJWKClientConnectionError

from app.core.config import settings

_jwks_uri = f"{settings.supabase_url}/auth/v1/.well-known/jwks.json"
_jwks_client = PyJWKClient(_jwks_uri)
_bearer_scheme = HTTPBearer()


def _get_signing_key(token: str):
    global _jwks_client
    try:
        return _jwks_client.get_signing_key_from_jwt(token)
    except PyJWKClientConnectionError:
        # Observed in practice: a client that's been alive for hours can
        # start failing to fetch/refresh the JWKS even though a brand-new
        # client fetching the exact same URL succeeds immediately. Replace
        # it and retry once rather than 401-ing every request until the
        # process gets restarted.
        _jwks_client = PyJWKClient(_jwks_uri)
        return _jwks_client.get_signing_key_from_jwt(token)


def get_token_claims(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
) -> dict:
    """Verifies a Supabase-issued access token and returns its claims.

    Supabase JWTs are asymmetrically signed (ES256) and verified against its
    JWKS endpoint — see docs/architecture.md for why FastAPI needs to do this
    itself rather than relying on Postgres RLS.
    """
    token = credentials.credentials
    try:
        signing_key = _get_signing_key(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["ES256"],
            audience="authenticated",
            # PyJWT validates iat/exp with zero tolerance by default. This
            # dev machine's clock runs a little behind Supabase's (observed:
            # ~1s), which intermittently made freshly-issued tokens look
            # "not yet valid". A small leeway is standard practice for JWT
            # validation generally (clocks are never perfectly synced).
            leeway=30,
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from exc

    return payload


def get_current_user_id(claims: dict = Depends(get_token_claims)) -> str:
    return claims["sub"]
