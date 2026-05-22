# Startup Migration Record

- `EntryAbility` now loads `app/StartupPage` as the application entry page.
- `main_pages.json` keeps legacy routes but registers `app/StartupPage` first.
- `StartupPage` routes into `StartupDecision.getInitialRoute(false)`, which currently opens the goal setup flow until goal persistence is implemented.
- Startup routing tests in `entry/src/test` and `entry/src/ohosTest` now assert the new startup entry.
