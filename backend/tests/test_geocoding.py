import uuid
from types import SimpleNamespace

from app.services import geocoding


class _Db:
    def __init__(self, rows):
        self.rows = rows
        self.updates = []
        self.committed = False

    def execute(self, statement, params=None):
        sql = str(statement)
        if sql.startswith("update"):
            self.updates.append(params)
        return self

    def fetchall(self):
        return self.rows

    def commit(self):
        self.committed = True


def test_locations_without_coordinates_get_them_and_unknown_postcodes_stay_empty(monkeypatch):
    known, unknown = uuid.uuid4(), uuid.uuid4()
    db = _Db([
        SimpleNamespace(id=known, postcode="SW1A 1AA", country="GB"),
        SimpleNamespace(id=unknown, postcode="ZZ99 9ZZ", country="GB"),
    ])
    monkeypatch.setattr(
        geocoding, "postcode_coordinates", lambda postcode, country: (51.5, -0.14) if postcode == "SW1A 1AA" else None
    )

    located = geocoding.geocode_missing_locations(db)

    assert located == [str(known)]
    assert db.updates == [{"latitude": 51.5, "longitude": -0.14, "id": known}]
    assert db.committed


def test_an_unsupported_country_is_never_looked_up():
    assert geocoding.postcode_coordinates("75001", "FR") is None
