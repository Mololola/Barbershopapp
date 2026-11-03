import re
from collections.abc import Callable

# Spanish for the error messages people can see in the app. The app sends
# Accept-Language with every request; anything not listed (admin, jobs,
# webhooks) stays English.
_SPANISH = {
    "Not your business": "Este negocio no es tuyo.",
    "Business not found": "No se ha encontrado el negocio.",
    "Service not found": "No se ha encontrado el servicio.",
    "Add your basic cut before subscribing.": "Añade tu corte básico antes de suscribirte.",
    "No billing account yet — subscribe first": "Aún no tienes cuenta de facturación: suscríbete primero.",
    "No active subscription": "No hay ninguna suscripción activa.",
    "This business has already had its free Premium trial": "Este negocio ya ha usado su prueba gratuita de Premium.",
    "Finance Premium is already active for this business": "Finance Premium ya está activo en este negocio.",
    "Minor accounts can't make purchases.": "Las cuentas de menores no pueden hacer compras.",
    "Service not found for this business": "Este negocio no tiene ese servicio.",
    "Worker not found for this business": "Ese barbero no trabaja en este negocio.",
    "This business is currently unavailable": "Este negocio no está disponible ahora mismo.",
    "That slot was just taken — please pick another.": "Esa hora se acaba de ocupar: elige otra.",
    "Could not create booking": "No se ha podido crear la reserva.",
    "Booking not found": "No se ha encontrado la reserva.",
    "Not your booking to cancel": "No puedes cancelar esta reserva.",
    "Not your business's booking": "Esta reserva no es de tu negocio.",
    "Only confirmed bookings can be marked done": "Solo se pueden marcar como hechas las reservas confirmadas.",
    "This booking hasn't started yet": "Esta reserva todavía no ha empezado.",
    "That month hasn't happened yet": "Ese mes todavía no ha llegado.",
    "That IBAN isn't valid — check it and try again.": "Ese IBAN no es válido: revísalo y vuelve a intentarlo.",
    "Add your bank details first.": "Añade antes tus datos bancarios.",
    "That's more than your available balance.": "Eso supera tu saldo disponible.",
    "No review for this booking": "Esta reserva no tiene reseña.",
    "Not your review": "Esta reseña no es tuya.",
    "Invalid or expired token": "Tu sesión ha caducado: vuelve a iniciar sesión.",
    # FastAPI's own, for a request with no token at all.
    "Not authenticated": "Tienes que iniciar sesión.",
    "Cancel your subscription before deleting your account.": "Cancela tu suscripción antes de eliminar tu cuenta.",
    "Something went wrong. Please try again.": "Algo ha fallado. Inténtalo de nuevo.",
}


def _upcoming_bookings(match: re.Match[str]) -> str:
    count = int(match[1])
    if count == 1:
        return "Resuelve tu reserva pendiente antes de eliminar tu cuenta."
    return f"Resuelve tus {count} reservas pendientes antes de eliminar tu cuenta."


_SPANISH_PATTERNS: list[tuple[re.Pattern[str], Callable[[re.Match[str]], str]]] = [
    (re.compile(r"Resolve your (\d+) upcoming bookings? before deleting your account\."), _upcoming_bookings),
]


def is_spanish(accept_language: str | None) -> bool:
    return (accept_language or "").strip().lower().startswith("es")


def translate(message: str, accept_language: str | None) -> str:
    """[message] in the request's language, when it's Spanish and we have it."""
    if not is_spanish(accept_language):
        return message
    if message in _SPANISH:
        return _SPANISH[message]
    for pattern, render in _SPANISH_PATTERNS:
        if match := pattern.fullmatch(message):
            return render(match)
    return message
