# Spike task #1 — verify the search path in-game

Goal: decide between the Blizzard-search-box path (default) and the raw-API
fallback, and confirm the protected calls work from our click handler.

## Setup

1. Symlink the repo as `Interface/AddOns/JustLetMePlay`, log in on a character
   with an M+-eligible ilvl.
2. `/console taintLog 1` (check `Logs/taint.log` afterwards).
3. Open Group Finder → Dungeons & Raids → Mythic+, type `10-12` in the search
   box, press its Search button once.

## Checklist

- [ ] Click the widget (Search). Verify chat/UI shows results and that the
      returned groups respect the `10-12` range — i.e. `LFGListSearchPanel_DoSearch`
      retained the box text.
- [ ] No taint errors in-session and nothing attributed to JustLetMePlay in
      `Logs/taint.log`.
- [ ] Click again (Apply). Verify `C_LFGList.ApplyToGroup` succeeds from our
      OnClick handler (applications appear in Blizzard's UI and widget shows n/5).
- [ ] Press the keybind twice instead of clicking — same behavior.
- [ ] `/jlmp mode raw`, click Search: verify the raw `C_LFGList.Search` call
      works and note its accepted arity (see uncertainty list below).
- [ ] Let one application expire → quiet sound + glow, count drops, next
      click-click refills.
- [ ] Spam-click to trigger `LFG_LIST_SEARCH_FAILED` → widget shows "Throttled",
      no Lua errors.

## API uncertainties to confirm while in there

1. `C_LFGList.Search` modern signature — code tries
   `Search(2, 0, 0, nil, nil, nil, activityIDs)` then falls back to `Search(2)`.
   Record what actually works (Search.lua `RawSearch`).
2. `C_LFGList.GetSearchResultMemberCounts(id)` key names — code assumes
   `TANK`/`HEALER`/`DAMAGER` member tallies (Search.lua `NeedsRole`).
3. `C_LFGList.GetApplicationInfo(id)` return order — code assumes
   `id, appStatus, pendingStatus, appDuration` (Core.lua, Widget.lua, Apply.lua).
4. `leaderDungeonScoreInfo` shape — single table with `bestRunLevel`, or array
   (Search.lua `LeaderBestRun` handles both).
5. `C_LFGList.GetRoles()` returns table or three booleans (Apply.lua `roleFlags`
   handles both).
6. Whether `SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON` is quiet enough (Notify.lua).

## Outcome

If DoSearch taints or drops the box text: set `useBlizzardSearchBox = false`
default, rely on `/jlmp levels` proxy filtering, and surface group titles in the
tooltip for an eyeball check before applying.
