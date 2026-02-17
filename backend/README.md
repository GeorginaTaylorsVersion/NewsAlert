# NewsAlarm Backend

Secure backend for iOS briefings with:
- scheduled precompute at `7:00`, `12:00`, `19:00`
- pull-based refresh for phone-only usage (no Apple Developer Program required)

The backend owns provider API keys and aggregates:
- NewsAPI
- NewsCatcher
- The Guardian
- FRED

Core endpoints:
- `GET /v1/briefing`
- `POST /v1/precompute` (manual trigger / testing)

## 1) Configure

```bash
cd /Users/georgina/Documents/NewsAlert/backend
cp .env.example .env
```

Set values in `.env`:
- `HOST` (`127.0.0.1` default, use `0.0.0.0` for LAN/device testing)
- `PORT` (default `8787`)
- `BACKEND_AUTH_TOKEN` (recommended)
- `BRIEFING_TIMEZONE` (example: `America/New_York`)
- `NEWSAPI_KEY`
- `NEWSCATCHER_API_KEY`
- `GUARDIAN_API_KEY`
- `FRED_API_KEY`

## 2) Run

```bash
cd /Users/georgina/Documents/NewsAlert/backend
npm run start
```

Health check:

```bash
curl http://localhost:8787/health
```

Briefing endpoint:

```bash
curl -H "Authorization: Bearer $BACKEND_AUTH_TOKEN" http://localhost:8787/v1/briefing
```

Manual precompute trigger:

```bash
curl -X POST \
  -H "Authorization: Bearer $BACKEND_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"briefingType":"noon"}' \
  http://localhost:8787/v1/precompute
```

## 3) iOS App Config

Set these app values (Info.plist / build settings / scheme env):
- `BACKEND_BASE_URL` (for simulator: `http://127.0.0.1:8787`)
- `BACKEND_AUTH_TOKEN` (must match backend if enabled)

Notes:
- For a physical device, `127.0.0.1` points to the phone itself. Use your Mac's LAN IP and same port.
- Endpoint guarantees payload shape `2 politics / 2 technology / 2 finance / 0 entertainment`.
- If source APIs fail, backend fills with fallback items so the payload contract remains valid.
- iOS must have:
  - Background App Refresh enabled
  - `UIBackgroundModes` including `fetch`
