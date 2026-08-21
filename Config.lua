local _, ns = ...

local Config = {}
ns.Config = Config

local ROLES = { tank = "TANK", healer = "HEALER", dps = "DAMAGER", any = "ANY" }
local GROUP_FINDER_CATEGORY_DUNGEONS = 2

local function say(msg)
  print("|cff33ff99JustLetMePlay|r: " .. msg)
end

local function listDungeons()
  local activities = C_LFGList.GetAvailableActivities(GROUP_FINDER_CATEGORY_DUNGEONS)
  if not activities or #activities == 0 then
    say("No activities available yet (open the Group Finder once).")
    return
  end
  for _, id in ipairs(activities) do
    local info = C_LFGList.GetActivityInfoTable(id)
    local name = info and (info.fullName or info.shortName) or "?"
    local marker = ns.db.activityIDs[id] and " |cff33ff99(selected)|r" or ""
    say(("%d - %s%s"):format(id, name, marker))
  end
end

local function handleDungeons(rest)
  local action, idText = rest:match("^(%S*)%s*(.-)$")
  if action == "" or action == "list" then
    listDungeons()
  elseif action == "clear" then
    wipe(ns.db.activityIDs)
    say("Dungeon filter cleared (searching all).")
  elseif action == "add" or action == "remove" then
    local id = tonumber(idText)
    if not id then
      say("Usage: /jlmp dungeons add|remove <activityID>")
      return
    end
    ns.db.activityIDs[id] = (action == "add") and true or nil
    say(("Activity %d %s."):format(id, action == "add" and "added" or "removed"))
  else
    say("Usage: /jlmp dungeons [list|add <id>|remove <id>|clear]")
  end
end

local function handleRole(rest)
  if rest == "auto" or rest == "" then
    ns.db.roleOverride = nil
    say("Role: auto (from current spec).")
  elseif ROLES[rest] then
    ns.db.roleOverride = ROLES[rest]
    say("Role override: " .. rest .. ".")
  else
    say("Usage: /jlmp role tank|healer|dps|any|auto")
  end
end

local function handleLevels(rest)
  if rest == "off" then
    ns.db.targetLevelMin, ns.db.targetLevelMax = nil, nil
    say("Target level range cleared.")
    return
  end
  local minLevel, maxLevel = rest:match("^(%d+)%s*-%s*(%d+)$")
  if not minLevel then
    minLevel = rest:match("^(%d+)$")
    maxLevel = minLevel
  end
  if not minLevel then
    say("Usage: /jlmp levels <min>-<max> or /jlmp levels off")
    return
  end
  ns.db.targetLevelMin = tonumber(minLevel)
  ns.db.targetLevelMax = tonumber(maxLevel)
  say(("Target levels %d-%d (scoring + raw-mode proxy filter). Remember to also type it in Blizzard's search box."):format(
    ns.db.targetLevelMin, ns.db.targetLevelMax))
end

local function showHelp()
  say("commands:")
  say("/jlmp dungeons [list|add <id>|remove <id>|clear] - pick dungeons")
  say("/jlmp role tank|healer|dps|any|auto - role for applications")
  say("/jlmp levels <min>-<max>|off - target key levels")
  say("/jlmp sounds on|off")
  say("/jlmp mode blizzard|raw - search via Blizzard's box (keeps typed range) or raw API")
  say("/jlmp debug on|off - action log for troubleshooting")
end

local function handle(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  if cmd == "dungeons" then
    handleDungeons(rest)
  elseif cmd == "role" then
    handleRole(rest)
  elseif cmd == "levels" then
    handleLevels(rest)
  elseif cmd == "sounds" then
    ns.db.sounds = rest ~= "off"
    say("Sounds " .. (ns.db.sounds and "on" or "off") .. ".")
  elseif cmd == "debug" then
    ns.db.debugEnabled = rest == "on"
    if not ns.db.debugEnabled then
      ns.db.debugLog = nil
    end
    say("Debug logging " .. (ns.db.debugEnabled and "on (flushed to SavedVariables on /reload)" or "off (log wiped)") .. ".")
  elseif cmd == "mode" then
    if rest == "blizzard" or rest == "raw" then
      ns.db.useBlizzardSearchBox = rest == "blizzard"
      say("Search mode: " .. rest .. ".")
    else
      say("Usage: /jlmp mode blizzard|raw")
    end
  else
    showHelp()
  end
end

SLASH_JUSTLETMEPLAY1 = "/jlmp"
SlashCmdList.JUSTLETMEPLAY = handle

function Config:OpenMenu(owner)
  if not MenuUtil or not MenuUtil.CreateContextMenu then
    say("Right-click menu unavailable; use /jlmp.")
    return
  end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle("JustLetMePlay")

    local role = root:CreateButton("Role")
    local function roleRadio(label, value)
      role:CreateRadio(label, function()
        return ns.db.roleOverride == value
      end, function()
        ns.db.roleOverride = value
      end)
    end
    roleRadio("Auto (spec)", nil)
    roleRadio("Tank", "TANK")
    roleRadio("Healer", "HEALER")
    roleRadio("DPS", "DAMAGER")
    roleRadio("Any", "ANY")

    root:CreateCheckbox("Sounds", function()
      return ns.db.sounds
    end, function()
      ns.db.sounds = not ns.db.sounds
    end)

    root:CreateCheckbox("Use Blizzard search box", function()
      return ns.db.useBlizzardSearchBox
    end, function()
      ns.db.useBlizzardSearchBox = not ns.db.useBlizzardSearchBox
    end)

    root:CreateButton("Dungeon list (chat)", function()
      listDungeons()
    end)
  end)
end
