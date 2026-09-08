# WeFit

A social fitness iOS app built with SwiftUI and Supabase. Log workouts, earn
points and streaks, join group challenges, set goals, and share progress in
a social feed — plus sync runs and lifts in automatically from Strava.

## Features

- **Auth** — email/password sign-up and sign-in via Supabase Auth
- **Workout logging** — running, weightlifting, and basketball, each with
  activity-specific detail screens
- **Gamification** — points and streaks for logged workouts
- **Challenges** — join group challenges and track progress toward a target
- **Goals** — set and track personal weekly goals
- **Social feed** — posts with likes, comments, and photo/video uploads
  (Supabase Storage)
- **Leaderboard** — see how you stack up against others
- **Strava integration** — connect your Strava account to auto-import runs,
  and weight-training sessions logged through [Hevy](https://hevyapp.com)
  (which syncs to Strava) get parsed into full exercise/set/rep/weight detail

## Tech stack

- **SwiftUI**, iOS 18+
- **Supabase**: Postgres, Auth, Storage
- **Strava API**: OAuth (`ASWebAuthenticationSession`) + REST for activity sync

## Setup

### 1. Supabase

`WeFit/Models/DatabaseManager.swift` already points at a working Supabase
project (the one this was originally built against), so the app runs without
any Supabase setup out of the box. If you want your own separate project
instead — e.g. to fully own your data going forward — create one at
[supabase.com](https://supabase.com), recreate the tables this app expects
(`profiles`/`users`, `workouts`, `running_workout_details`,
`weightlifting_workout_details`, `basketball_workout_details`, `challenges`,
`challenge_participants`, `goals`, `posts`, `post_likes`/comments — see
`Models/` for the exact shape each needs), and swap the URL/anon key in
`DatabaseManager.swift`.

### 2. Strava (optional — only needed for the sync feature)

1. Create an API app at [strava.com/settings/api](https://strava.com/settings/api).
   Note: Strava requires a paid Standard Tier subscription for API access as
   of June 2026 unless your app qualifies for Extended Access (10,000+ users).
2. Set **Authorization Callback Domain** to `localhost`.
3. Copy `StravaConfig.example.swift` to `WeFit/Models/StravaConfig.swift`
   (gitignored — never commit real credentials) and fill in your Client ID
   and Client Secret.

### 3. Run it

Open `WeFit.xcodeproj` in Xcode 16+, pick a simulator or device, and run.

## Project structure

```
WeFit/
  Models/       Data models + services (Supabase calls, Strava sync)
  Views/        SwiftUI views, grouped by feature
DevTools/       Manual test helpers for exercising Supabase queries
```

## Credit

Originally built with [Shawheen Ghezavat](https://github.com/shxwheen) as a
shared project; continuing development solo from here.
