import datetime
from zoneinfo import ZoneInfo

from app.services import finance_analytics as fa

LONDON = ZoneInfo("Europe/London")
UTC = datetime.UTC
OPEN = {
    "is_closed": False,
    "open_time": datetime.time(9),
    "close_time": datetime.time(17),
    "break_start": None,
    "break_end": None,
}
CLOSED = {"is_closed": True, "open_time": None, "close_time": None, "break_start": None, "break_end": None}
WEEK = {d: OPEN for d in range(6)} | {6: CLOSED}  # Mon-Sat 9-17, Sunday closed

SEP, OCT, AUG = datetime.date(2026, 9, 1), datetime.date(2026, 10, 1), datetime.date(2026, 8, 1)


def booking(start, *, minutes=30, price=2000, status="completed", worker="w1", service="cut", customer="c1"):
    return fa.BookingRow(
        start=start,
        end=start + datetime.timedelta(minutes=minutes),
        status=status,
        price_cents=price,
        worker_id=worker,
        service_id=service,
        customer_id=customer,
    )


def shop(bookings=(), costs=(), income=None, **overrides):
    values = dict(
        tz=LONDON,
        bookings=list(bookings),
        costs=list(costs),
        other_income=income or {},
        business_hours=WEEK,
        worker_names={"w1": "Jane"},
        worker_schedules={},
        service_names={"cut": "Skin fade", "beard": "Beard trim"},
        average_service_price_cents=2000,
        first_visit={},
        worker_ratings={},
    )
    values.update(overrides)
    return fa.ShopData(**values)


def at(day, hour=10, minute=0):
    return datetime.datetime(2026, 9, day, hour, minute, tzinfo=LONDON)


# ------------------------------------------------------------------ costs


def test_monthly_costs_run_from_start_to_end_and_one_offs_hit_one_month():
    costs = [
        fa.CostRow("monthly", 100000, AUG, None),  # rent, ongoing
        fa.CostRow("monthly", 20000, AUG, AUG),  # stopped after August
        fa.CostRow("monthly", 30000, SEP, None),  # started September
        fa.CostRow("one_off", 50000, SEP, None),  # new chair in September
    ]
    assert fa.costs_for_month(costs, AUG) == 120000
    assert fa.costs_for_month(costs, SEP) == 180000
    assert fa.costs_for_month(costs, OCT) == 130000


# ------------------------------------------------------------ free summary


def test_month_figures_count_only_completed_bookings_in_that_month_plus_other_income():
    data = shop(
        bookings=[
            booking(at(3)),
            booking(at(4), price=3000),
            booking(at(5), status="cancelled"),
            booking(at(6), status="confirmed"),
            booking(datetime.datetime(2026, 8, 31, 10, tzinfo=LONDON)),
        ],
        costs=[fa.CostRow("monthly", 10000, SEP, None)],
        income={SEP: 1500},
    )
    figures = fa.month_figures(data, SEP)
    assert (figures.booking_revenue_cents, figures.completed_bookings) == (5000, 2)
    assert figures.revenue_cents == 6500
    assert figures.net_cents == -3500


def test_month_is_decided_in_the_shops_time_zone():
    # 23:30 UTC on 30 Sep is 00:30 on 1 Oct in London (BST).
    late = datetime.datetime(2026, 9, 30, 23, 30, tzinfo=UTC)
    data = shop(bookings=[booking(late)])
    assert fa.month_figures(data, SEP).completed_bookings == 0
    assert fa.month_figures(data, OCT).completed_bookings == 1


def test_bookings_to_break_even_rounds_up_at_the_average_ticket():
    figures = fa.MonthFigures(SEP, booking_revenue_cents=6000, other_income_cents=0, costs_cents=10000, completed_bookings=3)
    ticket = fa.average_ticket_cents(figures, fallback_cents=9999)
    assert ticket == 2000
    assert fa.bookings_to_break_even(figures, ticket) == 2
    profitable = fa.MonthFigures(SEP, 20000, 0, 10000, 5)
    assert fa.bookings_to_break_even(profitable, 4000) is None


def test_average_ticket_falls_back_to_service_prices_before_any_booking():
    empty = fa.MonthFigures(SEP, 0, 0, 10000, 0)
    assert fa.average_ticket_cents(empty, fallback_cents=2500) == 2500
    assert fa.bookings_to_break_even(empty, 2500) == 4


# ---------------------------------------------------------------- forecast


def test_forecast_projects_the_pace_so_far_over_remaining_open_days():
    # 1-10 Sep has 9 open days (Sunday 6th closed); two £20 cuts on each = £40/day.
    open_days = [d for d in range(1, 11) if datetime.date(2026, 9, d).weekday() != 6]
    done = [booking(at(d)) for d in open_days for _ in range(2)]
    data = shop(bookings=done, costs=[fa.CostRow("monthly", 60000, SEP, None)])
    forecast = fa.forecast_month(data, SEP, at(11, 8))
    # 11-30 Sep: 20 days minus 3 Sundays = 17 open days at £40.
    assert forecast.projected_revenue_cents == 9 * 4000 + 17 * 4000
    assert forecast.projected_net_cents == 26 * 4000 - 60000
    # £600 at £40 per open day is reached on the 15th open day: Thu 17 Sep.
    assert forecast.break_even_day == datetime.date(2026, 9, 17)
    assert not forecast.already_broken_even


def test_forecast_never_below_what_is_already_confirmed():
    data = shop(bookings=[booking(at(20), status="confirmed", price=50000)])
    forecast = fa.forecast_month(data, SEP, at(2, 8))
    assert forecast.confirmed_upcoming_cents == 50000
    assert forecast.projected_revenue_cents >= 50000


