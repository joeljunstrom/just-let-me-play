# JustLetMePlay — agent quick start

Retail WoW addon that keeps you queued for Mythic+ in the Premade Group Finder
with two clicks instead of constant babysitting. Repo root **is** the addon
folder; it is symlinked as
`/Applications/World of Warcraft/_retail_/Interface/AddOns/JustLetMePlay`.

## Hard API constraints (everything follows from these)

- `C_LFGList.Search`, `ApplyToGroup`, `CancelApplication` are
  **hardware-event protected**: they may only be called inside a click/keypress
  call stack. Never call them from timers or event handlers. The single entry
  point is `Core:OnHardwareAction()` (widget click / keybind).
- `Search` is **async** — results arrive via `LFG_LIST_SEARCH_RESULTS_RECEIVED`
  (can fire twice per search; deduped by `GetTime()` in Core). One click can
  therefore only search; the next click applies. Hence the two-click flow.
- Group **titles/comments are opaque kstrings** (`|Kt…|k`): displayable, never
  parseable. Key levels cannot be read or filtered client-side.
- **Key-level filtering** rides on Blizzard's search box: text typed there
  (e.g. `10-12`) is retained when we call `LFGListSearchPanel_DoSearch`
  (verified in-game, no taint). Fallback path: raw `C_LFGList.Search` +
  proxy filter on the leader's best-run level.
- Max **5 active applications** (server rule). Server confirms an application
  1–3s after `ApplyToGroup`, so `ns.pendingApplies` counts unconfirmed sends —
  without it rapid clicks over-apply.
- **Taint rule**: never write to Blizzard `LFGListFrame` state. Read-only
  access, `HookScript` post-hooks, and the `DoSearch` call are fine.

## Module map (load order in the .toc)

- `Debug.lua` — rolling 300-entry log in SavedVariables (see workflow below)
- `Core.lua` — event frame, DB init, state machine `IDLE→SEARCHED`,
  application/slot accounting, `OnHardwareAction` dispatch
- `Config.lua` — `/jlmp` slash commands + right-click menu
- `Search.lua` — search trigger (blizzard/raw path), eligibility, scoring
  (needs-my-role → age bucket → level proximity), `HasSearchContext`
- `Apply.lua` — apply-to-top until cap, role flags from spec
- `Notify.lua` — sounds/pulses (slot freed, stale results)
- `Widget.lua` — movable button UI; hidden until a search context exists

State lives on the shared addon namespace `ns` (second vararg of each file).

## Dev workflow

- No build step. Edit → in-game `/reload` → test. The symlink makes repo edits
  live on next reload.
- Syntax check locally: `/opt/homebrew/bin/luajit -bl <file>.lua`
  (Lua 5.1 == WoW's dialect). Run over every .lua before committing.
- **Debug loop**: the addon logs actions/searches/applies/status changes to
  `JustLetMePlayDB.debugLog`. SavedVariables flush on `/reload` or logout, then
  read
  `/Applications/World of Warcraft/_retail_/WTF/Account/JOELJUNSTROM/SavedVariables/JustLetMePlay.lua`.
  Log lines: `HH:MM:SS [tag] key=value…` with tags
  `action|search|results|pick|apply|app|debug`.
- `SPIKE.md` holds the in-game verification checklist and which API
  assumptions are confirmed vs open.
- TOC `## Interface` must track current retail (120100 = 12.1.x); bump when
  the client updates or the addon shows as out of date.

## Conventions

- Very few comments; only non-obvious constraints (mostly the
  hardware-event/taint rules above).
- Conventional commit messages, no AI-attribution trailers. Push to
  `origin main` (github.com/joeljunstrom/just-let-me-play).
