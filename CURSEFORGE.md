# CurseForge listing

**Summary:** Keeps you topped up at 5 Mythic+ applications with a few quick clicks. Stop babysitting the Group Finder.

---

# JustLetMePlay

Queueing for Mythic+ means staring at the Group Finder: refresh the search, scroll, click a group, sign up in the role prompt, over and over as applications expire after 5 minutes or get declined. JustLetMePlay shrinks that whole loop to a click per action, no window, no scrolling, so you can do world content, delves, or auction house errands while you wait.

## How it works

A small movable button shows your active applications (`3/5`) and glows when there's something to do. Each click does the one thing that helps most right now:

1. **Cancel** an application that's going nowhere (group delisted or your role filled while they let you hang).
2. **Apply** to the next best group from the last search. Results are scored: groups that need your role first, then the freshest listings, then leaders whose best run is closest to your target key level. Groups that declined you (or whose invite you declined) are skipped for the session.
3. **Search** when there's nothing left to apply to.

When a slot frees up (declined or expired) you get a quiet sound and the button glows. A few quick clicks, back to playing. Getting accepted uses Blizzard's normal invite dialog.

## Key level filtering

Type your range once per session in Blizzard's search box (e.g. `10-12`) and every search from the button keeps it. Prefer the raw API? `/jlmp mode raw` approximates the range from the leader's best-run level instead.

## Configuration

`/jlmp` for everything: restrict to specific dungeons, override your role (auto-detects from spec), set target levels, toggle sounds. A keybind mirroring the button lives under Options → Keybindings → AddOns.

## Fair play

No automation: Blizzard protects search/apply behind real clicks, and this addon respects that. It just makes each click count. It never touches the Group Finder UI (no taint), uses no background polling, and costs nothing in FPS.