# ------------------------------------------------------------- utilisation


def test_utilisation_is_booked_chair_time_over_available_by_hour():
    # Monday 7 Sep 10:00-11:00 fully booked; now = Tuesday 8 Sep.
    data = shop(bookings=[booking(at(7, 10), minutes=60)])
    cells = {(c.weekday, c.hour): c for c in fa.utilisation_heatmap(data, at(8, 8))}
    monday_10 = cells[(0, 10)]
    assert monday_10.available_minutes == 8 * 60  # 8 Mondays in the 56-day window
    assert monday_10.booked_minutes == 60
    assert cells[(0, 11)].booked_minutes == 0
    assert (6, 10) not in cells  # closed Sundays have no capacity at all


# --------------------------------------------------------- barbers/services


def test_barber_stats_cover_the_last_30_days():
    data = shop(
        bookings=[
            booking(at(1)),
            booking(at(2), price=3000),
            booking(datetime.datetime(2026, 7, 1, 10, tzinfo=LONDON)),
        ],
        worker_ratings={"w1": 4.7},
    )
    [jane] = fa.barber_stats(data, at(15, 8))
    assert (jane.name, jane.bookings, jane.revenue_cents, jane.average_rating) == ("Jane", 2, 5000, 4.7)
    assert 0 < jane.utilisation < 0.01


def test_service_stats_compare_with_the_previous_90_days():
    now = at(15, 8)
    data = shop(
        bookings=[
            booking(at(1)),
            booking(at(2)),
            booking(at(3), service="beard", price=1000),
            booking(now - datetime.timedelta(days=120)),
        ]
    )
    stats = fa.service_stats(data, now)
    assert [s.name for s in stats] == ["Skin fade", "Beard trim"]
    assert (stats[0].bookings, stats[0].previous_bookings, round(stats[0].share, 2)) == (2, 1, 0.67)


# ---------------------------------------------------------------- customers


def test_overdue_regulars_are_flagged_by_their_own_usual_gap():
    now = at(30, 12)
    regular = [booking(now - datetime.timedelta(days=d), customer="reg") for d in (140, 110, 80)]  # every 30 days
    recent = [booking(now - datetime.timedelta(days=d), customer="fine") for d in (70, 40, 10)]
    stats = fa.customer_stats(shop(bookings=regular + recent), now)
    assert [c.customer_id for c in stats.at_risk] == ["reg"]
    assert (stats.at_risk[0].usual_gap_days, stats.at_risk[0].days_since) == (30, 80)


def test_new_vs_returning_and_return_rate():
    now = at(30, 12)

    def ago(days):
        return now - datetime.timedelta(days=days)

    data = shop(
        bookings=[
            booking(ago(5), customer="new"),
            booking(ago(5), customer="old"),
            booking(ago(60), customer="old"),  # seen 6-12 weeks ago, came back
            booking(ago(60), customer="gone"),  # seen 6-12 weeks ago, never since
        ],
        first_visit={"new": ago(5), "old": ago(60), "gone": ago(60)},
    )
    stats = fa.customer_stats(data, now)
    assert (stats.customers_last_30_days, stats.new_last_30_days, stats.returning_last_30_days) == (2, 1, 1)
    assert stats.return_rate == 0.5


# -------------------------------------------------------------- suggestions


def test_no_suggestions_without_enough_history():
    data = shop(bookings=[booking(at(d)) for d in (1, 2, 3)])
    assert fa.suggestions(data, at(15), [], fa.customer_stats(data, at(15)), [], "£") == []


def test_second_visit_bundle_when_most_customers_come_once():
    now = at(30, 12)
    once = [booking(now - datetime.timedelta(days=d), customer=f"c{d}") for d in range(1, 13)]
    data = shop(bookings=once)
    found = fa.suggestions(data, now, [], fa.customer_stats(data, now), [], "£")
    bundle = next(s for s in found if s.kind == "second_visit_bundle")
    # 12 one-visit customers, no repeaters: 0.5 x £20 x (0.2 x 12) = £24.
    assert bundle.monthly_gain_cents == 2400
    assert "2 cuts for the price of 1.5" in bundle.title


def test_quiet_window_offer_only_when_it_pays_for_itself():
    now = at(30, 12)
    # Busy Monday mornings, empty afternoons.
    busy = [
        booking(datetime.datetime(2026, 9, d, h, tzinfo=LONDON), minutes=60, customer=f"c{d}{h}")
        for d in (7, 14, 21, 28)
        for h in (9, 10, 11)
    ]
    data = shop(bookings=busy)
    cells = fa.utilisation_heatmap(data, now)
    found = fa.suggestions(data, now, cells, fa.customer_stats(data, now), fa.service_stats(data, now), "£")
    quiet = next(s for s in found if s.kind == "quiet_window")
    assert quiet.monthly_gain_cents > 0
    assert "25% off" in quiet.detail
    assert found == sorted(found, key=lambda s: s.monthly_gain_cents, reverse=True)


def test_suggestions_in_spanish_keep_the_same_figures():
    now = at(30, 12)
    once = [booking(now - datetime.timedelta(days=d), customer=f"c{d}") for d in range(1, 13)]
    data = shop(bookings=once)
    english = fa.suggestions(data, now, [], fa.customer_stats(data, now), [], "£")
    spanish = fa.suggestions(data, now, [], fa.customer_stats(data, now), [], "£", spanish=True)
    bundle = next(s for s in spanish if s.kind == "second_visit_bundle")
    assert "2 cortes por el precio de 1,5" in bundle.title
    assert "Supone" in bundle.assumptions
    assert [s.monthly_gain_cents for s in spanish] == [s.monthly_gain_cents for s in english]
