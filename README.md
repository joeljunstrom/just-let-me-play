# JustLetMePlay

Low-effort Mythic+ Premade Group Finder queueing for WoW retail. Keeps you topped
up at the 5-application cap with a few clicks instead of babysitting the group browser.

## How it works

Blizzard protects `C_LFGList.Search`, `ApplyToGroup` and `CancelApplication`
behind hardware events: they only run inside a real click or keypress, and the
server honors just one such action per click. So each widget click (or keybind
press) does exactly one thing, picked by priority:

1. **Cancel** an application that can't work out anymore (group delisted, or
   your role filled while they let you hang).
2. **Apply** to the next best group from the last search. Results are scored:
   groups that need your role first, then freshest listings, then leader
   best-run level closest to your target range. Already-applied groups, groups
   that declined you, and groups whose invite you declined this session are
   skipped.
3. **Search** when there is nothing left to apply to.

Filling all 5 slots from scratch is a search plus five clicks. Click as fast as
you like; each click is one action.

Shift-click leaves your oldest application, the one you've waited
on longest, and blacklists that group for the session. Handy when a leader lets
you hang and you'd rather chase a fresh group.

The widget stays hidden until you have something to search for: text in
Blizzard's M+ search box, or dungeons picked with `/jlmp dungeons`. It shows
`n/5` active applications, glows when there are results to apply to,
and its tooltip lists active applications with time left plus the next scored
picks. Drag to move, right-click for options. When a slot frees up (declined or
expired application) you get a quiet sound and a glow; when results go stale
while you are below 5, the widget pulses. Accepted invites use Blizzard's own
dialog, no extra notification.

## Install

The repo root is the addon folder. Symlink it into your AddOns directory:

```
ln -s /path/to/this/repo "/path/to/World of Warcraft/_retail_/Interface/AddOns/JustLetMePlay"
```

## Once per session: type your key range

Addons cannot put text into Blizzard's search box, but they can re-run a search
that reuses what is already typed there. So once per session:

1. Open Group Finder → Dungeons & Raids → Mythic+ (the search panel).
2. Type your key range in the search box, e.g. `10-12`, and search once.

Every widget search after that inherits the range. If you skip this (or flip
`/jlmp mode raw`), the addon searches via the raw API instead and approximates
the range with a proxy filter on the leader's best-run level
(`/jlmp levels 10-12`).

## Configuration

`/jlmp` in chat:

- `/jlmp dungeons [list|add <id>|remove <id>|clear]`: restrict to specific dungeons
- `/jlmp role tank|healer|dps|any|auto`: role used when applying (auto = current spec)
- `/jlmp levels <min>-<max>|off`: target key levels (scoring tiebreak + raw-mode filter)
- `/jlmp sounds on|off`
- `/jlmp mode blizzard|raw`: search through Blizzard's box or the raw API
- `/jlmp autocancel on|off`: on your next click, drop applications where the
  group delisted or your role filled up (on by default)
- `/jlmp show always|auto`: keep the widget visible even without a search;
  clicking it then opens the Group Finder so you can type one
- `/jlmp debug on|off`: troubleshooting log (off wipes it), written to
  SavedVariables on `/reload`

A keybind mirroring the widget click is under Options → Keybindings → AddOns.

## Releasing

CurseForge packages automatically via a webhook on this repo (`.pkgmeta`
controls the folder name and which files ship). The TOC version is stamped
from the git tag (`@project-version@`), so a release is just:

```
git tag -a vX.Y.Z -m "short note"
git push origin main --tags
```

Every untagged push builds an alpha file on CurseForge; tags build releases
(a tag containing "beta" or "alpha" is marked as such). No manual zips.
For a GitHub release mirror: `git archive --format=zip --prefix=JustLetMePlay/
-o ../JustLetMePlay.zip vX.Y.Z` and attach with `gh release create`.

Locally the addon list shows the literal `@project-version@`; that's the
packager token, only CurseForge builds get the real version.

## Status

Works. Tested in-game: searches keep the key range you typed, no taint errors,
and applications show up in the Blizzard UI as expected. Applications can't be
auto-cancelled (also protected), they just expire.
