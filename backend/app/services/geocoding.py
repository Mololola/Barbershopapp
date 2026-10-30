import json
import time
import urllib.error
import urllib.parse
import urllib.request

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings

# Free, keyless lookups by postcode: accurate to a street or two, which is all
# "near me" needs, and no customer location is ever sent anywhere (the app
# measures distances on the phone). Nominatim's usage policy asks for an
# identifying User-Agent and at most one request a second.
_USER_AGENT = f"FadraCut/1.0 (+{settings.public_base_url})"
_NOMINATIM_INTERVAL_SECONDS = 1.0


def _get_json(url: str):
    request = urllib.request.Request(url, headers={"User-Agent": _USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        # postcodes.io answers an unknown postcode with 404.
        if error.code == 404:
            return None
        raise


def postcode_coordinates(postcode: str, country: str) -> tuple[float, float] | None:
    """(latitude, longitude) of a postcode in one of the app's countries, or
    None when it isn't found."""
    if country == "GB":
        data = _get_json(f"https://api.postcodes.io/postcodes/{urllib.parse.quote(postcode)}")
        result = (data or {}).get("result") or {}
        if result.get("latitude") is None:
            return None
        return result["latitude"], result["longitude"]
    if country == "ES":
        query = urllib.parse.urlencode({"postalcode": postcode, "country": "es", "format": "jsonv2", "limit": 1})
        data = _get_json(f"https://nominatim.openstreetmap.org/search?{query}")
        if not data:
            return None
        return float(data[0]["lat"]), float(data[0]["lon"])
    return None


def geocode_missing_locations(db: Session) -> list[str]:
    """Fills in coordinates for locations that have none (the scheduled job
    runs it every 6 hours; a shop's new address gets a distance by then).
    Returns the ids it located; a postcode that isn't found stays empty and
    is tried again next run."""
    rows = db.execute(text("select id, postcode, country from locations where latitude is null")).fetchall()

    located = []
    for index, row in enumerate(rows):
        if index and row.country == "ES":
            time.sleep(_NOMINATIM_INTERVAL_SECONDS)
        coordinates = postcode_coordinates(row.postcode, row.country)
        if coordinates is None:
            continue
        db.execute(
            text("update locations set latitude = :latitude, longitude = :longitude where id = :id"),
            {"latitude": coordinates[0], "longitude": coordinates[1], "id": row.id},
        )
        located.append(str(row.id))
    db.commit()
    return located
