from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

from app.core.rate_limit import limiter

router = APIRouter()

# Supabase email links (signup confirmation, password reset) can only ever
# redirect to a real https:// URL, never straight to the app's custom
# scheme — opened from a desktop mail client there's no app to catch it and
# the browser just shows a blank page. This page is the real redirect
# target: it forwards the query string/hash Supabase attached straight into
# barbershopapp://auth-callback (which the OS intercepts directly if the
# app is installed) and, either way, tells the person what happened.
_CONFIRMED_PAGE = """<!doctype html>
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
    <h1>You're all set</h1>
    <p>Your email is confirmed. If the app didn't open automatically, tap below — or close this page and open it yourself.</p>
    <a class="button" id="open-app" href="#">Open the app</a>
  </div>
  <script>
    var target = 'barbershopapp://auth-callback' + window.location.search + window.location.hash;
    document.getElementById('open-app').href = target;
    window.location.replace(target);
  </script>
</body>
</html>
"""


@router.get("/auth/confirmed", response_class=HTMLResponse)
@limiter.exempt
def auth_confirmed(request: Request) -> str:
    return _CONFIRMED_PAGE
