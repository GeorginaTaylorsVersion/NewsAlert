# NewsAlarm (NewsAlert iOS Project)

Multisource iOS news briefing app built with SwiftUI + a lightweight Node backend.

This project delivers timed briefings from multiple providers, clusters coverage into stories, and presents a clean reading flow on iPhone.

## What This Project Does

- iOS app (SwiftUI, iOS 17+) with two tabs:
  - `Briefings`
  - `Explore`
- Schedules local reminders at:
  - `7:00 AM`
  - `12:00 PM`
  - `7:00 PM`
- Aggregates real news from backend providers:
  - NewsAPI
  - NewsCatcher
  - The Guardian
  - FRED
- Current briefing layout is:
  - `2 Politics`
  - `2 Technology`
  - `2 Finance`
  - `0 Entertainment`
- Uses long condensed summaries (minimum ~160 words).
- Supports background refresh (`BGAppRefreshTask`) and pull-to-refresh.
- Works in phone-only mode (no APNs required).

## Architecture

- iOS:
  - SwiftUI + MVVM
  - Repository pattern
  - Local cache for last successful stories
  - `UNUserNotificationCenter` for local notifications
- Backend:
  - Node.js HTTP server (`backend/server.js`)
  - Scheduled precompute at `7 / 12 / 19` (timezone configurable)
  - Secure endpoint: `GET /v1/briefing`

## Project Structure

```text
NewsAlert/
├── NewsAlert/                # iOS app source (SwiftUI + MVVM)
├── NewsAlert.xcodeproj       # Xcode project
├── NewsAlert-Info.plist      # App plist with config keys
├── backend/                  # Node backend
│   ├── server.js
│   ├── .env.example
│   └── README.md
└── deploy-testflight.sh      # Optional deployment helper
```

## Prerequisites

- Xcode 15+ (iOS 17+ target)
- Node.js 18+ (20+ recommended)
- iPhone on same Wi-Fi as your Mac (for phone-only runtime testing)

## Local Setup

### 1) Backend

```bash
cd /Users/georgina/Documents/NewsAlert/backend
cp .env.example .env
```

Update `/Users/georgina/Documents/NewsAlert/backend/.env`:

- `HOST=0.0.0.0` (required for iPhone over LAN)
- `PORT=8787`
- `BACKEND_AUTH_TOKEN=` (empty for easiest local device testing)
- Add your provider keys:
  - `NEWSAPI_KEY`
  - `NEWSCATCHER_API_KEY`
  - `GUARDIAN_API_KEY`
  - `FRED_API_KEY`

Start backend:

```bash
cd /Users/georgina/Documents/NewsAlert/backend
npm run start
```

Verify health:

```bash
curl http://127.0.0.1:8787/health
```

### 2) iOS app config

In Xcode `Target > Build Settings`, set:

- `INFOPLIST_KEY_BACKEND_BASE_URL` (Debug) = `http://<YOUR_MAC_LAN_IP>:8787`
- `INFOPLIST_KEY_BACKEND_AUTH_TOKEN` = empty (or match backend token if enabled)

Note:
- `127.0.0.1` works for simulator, **not** physical iPhone.
- For iPhone, use your Mac LAN IP (for example `192.168.x.x`).

### 3) Run the app

- Connect iPhone to Xcode once to install the app.
- Run scheme `NewsAlert`.
- Confirm:
  - Briefings load from backend
  - Pull-to-refresh works
  - Notifications are scheduled

## Validate True Phone-Only Flow (No Xcode Connected)

1. Keep backend running on Mac.
2. On iPhone Safari, open:
   - `http://<YOUR_MAC_LAN_IP>:8787/health`
3. Unplug phone, close Xcode.
4. Open app on phone, pull-to-refresh.
5. Confirm feed updates and shows `2 / 2 / 2 / 0`.

## Upload This Project to GitHub

## Important: clean secrets first

Before pushing, remove or rotate any real API keys from tracked files.

You currently have provider keys in:
- `/Users/georgina/Documents/NewsAlert/NewsAlert.xcodeproj/project.pbxproj`

Recommended:
- Replace keys in build settings with placeholders.
- Keep real secrets in local-only environment/config.
- Rotate exposed keys in provider dashboards if they were ever committed.

### Create and push repository

```bash
cd /Users/georgina/Documents/NewsAlert
git status
git add .
git commit -m "Initial commit: NewsAlarm iOS app + backend"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

If remote already exists:

```bash
git remote set-url origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

### Verify on GitHub

- README displays correctly
- `.env` is not uploaded
- No API keys are visible in source

## Troubleshooting

- iPhone cannot reach backend:
  - Check same Wi-Fi network
  - Confirm `HOST=0.0.0.0`
  - Confirm Mac firewall allows Node on port `8787`
- `401 Unauthorized` from `/v1/briefing`:
  - Clear `BACKEND_AUTH_TOKEN` in backend and app for local testing
  - Or ensure both sides use identical token
- App shows stale data:
  - Pull to refresh
  - Restart backend
  - Reopen app

