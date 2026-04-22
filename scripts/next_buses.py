#!/usr/bin/env -S uv run --quiet
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx"]
# ///
"""Print the next 5 bus arrivals at a TfWM stop.

Accepts either a numeric `stop_id` (e.g. 43000320101) or a short `stop_code`
(e.g. nwmaptwp). Short codes are resolved to stop_ids via the GTFS
`stops.txt` feed checked into `data/`.

The REST Arrivals endpoint is keyed by (line, stop) with no "lines serving
stop" lookup, so we fan out across every bus line in parallel and merge.

Run with: uv run scripts/next_buses.py [stop_code_or_id]
"""

from __future__ import annotations

import asyncio
import csv
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import httpx

try:
    APP_ID = os.environ["TFWM_APP_ID"]
    APP_KEY = os.environ["TFWM_APP_KEY"]
except KeyError as e:
    raise SystemExit(f"missing env var {e.args[0]} (set TFWM_APP_ID and TFWM_APP_KEY)")
BASE = "http://api.tfwm.org.uk"
DEFAULT_STOP = "nwmaptwp"
CONCURRENCY = 32
STOPS_TXT = Path(__file__).parent.parent / "data" / "stops.txt"


def creds() -> dict[str, str]:
    return {"app_id": APP_ID, "app_key": APP_KEY, "formatter": "JSON"}


def resolve_stop(code_or_id: str) -> tuple[str, str]:
    """Return (stop_id, stop_name). Accepts either stop_id or stop_code."""
    if code_or_id.isdigit():
        with STOPS_TXT.open() as f:
            for row in csv.DictReader(f):
                if row["stop_id"] == code_or_id:
                    return code_or_id, row["stop_name"]
        return code_or_id, code_or_id
    with STOPS_TXT.open() as f:
        for row in csv.DictReader(f):
            if row["stop_code"] == code_or_id:
                return row["stop_id"], row["stop_name"]
    raise SystemExit(f"stop_code {code_or_id!r} not found in {STOPS_TXT}")


async def list_bus_lines(client: httpx.AsyncClient) -> list[str]:
    r = await client.get(f"{BASE}/Line/Mode/bus", params=creds())
    r.raise_for_status()
    return [line["Id"] for line in r.json()["ArrayOfLine"]["Line"]]


async def fetch_arrivals(
    client: httpx.AsyncClient,
    sem: asyncio.Semaphore,
    line_id: str,
    stop_id: str,
) -> list[dict]:
    async with sem:
        try:
            r = await client.get(
                f"{BASE}/Line/{line_id}/Arrivals/{stop_id}", params=creds()
            )
            r.raise_for_status()
        except httpx.HTTPError:
            return []
    return r.json().get("ArrayOfPrediction", {}).get("Prediction") or []


def parse_iso(s: str) -> datetime | None:
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None


def best_time(p: dict) -> datetime | None:
    return parse_iso(p.get("ExpectedArrival", "")) or parse_iso(
        p.get("ScheduledArrival", "")
    )


def dedupe(predictions: list[dict]) -> list[dict]:
    """API returns a scheduled and a live row per trip; prefer the live one."""
    by_key: dict[str, dict] = {}
    for p in predictions:
        sched = parse_iso(p.get("ScheduledArrival", ""))
        key = (
            f"{p.get('LineName')}|{int(sched.timestamp())}"
            if sched
            else p.get("Id", "")
        )
        is_live = bool(p.get("ExpectedArrival"))
        existing = by_key.get(key)
        if existing is None or (is_live and not existing.get("ExpectedArrival")):
            by_key[key] = p
    return list(by_key.values())


async def main() -> None:
    arg = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_STOP
    stop_id, stop_name = resolve_stop(arg)
    now = datetime.now(timezone.utc)

    async with httpx.AsyncClient(timeout=15.0) as client:
        lines = await list_bus_lines(client)
        sem = asyncio.Semaphore(CONCURRENCY)
        results = await asyncio.gather(
            *(fetch_arrivals(client, sem, lid, stop_id) for lid in lines)
        )

    upcoming = []
    for p in dedupe([p for batch in results for p in batch]):
        t = best_time(p)
        if t is None or (t - now).total_seconds() < -60:
            continue
        upcoming.append((t, p))
    upcoming.sort(key=lambda x: x[0])

    label = f"{stop_name} ({stop_id})" if stop_name != stop_id else stop_id
    if not upcoming:
        print(f"No upcoming arrivals at {label}.")
        return

    print(f"Next arrivals at {label} (as of {now.strftime('%H:%M:%S')} UTC):")
    for t, p in upcoming[:5]:
        mins = max(0, int((t - now).total_seconds() // 60))
        live = "live" if p.get("ExpectedArrival") else "sched"
        print(
            f"  {t.astimezone().strftime('%H:%M')}  "
            f"({mins:>2}m, {live})  "
            f"{p.get('LineName', '?'):<4}  →  {p.get('DestinationName', '?')}"
        )


if __name__ == "__main__":
    asyncio.run(main())
