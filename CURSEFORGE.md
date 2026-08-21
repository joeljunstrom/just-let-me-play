# CurseForge listing

**Summary:** Keeps you topped up at 5 Mythic+ applications with two clicks — stop babysitting the Group Finder.

---

# JustLetMePlay

Queueing for Mythic+ means staring at the Group Finder: applications expire after 5 minutes, groups decline you, and every slot you get back has to be refilled by hand. JustLetMePlay turns that into two clicks so you can do world content, delves, or auction house errands while you wait.

## How it works

A small movable button shows your active applications (`3/5`) and glows when there's something to do:

1. **Click — Search.** Runs a Group Finder search and scores the results: groups that need your role first, then the freshest listings, then leaders whose best run is closest to your target key level. Groups that declined you (or whose invite you declined) are skipped for the session.
2. **Click — Apply.** Applies to the top-scored groups until you're back at the 5-application cap.

When a slot frees up — declined or expired — you get a quiet sound and the button glows. Click-click, back to playing. Getting accepted uses Blizzard's normal invite dialog.

## Key level filtering

Type your range once per session in Blizzard's search box (e.g. `10-12`) — every search from the button keeps it. Prefer the raw API? `/jlmp mode raw` approximates the range from the leader's best-run level instead.

## Configuration

`/jlmp` for everything: restrict to specific dungeons, override your role (auto-detects from spec), set target levels, toggle sounds. A keybind mirroring the button lives under Options → Keybindings → AddOns.

## Fair play

No automation: Blizzard protects search/apply behind real clicks, and this addon respects that — it just makes each click count. It never touches the Group Finder UI (no taint), uses no background polling, and costs nothing in FPS.
