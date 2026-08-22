# JustLetMePlay: agent quick start

Retail WoW addon that keeps you queued for Mythic+ in the Premade Group Finder
with two clicks instead of constant babysitting. Repo root **is** the addon
folder; symlink it as `<WoW>/_retail_/Interface/AddOns/JustLetMePlay`.

## Hard API constraints (everything follows from these)

- `C_LFGList.Search`, `ApplyToGroup`, `CancelApplication` are
  **hardware-event protected**: they may only be called inside a click/keypress
  call stack. Never call them from timers or event handlers. The single entry
  point is `Core:OnHardwareAction()` (widget click / keybind).
- **One protected action per hardware event.** Extra calls in the same click
  return without error but the server silently drops them (saw it in the debug
  log: 5 applies sent, only the first ever registered). So each click does
  exactly one thing: cancel one dead application, or apply to one group, or
  search. `CancelApplication` on a declined/timed-out entry also no-ops; those
  expire on their own.
- `Search` is **async**. Results arrive via `LFG_LIST_SEARCH_RESULTS_RECEIVED`
  (can fire twice per search; deduped by `GetTime()` in Core). One click can
  therefore only search; the next click applies. Hence the two-click flow.
- Group **titles/comments are opaque kstrings** (`|Kt…|k`): displayable, never
  parseable. Key levels cannot be read or filtered client-side.
- **Key-level filtering** rides on Blizzard's search box: text typed there
  (e.g. `10-12`) is kept when we call `LFGListSearchPanel_DoSearch` (holds up
  in-game, no taint). Fallback path: raw `C_LFGList.Search` plus a proxy
  filter on the leader's best-run level.
- Max **5 active applications** (server rule). The server confirms an
  application 1-3s after `ApplyToGroup`, so `ns.pendingApplies` counts
  unconfirmed sends. Without it rapid clicks over-apply.
- **Taint rule**: never write to Blizzard `LFGListFrame` state. Read-only
  access, `HookScript` post-hooks, and the `DoSearch` call are fine.

## Module map (load order in the .toc)

- `Debug.lua`: rolling 300-entry log in SavedVariables (see workflow below)
- `Core.lua`: event frame, DB init, state machine `IDLE→SEARCHED`,
  application/slot accounting, `OnHardwareAction` dispatch
- `Config.lua`: `/jlmp` slash commands plus right-click menu
- `Search.lua`: search trigger (blizzard/raw path), eligibility, scoring
  (needs-my-role, then age bucket, then level proximity), `HasSearchContext`
- `Apply.lua`: apply-to-top until cap, role flags from spec
- `Notify.lua`: sounds/pulses (slot freed, stale results)
- `Widget.lua`: movable button UI; hidden until a search context exists

State lives on the shared addon namespace `ns` (second vararg of each file).

## Dev workflow

- No build step. Edit, `/reload` in-game, test. The symlink makes repo edits
  live on next reload.
- Syntax check locally: `luajit -bl <file>.lua` (Lua 5.1 == WoW's dialect).
  Run over every .lua before committing.
- **Debug loop**: `/jlmp debug on` (off by default; off wipes the log), then
  the addon logs actions/searches/applies/status changes to
  `JustLetMePlayDB.debugLog`. SavedVariables flush on `/reload` or logout, then
  read `<WoW>/_retail_/WTF/Account/<ACCOUNT>/SavedVariables/JustLetMePlay.lua`.
  Log lines: `HH:MM:SS [tag] key=value…` with tags
  `action|search|results|pick|apply|app|debug`.
- Confirmed in-game so far: `LFGListSearchPanel_DoSearch` keeps the search-box
  text without taint; the raw 7-arg `C_LFGList.Search` works; `ApplyToGroup`,
  `GetApplicationInfo` order, and `leaderDungeonScoreInfo.bestRunLevel` behave
  as coded. Still open: `GetSearchResultMemberCounts` key names (assumed
  `TANK`/`HEALER`/`DAMAGER`) and whether the slot-freed sound
  (`SOUNDKIT.READY_CHECK` since v0.5.1) is loud enough without being annoying.
- TOC `## Interface` must track current retail (120100 = 12.1.x); bump when
  the client updates or the addon shows as out of date.

## Releases

CurseForge packages automatically when a tag is pushed (repo webhook): it
builds the zip itself from `.pkgmeta` (honors `ignore:`, substitutes
`@project-version@` in the .toc) and takes the changelog from `CHANGELOG.md`
(`manual-changelog` in `.pkgmeta`). Without that key it compiles the raw git
log, author emails included; never remove it. Cutting a release:

1. Add a `## vX.Y.Z` entry to `CHANGELOG.md`, player-facing highlights, not a
   commit log. Commit it with (or after) the work.
2. Annotated tag: `git tag -a vX.Y.Z -m "short summary"` (plain `git tag`
   fails, the repo wants tag messages). Push branch and tag; CurseForge takes
   it from there. A tag name containing "alpha" or "beta" uploads as that
   release type.
3. Also cut a GitHub release: `gh release create vX.Y.Z --title vX.Y.Z
   --notes "..."`, same highlights as the changelog entry. No zip asset
   needed, CurseForge builds its own.

Commits and tags must use the personal email. Repo-local
`git config user.email joel.junstrom@gmail.com` is set; never let the global
work address leak in, it ends up in the CurseForge changelog.

## Conventions

- Very few comments; only non-obvious constraints (mostly the
  hardware-event/taint rules above).
- Plain commit messages: no feat:/fix:/docs: prefixes, no AI-attribution
  trailers. Push to `origin main` (github.com/joeljunstrom/just-let-me-play).
- Docs read like a person wrote them: no em-dash chains, no stiff words like
  "utilize" or "leverage", no robotic "verified/ensured" phrasing.
