from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

from app.core.config import settings
from app.core.i18n import is_spanish
from app.core.rate_limit import limiter

router = APIRouter()

# Google Play requires a web page, reachable without the app, that explains
# how to delete an account and what is kept afterwards. The deletion itself
# stays in the app (DELETE /account), so this page only gives the steps and
# an email fallback for people who no longer have the app. It's in the
# browser's language.
_TEXT = {
    "en": {
        "title": "Delete your Fadra Cut account",
        "intro": "Fadra Cut is run by Luis Guillot Lozano. You can delete your account at any time.",
        "in_app": "In the app",
        "step1": "Open Fadra Cut and sign in.",
        "step2": "Tap <strong>Settings</strong> (the gear icon at the top of the home screen).",
        "step3": "Tap <strong>Delete account</strong> and confirm.",
        "immediate": "Your account is deleted straight away.",
        "without_app": "Without the app",
        "email_subject": "Delete%20my%20Fadra%20Cut%20account",
        "email_before": "Email",
        "email_after": "from the email address you signed up with, asking us to delete your account. "
        "We'll do it within one month and reply to confirm.",
        "deleted": "What is deleted",
        "deleted_body": "Your profile, bookings, reviews, posts, photos and videos, messages, saved designs, "
        "and any rewards that haven't been paid to you yet.",
        "kept": "What is kept",
        "kept_payouts": "Records of reward withdrawals already paid to you (amount, date, account holder name "
        "and IBAN) are kept for 6 years, because tax law requires it.",
        "kept_stripe": "Stripe keeps its own records of payments for its legal obligations.",
        "business": "Business accounts",
        "business_body": "Before deleting a business account, cancel its subscription and resolve any upcoming "
        "bookings, so no customer loses an appointment without warning.",
        "more_before": "More detail is in our",
        "privacy": "Privacy Policy",
    },
    "es": {
        "title": "Eliminar tu cuenta de Fadra Cut",
        "intro": "Fadra Cut lo gestiona Luis Guillot Lozano. Puedes eliminar tu cuenta cuando quieras.",
        "in_app": "Desde la app",
        "step1": "Abre Fadra Cut e inicia sesión.",
        "step2": "Toca <strong>Ajustes</strong> (el icono del engranaje arriba en la pantalla de inicio).",
        "step3": "Toca <strong>Eliminar cuenta</strong> y confirma.",
        "immediate": "Tu cuenta se elimina en el momento.",
        "without_app": "Sin la app",
        "email_subject": "Eliminar%20mi%20cuenta%20de%20Fadra%20Cut",
        "email_before": "Escribe a",
        "email_after": "desde el correo con el que te registraste pidiendo que eliminemos tu cuenta. "
        "Lo haremos en un plazo de un mes y te responderemos para confirmarlo.",
        "deleted": "Qué se elimina",
        "deleted_body": "Tu perfil, reservas, reseñas, publicaciones, fotos y vídeos, mensajes, diseños guardados "
        "y las recompensas que aún no se te hayan pagado.",
        "kept": "Qué se conserva",
        "kept_payouts": "Los registros de las retiradas de recompensas ya pagadas (importe, fecha, titular y "
        "IBAN) se conservan 6 años, porque lo exige la ley fiscal.",
        "kept_stripe": "Stripe conserva sus propios registros de pagos por sus obligaciones legales.",
        "business": "Cuentas de negocio",
        "business_body": "Antes de eliminar una cuenta de negocio, cancela su suscripción y resuelve las reservas "
        "pendientes, para que ningún cliente pierda una cita sin aviso.",
        "more_before": "Tienes más detalles en nuestra",
        "privacy": "Política de privacidad",
    },
}

_PAGE = """<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
  body {{ font-family: -apple-system, Roboto, Arial, sans-serif; background: #EDEAE3; color: #221D1A;
         margin: 0; padding: 24px 16px; line-height: 1.5; }}
  .card {{ max-width: 560px; margin: 0 auto; background: #FAF8F4; border: 1px solid #DCD5C6;
          border-radius: 16px; padding: 28px 24px; }}
  h1 {{ font-size: 1.5rem; margin: 0 0 8px; }}
  h2 {{ font-size: 1.1rem; margin: 24px 0 8px; }}
  p, li {{ color: #4A4641; }}
  ol, ul {{ padding-left: 22px; margin: 0; }}
  li {{ margin-bottom: 6px; }}
  a {{ color: #7A5B22; }}
</style>
</head>
<body>
  <div class="card">
    <h1>{title}</h1>
    <p>{intro}</p>

    <h2>{in_app}</h2>
    <ol>
      <li>{step1}</li>
      <li>{step2}</li>
      <li>{step3}</li>
    </ol>
    <p>{immediate}</p>

    <h2>{without_app}</h2>
    <p>{email_before} <a href="mailto:{support_email}?subject={email_subject}">{support_email}</a>
       {email_after}</p>

    <h2>{deleted}</h2>
    <p>{deleted_body}</p>

    <h2>{kept}</h2>
    <ul>
      <li>{kept_payouts}</li>
      <li>{kept_stripe}</li>
    </ul>

    <h2>{business}</h2>
    <p>{business_body}</p>

    <p style="margin-top: 24px;">{more_before}
       <a href="https://claude.ai/code/artifact/f348e6eb-ffe5-4615-8087-6ab8396295ca">{privacy}</a>.</p>
  </div>
</body>
</html>
"""

_PAGES = {lang: _PAGE.format(lang=lang, support_email=settings.support_email, **text) for lang, text in _TEXT.items()}


@router.get("/delete-account", response_class=HTMLResponse)
@limiter.exempt
def delete_account_page(request: Request) -> str:
    return _PAGES["es" if is_spanish(request.headers.get("accept-language")) else "en"]
