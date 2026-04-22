#!/usr/bin/env -S uv run --quiet
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "gtfs-realtime-bindings"]
# ///
"""Print the next 5 bus arrivals at a TfWM stop using the GTFS-RT feed.

Accepts either a numeric `stop_id` (e.g. 43000320101) or a short `stop_code`
(e.g. nwmaptwp). Reads `data/stops.txt`, `data/routes.txt`, and
`data/trips.txt` to attach human-readable route names and destination
headsigns to the live feed.

Run with: uv run scripts/next_buses_rt.py [stop_code_or_id]
"""

from __future__ import annotations

import csv
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

import httpx
from google.transit import gtfs_realtime_pb2

try:
    APP_ID = os.environ["TFWM_APP_ID"]
    APP_KEY = os.environ["TFWM_APP_KEY"]
except KeyError as e:
    raise SystemExit(f"missing env var {e.args[0]} (set TFWM_APP_ID and TFWM_APP_KEY)")

BASE = "http://api.tfwm.org.uk"
TRIP_UPDATES_URL = f"{BASE}/gtfs/trip_updates"
DEFAULT_STOP = "nwmaptwp"
LOCAL_TZ = ZoneInfo("Europe/London")
DATA = Path(__file__).parent.parent / "data"


def resolve_stop(code_or_id: str) -> tuple[str, str]:
    """Return (stop_id, stop_name) from stops.txt."""
    with (DATA / "stops.txt").open() as f:
        for row in csv.DictReader(f):
            if row["stop_id"] == code_or_id or row["stop_code"] == code_or_id:
                return row["stop_id"], row["stop_name"]
    raise SystemExit(f"stop {code_or_id!r} not found in stops.txt")


def fetch_feed() -> gtfs_realtime_pb2.FeedMessage:
    r = httpx.get(
        TRIP_UPDATES_URL,
        params={"app_id": APP_ID, "app_key": APP_KEY},
        timeout=30.0,
    )
    r.raise_for_status()
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.ParseFromString(r.content)
    return feed


def arrivals_at_stop(
    feed: gtfs_realtime_pb2.FeedMessage, stop_id: str
) -> list[tuple[str, str, datetime, bool]]:
    """Return (trip_id, route_id, arrival_dt_utc, is_skipped) for trips touching stop_id."""
    out = []
    for entity in feed.entity:
        if not entity.HasField("trip_update"):
            continue
        tu = entity.trip_update
        for stu in tu.stop_time_update:
            if stu.stop_id != stop_id:
                continue
            skipped = (
                stu.schedule_relationship
                == gtfs_realtime_pb2.TripUpdate.StopTimeUpdate.SKIPPED
            )
            ts = 0
            if stu.HasField("arrival") and stu.arrival.time:
                ts = stu.arrival.time
            elif stu.HasField("departure") and stu.departure.time:
                ts = stu.departure.time
            if ts == 0 and not skipped:
                break
            dt = datetime.fromtimestamp(ts, tz=timezone.utc) if ts else None
            out.append((tu.trip.trip_id, tu.trip.route_id, dt, skipped))
            break
    return out


def load_route_names(route_ids: set[str]) -> dict[str, str]:
    result = {}
    with (DATA / "routes.txt").open() as f:
        for row in csv.DictReader(f):
            if row["route_id"] in route_ids:
                result[row["route_id"]] = row["route_short_name"]
    return result


def load_headsigns(trip_ids: set[str]) -> dict[str, str]:
    result = {}
    with (DATA / "trips.txt").open() as f:
        for row in csv.DictReader(f):
            if row["trip_id"] in trip_ids:
                result[row["trip_id"]] = row.get("trip_headsign", "")
    return result


def main() -> None:
    arg = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_STOP
    stop_id, stop_name = resolve_stop(arg)

    feed = fetch_feed()
    hits = arrivals_at_stop(feed, stop_id)

    now = datetime.now(timezone.utc)
    upcoming = [
        (trip_id, route_id, dt, skipped)
        for trip_id, route_id, dt, skipped in hits
        if not skipped and dt is not None and (dt - now).total_seconds() >= -60
    ]
    upcoming.sort(key=lambda x: x[2])
    upcoming = upcoming[:5]

    route_names = load_route_names({r for _, r, _, _ in upcoming})
    headsigns = load_headsigns({t for t, _, _, _ in upcoming})

    feed_age = int(now.timestamp()) - feed.header.timestamp
    label = f"{stop_name} ({stop_id})"
    if not upcoming:
        print(f"No upcoming arrivals at {label} (feed age {feed_age}s).")
        return

    print(
        f"Next arrivals at {label} "
        f"(as of {now.astimezone(LOCAL_TZ).strftime('%H:%M:%S %Z')}, "
        f"feed age {feed_age}s):"
    )
    for trip_id, route_id, dt, _ in upcoming:
        mins = max(0, int((dt - now).total_seconds() // 60))
        route = route_names.get(route_id, route_id)
        dest = headsigns.get(trip_id, "")
        print(
            f"  {dt.astimezone(LOCAL_TZ).strftime('%H:%M')}  "
            f"({mins:>2}m)  {route:<4}  →  {dest}"
        )


if __name__ == "__main__":
    main()
