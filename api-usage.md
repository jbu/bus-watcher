# TfWM API Usage

Notes on how the scripts under `scripts/` use the Transport for West Midlands
API. There are two implementations:

- `scripts/next_buses.py` — undocumented REST endpoints.
- `scripts/next_buses_rt.py` — documented GTFS + GTFS-RT feeds.

## Authentication

All requests are authenticated with `app_id` and `app_key` query parameters
obtained from the [TfWM API portal](https://api-portal.tfwm.org.uk). Both
scripts read these from the `TFWM_APP_ID` and `TFWM_APP_KEY` environment
variables.

No headers, no bearer tokens. `curl -I` (HEAD) returns `403` — use `GET`.

## Endpoints

### `GET /gtfs/tfwm_gtfs.zip`

Static GTFS schedule feed (~38 MB). Documented on the portal. We don't fetch
it at runtime; a snapshot is checked into `data/` and individual files
(`stops.txt`, `routes.txt`, `trips.txt`) are read locally to resolve short
stop codes and attach route/headsign names to live predictions.

### `GET /gtfs/trip_updates`

Documented GTFS-RT feed (~2.6 MB protobuf, ~1,700 active trip entities).
Used by `next_buses_rt.py`.

- Returned as `FeedMessage` protobuf; parse with `gtfs-realtime-bindings`.
- Each `TripUpdate` includes a `stop_time_update` for **every** stop on the
  trip, with an absolute `arrival.time` (unix seconds) — no delay
  propagation is required.
- `trip.route_id` is embedded in each entity; join with local `routes.txt`
  for the `route_short_name`, and `trips.txt` for the `trip_headsign`.
- `feed.header.timestamp` gives the feed's snapshot time — worth surfacing
  as "feed age" so stale data is obvious.

### `GET /Line/Mode/bus`

Undocumented REST endpoint that lists every bus line known to the API.
Returns ~387 lines keyed by numeric `Id` (e.g. `1144`) with a human-readable
`Name` (e.g. `11a`). Used by `next_buses.py` to enumerate line IDs for the
fan-out below.

### `GET /Line/{line_id}/Arrivals/{stop_id}`

Undocumented REST endpoint that returns predictions for a single line at a
single stop. Response shape:

```json
{"ArrayOfPrediction": {"Prediction": [
  {"LineName": "24", "DestinationName": "Bus Mall",
   "ExpectedArrival": "2026-04-22T10:43:00Z",
   "ScheduledArrival": "2026-04-22T10:42:00Z", ...}
]}}
```

There is **no endpoint that lists arrivals at a stop without a line**, so
`next_buses.py` fans out `/Line/{id}/Arrivals/{stop_id}` across every bus
line in parallel (concurrency 32), merges, dedupes, and sorts. Takes ~2 s.

## REST vs GTFS-RT

| | REST (`next_buses.py`) | GTFS-RT (`next_buses_rt.py`) |
|---|---|---|
| Documented | No | Yes |
| Requests per run | 388 (1 + fan-out) | 1 |
| Response | JSON per line | Single protobuf |
| Includes scheduled-but-not-yet-tripped buses | Yes | No — only trips currently in the RT feed |
| Destination field | `DestinationName` (next-segment "towards") | `trip_headsign` (trip's final destination) |

## Network Usage

Measured payloads (April 2026):

| | REST (iOS app, known lines) | REST (fan-out, unknown lines) | GTFS-RT |
|---|---|---|---|
| Requests per refresh | ~6 (1–3 per stop × 3–4 stops) | ~388 (1 + 387 lines) | 1 |
| Populated response | ~25 KB JSON | ~25 KB per hit, ~7 hits typical | 2.6 MB protobuf |
| Empty response | — | 56 B × ~380 | — |
| Total per refresh | ~150 KB | ~200 KB + 380 TLS round-trips | 2.6 MB |
| At 30 s cadence | ~18 MB/hr | ~24 MB/hr | ~312 MB/hr |

Notes:

- **Server does no compression.** `Accept-Encoding: gzip/br` is ignored on
  both endpoints. The protobuf would gzip 3.3× (2.6 MB → 775 KB) if the
  server served it compressed, but you can't ask for it.
- **GTFS-RT is fixed-size regardless of how many stops you watch** — ~17×
  the bytes of the REST path for the typical "few known stops" case.
- **REST scales with stops, not fleet size.** The iOS app's
  "know-the-lines, query-only-those" pattern is extremely cheap
  (sub-200 KB per refresh for any practical number of stops).
- **Request count matters on cellular.** 388 REST fan-out requests incur
  real TLS/HTTP overhead even when each response is tiny — fine for
  one-off discovery, unsuitable for polling.
- **Implication for the iOS app:** fetching GTFS-RT on-device at the app's
  30 s cadence would be ~300 MB/hr while the user is near a stop —
  impractical on cellular. The realistic GTFS-RT pattern for a
  battery/data-constrained client is a backend that pulls the feed once
  per fleet and serves filtered JSON down to the phone.

## Quirks

- **Short `stop_code` values don't work on the REST Arrivals endpoint.**
  GTFS defines both `stop_id` (numeric, e.g. `43000320101`) and `stop_code`
  (short, e.g. `nwmaptwp`). The Arrivals endpoint accepts short codes
  without returning an error but silently returns an empty prediction list.
  Both scripts resolve short codes to numeric IDs via `data/stops.txt`
  before querying.

- **Scheduled + live rows per trip (REST only).** The REST API often
  returns two predictions per upcoming trip: one with `ExpectedArrival`
  populated (live) and one without (scheduled-only). The script dedupes by
  `(LineName, ScheduledArrival)` and prefers the live row. GTFS-RT has
  one record per trip/stop.

- **Past arrivals leak in.** Predictions with an expected time more than
  60 s in the past are filtered out in both scripts.

- **Coverage gap in GTFS-RT.** The RT feed only includes currently-tracked
  trips, so at quiet stops the next scheduled bus may not appear until it
  enters the feed. For comprehensive coverage you'd need to also join with
  the static GTFS schedule (`stop_times.txt` + `calendar.txt`).

- **REST endpoints are undocumented.** They're reachable with the same
  credentials but aren't listed on the portal, so availability isn't
  guaranteed. GTFS-RT is the portable choice.
