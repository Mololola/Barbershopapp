import json

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

from app.core.rate_limit import limiter

router = APIRouter()

# Stripe Checkout and the billing portal open in the phone's browser, and
# Stripe only redirects to https:// pages, so they land here when done. This
# page says nothing about what was bought: the webhook, not this redirect,
# records the payment, and the query string can be edited by anyone.
#
# "Back to the app" launches the app the way its home-screen icon does, so
# it comes to the front on whatever screen was open (a custom-scheme link
# would reset it to the home route instead).
_COPY = {
    "success": {
        "title": "Payment complete",
        "body": "Thank you! It can take a few seconds to show up in the app.",
    },
    "cancelled": {
        "title": "Checkout cancelled",
        "body": "Nothing was charged. You can try again from the app whenever you're ready.",
    },
    "portal": {
        "title": "All done",
        "body": "Any changes you made to your billing are saved.",
    },
}

_PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Barbershop app</title>
<style>
  body { font-family: -apple-system, Roboto, Arial, sans-serif; background: #EDEAE3; color: #221D1A;
         display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 24px;
         box-sizing: border-box; }
  .card { max-width: 360px; width: 100%; text-align: center; background: #FAF8F4; border: 1px solid #DCD5C6;
          border-radius: 16px; padding: 32px 24px; }
  .mark { width: 56px; height: 56px; border-radius: 50%; background: #A6803C; color: #2C1F0E; margin: 0 auto 16px;
          display: flex; align-items: center; justify-content: center; font-size: 28px; font-weight: 700; }
  h1 { font-size: 1.4rem; margin: 0 0 8px; }
  p { color: #6B6862; line-height: 1.5; margin: 0; }
  a.button { display: block; margin-top: 24px; padding: 14px 24px; background: #221D1A; color: #EDEAE3;
             text-decoration: none; border-radius: 10px; font-weight: 600; }
  .hint { margin-top: 16px; font-size: 0.9rem; }
</style>
</head>
<body>
  <div class="card">
    <div class="mark" id="mark"></div>
    <h1 id="title"></h1>
    <p id="body"></p>
    <a class="button" id="open-app" hidden
       href="intent://#Intent;action=android.intent.action.MAIN;category=android.intent.category.LAUNCHER;package=com.barbershopapp.mobile;end">Back to the app</a>
    <p class="hint" id="hint" hidden>You can close this tab and go back to the app.</p>
  </div>
  <script>
    var copy = __COPY__;
    var outcome = new URLSearchParams(window.location.search).get('outcome');
    var state = copy[outcome] || copy.portal;
    document.getElementById('mark').textContent = outcome === 'cancelled' ? '\\u2715' : '\\u2713';
    document.getElementById('title').textContent = state.title;
    document.getElementById('body').textContent = state.body;
    var isAndroid = /Android/i.test(navigator.userAgent);
    document.getElementById(isAndroid ? 'open-app' : 'hint').hidden = false;
  </script>
</body>
</html>
""".replace("__COPY__", json.dumps(_COPY))


@router.get("/billing/return", response_class=HTMLResponse)
@limiter.exempt
def billing_return(request: Request) -> str:
    return _PAGE
