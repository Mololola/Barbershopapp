import json

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

from app.core.config import settings
from app.core.rate_limit import limiter

router = APIRouter()

# Supabase email links (signup confirmation, password reset) can only ever
# redirect to a real https:// URL, never straight to the app's custom
# scheme — opened from a desktop mail client there's no app to catch it and
# the browser just shows a blank page. These pages are the real redirect
# targets (both must be in Supabase's Redirect URLs allow-list, or Supabase
# silently falls back to the Site URL instead). On a phone they forward the
# query string/hash Supabase attached into barbershopapp://auth-callback;
# on a desktop there's no app to open, so they say what to do next — and
# point business owners to the website, when there is one.
_PAGE_TEMPLATE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fadra Cut</title>
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
    <a class="button" id="open-app" href="#" hidden></a>
    <a class="button" id="open-web" href="#" hidden></a>
  </div>
  <script>
    // In the phone's language: these pages open from emailed links, outside the app.
    var lang = (navigator.language || '').toLowerCase().indexOf('es') === 0 ? 'es' : 'en';
    var copy = __COPY__[lang];
    var website = __WEBSITE__;
    document.documentElement.lang = lang;
    document.getElementById('open-app').textContent = copy.openApp;
    document.getElementById('open-web').textContent = copy.openWebsite;
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
    } else if (website && state.website) {
      var web = document.getElementById('open-web');
      web.href = website;
      web.hidden = false;
    }
  </script>
</body>
</html>
"""


def _page(copy: dict) -> str:
    website = f"{settings.web_app_url}/sign-in" if settings.web_app_url else ""
    return _PAGE_TEMPLATE.replace("__COPY__", json.dumps(copy)).replace("__WEBSITE__", json.dumps(website))


_BUTTONS = {
    "en": {"openApp": "Open the app", "openWebsite": "Open the website"},
    "es": {"openApp": "Abrir la app", "openWebsite": "Abrir la web"},
}

_CONFIRMED_PAGE = _page(
    {
        "en": {
            **_BUTTONS["en"],
            "phone": {
                "title": "Email confirmed",
                "body": "Opening the app… If it doesn't open, tap the button below.",
            },
            "desktop": {
                "title": "Email confirmed",
                "body": "Your account is ready. Go back to the app on your phone and sign in — "
                "or, if you run a shop, sign in on the website.",
                "website": True,
            },
            "error": {
                "title": "This link has expired",
                "body": "It may already have been used. Try signing in on the app — if your email still "
                "isn't confirmed, you can request a new link from the sign-in screen.",
            },
        },
        "es": {
            **_BUTTONS["es"],
            "phone": {
                "title": "Correo confirmado",
                "body": "Abriendo la app… Si no se abre, toca el botón de abajo.",
            },
            "desktop": {
                "title": "Correo confirmado",
                "body": "Tu cuenta está lista. Vuelve a la app en tu móvil e inicia sesión, "
                "o, si tienes una barbería, inicia sesión en la web.",
                "website": True,
            },
            "error": {
                "title": "Este enlace ha caducado",
                "body": "Puede que ya se haya usado. Prueba a iniciar sesión en la app: si tu correo aún no "
                "está confirmado, puedes pedir un enlace nuevo desde la pantalla de inicio de sesión.",
            },
        },
    }
)

_RESET_PAGE = _page(
    {
        "en": {
            **_BUTTONS["en"],
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
        },
        "es": {
            **_BUTTONS["es"],
            "phone": {
                "title": "Restablece tu contraseña",
                "body": "Abriendo la app para que elijas una contraseña nueva… Si no se abre, toca el botón de abajo.",
            },
            "desktop": {
                "title": "Abre este enlace en tu móvil",
                "body": "La contraseña se cambia dentro de la app. Abre este correo en el móvil desde el que "
                "la pediste y toca el enlace allí.",
            },
            "error": {
                "title": "Este enlace ha caducado",
                "body": "Pide un nuevo cambio de contraseña desde la pantalla de inicio de sesión de la app.",
            },
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
