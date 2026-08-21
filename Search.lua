local _, ns = ...

local Search = {}
ns.Search = Search

local GROUP_FINDER_CATEGORY_DUNGEONS = 2
local ROLE_LIMITS = { TANK = 1, HEALER = 1, DAMAGER = 3 }

function Search:MyRole()
  local override = ns.db.roleOverride
  if override and override ~= "ANY" then
    return override
  end
  local spec = GetSpecialization()
  local role = spec and GetSpecializationRole(spec)
  return role or "DAMAGER"
end

-- A search context exists when the user has set up what they want: typed
-- something in Blizzard's M+ search box, or configured dungeons via /jlmp.
-- Without one, searching would apply to arbitrary groups.
function Search:HasSearchContext()
  local panel = LFGListFrame and LFGListFrame.SearchPanel
  if panel and panel.categoryID == GROUP_FINDER_CATEGORY_DUNGEONS then
    local text = panel.SearchBox and panel.SearchBox:GetText() or ""
    if text ~= "" then return true end
  end
  if next(ns.db.activityIDs) then return true end
  return not ns.db.useBlizzardSearchBox and ns.db.targetLevelMin ~= nil
end

-- The Blizzard path only filters through the typed box text, so an empty box
-- would run a wide-open search; require text and fall back to raw otherwise.
local function blizzardPanelUsable()
  local panel = LFGListFrame and LFGListFrame.SearchPanel
  if not (panel and panel.categoryID == GROUP_FINDER_CATEGORY_DUNGEONS
    and LFGListSearchPanel_DoSearch) then
    return false
  end
  local text = panel.SearchBox and panel.SearchBox:GetText() or ""
  return text ~= ""
end

-- Hardware-event context only: C_LFGList.Search is protected.
function Search:Trigger()
  ns.pendingSearch = true
  if ns.db.useBlizzardSearchBox and blizzardPanelUsable() then
    ns.lastSearchPath = "blizzard"
    local boxText = LFGListFrame.SearchPanel.SearchBox and LFGListFrame.SearchPanel.SearchBox:GetText() or "?"
    ns.Debug:Log("search", "trigger path=blizzard boxText=" .. boxText)
    LFGListSearchPanel_DoSearch(LFGListFrame.SearchPanel)
  else
    ns.lastSearchPath = "raw"
    ns.Debug:Log("search", "trigger path=raw (panelUsable=" .. tostring(blizzardPanelUsable() or false) .. ")")
    self:RawSearch()
  end
end

function Search:RawSearch()
  local ids
  if next(ns.db.activityIDs) then
    ids = {}
    for id in pairs(ns.db.activityIDs) do
      ids[#ids + 1] = id
    end
  end
  -- Search arity has shifted across patches; fall back to the minimal call if
  -- the full modern signature is rejected.
  local ok, err = pcall(C_LFGList.Search, GROUP_FINDER_CATEGORY_DUNGEONS, 0, 0, nil, nil, nil, ids)
  ns.Debug:Log("search", "raw 7-arg ok=" .. tostring(ok) .. (err and (" err=" .. tostring(err)) or ""))
  if not ok then
    C_LFGList.Search(GROUP_FINDER_CATEGORY_DUNGEONS)
  end
end

function Search:LeaderBestRun(info)
  local score = info.leaderDungeonScoreInfo
  if not score then return nil end
  if score.bestRunLevel then return score.bestRunLevel end
  if score[1] and score[1].bestRunLevel then return score[1].bestRunLevel end
  return nil
end

function Search:TargetMid()
  local minLevel, maxLevel = ns.db.targetLevelMin, ns.db.targetLevelMax
  if minLevel and maxLevel then
    return (minLevel + maxLevel) / 2
  end
end

function Search:PassesProxyFilter(info)
  local minLevel, maxLevel = ns.db.targetLevelMin, ns.db.targetLevelMax
  if not minLevel or not maxLevel then return true end
  local best = self:LeaderBestRun(info)
  if not best then return true end
  return best >= minLevel - 2 and best <= maxLevel + 2
end

function Search:NeedsRole(id, role)
  local counts = C_LFGList.GetSearchResultMemberCounts(id)
  if not counts then return true end
  local have = counts[role]
  if have == nil then return true end
  return have < (ROLE_LIMITS[role] or 3)
end

-- With the ANY override we cannot tell which role the user would fill, so
-- assume space rather than filtering or cancelling wrongly.
function Search:RoleHasSpace(id)
  if ns.db.roleOverride == "ANY" then return true end
  return self:NeedsRole(id, self:MyRole())
end

-- The dungeon checkboxes must hold on both search paths: the raw path passes
-- them to C_LFGList.Search, but the Blizzard-box path returns whatever the
-- typed text matches, so filter results here too.
function Search:MatchesDungeonFilter(info)
  if not next(ns.db.activityIDs) then return true end
  if info.activityID and ns.db.activityIDs[info.activityID] then return true end
  for _, id in ipairs(info.activityIDs or {}) do
    if ns.db.activityIDs[id] then return true end
  end
  return false
end

function Search:Eligible(id, info)
  if info.isDelisted then return false end
  if not self:MatchesDungeonFilter(info) then return false end
  if ns.sessionDeclined[id] then return false end
  if ns.pendingApplies[id] then return false end
  if not self:RoleHasSpace(id) then return false end
  local _, appStatus = C_LFGList.GetApplicationInfo(id)
  if appStatus and appStatus ~= "none" then return false end
  if ns.lastSearchPath == "raw" and not self:PassesProxyFilter(info) then return false end
  return true
end

function Search:CollectAndScore()
  wipe(ns.results)
  wipe(ns.resultInfo)

  local _, ids = C_LFGList.GetSearchResults()
  if not ids then
    ns.searchedAt = GetTime()
    return
  end

  local role = self:MyRole()
  for _, id in ipairs(ids) do
    local info = C_LFGList.GetSearchResultInfo(id)
    if info and self:Eligible(id, info) then
      ns.results[#ns.results + 1] = id
      ns.resultInfo[id] = {
        name = info.name,
        age = info.age or 0,
        bestRunLevel = self:LeaderBestRun(info),
        needsMyRole = self:NeedsRole(id, role),
      }
    end
  end

  ns.Debug:Log("results", ("total=%d eligible=%d role=%s"):format(#ids, #ns.results, role))

  local targetMid = self:TargetMid()
  table.sort(ns.results, function(a, b)
    local ia, ib = ns.resultInfo[a], ns.resultInfo[b]
    if ia.needsMyRole ~= ib.needsMyRole then
      return ia.needsMyRole
    end
    -- Age bucketed to minutes so level proximity can break near-ties in freshness.
    local bucketA, bucketB = math.floor(ia.age / 60), math.floor(ib.age / 60)
    if bucketA ~= bucketB then
      return bucketA < bucketB
    end
    if targetMid and ia.bestRunLevel and ib.bestRunLevel then
      local distA = math.abs(ia.bestRunLevel - targetMid)
      local distB = math.abs(ib.bestRunLevel - targetMid)
      if distA ~= distB then
        return distA < distB
      end
    end
    return ia.age < ib.age
  end)

  for rank = 1, math.min(5, #ns.results) do
    local id = ns.results[rank]
    local entry = ns.resultInfo[id]
    ns.Debug:Log("pick", ("#%d id=%s name=%s age=%d bestRun=%s needsRole=%s"):format(
      rank, tostring(id), tostring(entry.name), entry.age,
      tostring(entry.bestRunLevel), tostring(entry.needsMyRole)))
  end

  ns.searchedAt = GetTime()
end
