import json

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

from app.core.rate_limit import limiter

router = APIRouter()

# Supabase email links (signup confirmation, password reset) can only ever
# redirect to a real https:// URL, never straight to the app's custom
# scheme — opened from a desktop mail client there's no app to catch it and
# the browser just shows a blank page. These pages are the real redirect
# targets (both must be in Supabase's Redirect URLs allow-list, or Supabase
# silently falls back to the Site URL instead). On a phone they forward the
# query string/hash Supabase attached into barbershopapp://auth-callback;
# on a desktop there's no app to open, so they just say what to do next.
_PAGE_TEMPLATE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Barbershop app</title>
<style>
  body { font-family: -apple-system, Roboto, Arial, sans-serif; background: #fafafa; color: #1a1a1a;
         display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 24px; }
  .card { max-width: 360px; text-align: center; }
  h1 { font-size: 1.4rem; margin-bottom: 8px; }
  p { color: #555; line-height: 1.5; }
  a.button { display: inline-block; margin-top: 20px; padding: 12px 24px; background: #1a1a1a; color: #fff;
             text-decoration: none; border-radius: 8px; font-weight: 600; }
</style>
</head>
<body>
  <div class="card">
    <h1 id="title"></h1>
    <p id="body"></p>
    <a class="button" id="open-app" href="#" hidden>Open the app</a>
  </div>
  <script>
    var copy = __COPY__;
    var params = new URLSearchParams(window.location.search + '&' + window.location.hash.slice(1));
    var isPhone = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
    var state = params.get('error') ? copy.error : isPhone ? copy.phone : copy.desktop;
    document.getElementById('title').textContent = state.title;
    document.getElementById('body').textContent = state.body;
    if (isPhone && !params.get('error')) {
      var target = 'barbershopapp://auth-callback' + window.location.search + window.location.hash;
      var button = document.getElementById('open-app');
      button.href = target;
      button.hidden = false;
      window.location.replace(target);
    }
  </script>
</body>
</html>
"""


def _page(copy: dict) -> str:
    return _PAGE_TEMPLATE.replace("__COPY__", json.dumps(copy))


_CONFIRMED_PAGE = _page(
    {
        "phone": {
            "title": "Email confirmed",
            "body": "Opening the app… If it doesn't open, tap the button below.",
        },
        "desktop": {
            "title": "Email confirmed",
            "body": "Your account is ready. You can close this tab — go back to the app on your phone and sign in.",
        },
        "error": {
            "title": "This link has expired",
            "body": "It may already have been used. Try signing in on the app — if your email still "
            "isn't confirmed, you can request a new link from the sign-in screen.",
        },
    }
)

_RESET_PAGE = _page(
    {
        "phone": {
            "title": "Reset your password",
            "body": "Opening the app so you can choose a new password… If it doesn't open, tap the button below.",
        },
        "desktop": {
            "title": "Open this link on your phone",
            "body": "Password resets finish inside the app. Open this email on the phone where you "
            "requested the reset and tap the link there.",
        },
        "error": {
            "title": "This link has expired",
            "body": "Request a new password reset from the app's sign-in screen.",
        },
    }
)


@router.get("/auth/confirmed", response_class=HTMLResponse)
@limiter.exempt
def auth_confirmed(request: Request) -> str:
    return _CONFIRMED_PAGE


@router.get("/auth/reset", response_class=HTMLResponse)
@limiter.exempt
def auth_reset(request: Request) -> str:
    return _RESET_PAGE
