local _, ns = ...

BINDING_HEADER_JUSTLETMEPLAY = "JustLetMePlay"
BINDING_NAME_JUSTLETMEPLAY_ACTION = "Search / Apply"

local Core = {}
ns.Core = Core

ns.MAX_APPLICATIONS = 5
ns.state = "IDLE"
ns.results = {}
ns.resultInfo = {}
ns.sessionDeclined = {}
ns.pendingApplies = {}
ns.pendingSearch = false
ns.lastSearchPath = "blizzard"

local defaults = {
  activityIDs = {},
  sounds = true,
  useBlizzardSearchBox = true,
  debugEnabled = false,
  autoCancel = true,
  alwaysShow = false,
}

function Core:InitDB()
  JustLetMePlayDB = JustLetMePlayDB or {}
  for key, value in pairs(defaults) do
    if JustLetMePlayDB[key] == nil then
      if type(value) == "table" then
        JustLetMePlayDB[key] = {}
      else
        JustLetMePlayDB[key] = value
      end
    end
  end
  ns.db = JustLetMePlayDB
  ns.Debug:StartSession()
end

function Core:ActiveApplicationCount()
  local count = 0
  for _, id in ipairs(C_LFGList.GetApplications()) do
    local _, appStatus = C_LFGList.GetApplicationInfo(id)
    if appStatus == "applied" or appStatus == "invited" then
      count = count + 1
    end
  end
  return count
end

-- Applications sent this session that the server has not yet confirmed via
-- LFG_LIST_APPLICATION_STATUS_UPDATED; without this a second click within the
-- confirmation window applies past the 5-cap. Confirmation lands within ~1s in
-- practice, so a pending entry older than 3s means the server silently ignored
-- the apply (full group, delisted) and it must not inflate the count. Worst
-- case on a laggy realm the count dips early and the server's own cap rejects
-- the extra apply, which is harmless.
function Core:PendingApplyCount()
  local now = GetTime()
  local count = 0
  for id, sentAt in pairs(ns.pendingApplies) do
    local _, appStatus = C_LFGList.GetApplicationInfo(id)
    if (appStatus and appStatus ~= "none") or now - sentAt > 3 then
      ns.pendingApplies[id] = nil
    else
      count = count + 1
    end
  end
  return count
end

function Core:FreeSlots()
  return math.max(0, ns.MAX_APPLICATIONS - self:ActiveApplicationCount() - self:PendingApplyCount())
end

-- C_LFGList.Search and ApplyToGroup are hardware-event protected: this function
-- must only be reached from a click or keybind call stack, never from a timer
-- or event handler.
-- One protected action per click, by priority: drop a dead application,
-- else apply to the next scored group, else search.
function Core:OnHardwareAction()
  ns.Debug:Log("action", ("state=%s results=%d free=%d"):format(ns.state, #ns.results, self:FreeSlots()))
  if ns.Apply:CancelOneDead() then
    -- click spent
  elseif ns.state == "SEARCHED" and #ns.results > 0 and self:FreeSlots() > 0 then
    ns.Apply:ApplyNext()
  elseif ns.Search:HasSearchContext() then
    ns.Search:Trigger()
  else
    -- Nothing sane to search for (empty box after a /reload, no configured
    -- dungeons); searching now would apply to random groups. Navigate to the
    -- premade dungeons search panel so the user can type their range.
    self:OpenDungeonSearchPanel()
    print("|cff33ff99JustLetMePlay|r: type your search (e.g. |cffffff7810-12|r) in the Group Finder box first.")
  end
  ns.Widget:Refresh()
  C_Timer.After(6, function() ns.Widget:Refresh() end)
end

function Core:OpenDungeonSearchPanel()
  if not PVEFrame_ShowFrame then return end
  pcall(PVEFrame_ShowFrame, "GroupFinderFrame", "LFGListPVEStub")
  local category = LFGListFrame and LFGListFrame.CategorySelection
  if category and LFGListCategorySelection_SelectCategory and LFGListCategorySelection_StartFindGroup then
    pcall(LFGListCategorySelection_SelectCategory, category, 2, 0)
    pcall(LFGListCategorySelection_StartFindGroup, category)
  end
end

-- Same hardware-event rule as OnHardwareAction: one cancel per click.
function Core:OnUnsignAction()
  ns.Debug:Log("action", "unsign requested")
  ns.Apply:CancelOldest()
  ns.Widget:Refresh()
  C_Timer.After(6, function() ns.Widget:Refresh() end)
end

function JustLetMePlay_OnKeybind()
  Core:OnHardwareAction()
end

local DECLINE_STATUSES = {
  declined = true,
  declined_full = true,
  declined_delisted = true,
  invitedeclined = true,
}

function Core:OnApplicationUpdate(id, newStatus)
  ns.pendingApplies[id] = nil
  ns.Debug:Log("app", ("id=%s status=%s active=%d"):format(tostring(id), tostring(newStatus), self:ActiveApplicationCount()))
  if DECLINE_STATUSES[newStatus] then
    ns.sessionDeclined[id] = true
  end
  -- invitedeclined is the user actively declining at the keyboard; no sound needed.
  if newStatus == "declined" or newStatus == "declined_full" or newStatus == "declined_delisted"
    or newStatus == "timedout" or newStatus == "failed" then
    ns.Notify:SlotFreed()
  end
end

function Core:CheckStale()
  ns.Widget:Refresh()
  if not ns.Search:HasSearchContext() then return end
  if self:ActiveApplicationCount() >= ns.MAX_APPLICATIONS then return end
  if not ns.searchedAt or GetTime() - ns.searchedAt > 60 then
    ns.Notify:Stale()
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
frame:RegisterEvent("LFG_LIST_SEARCH_FAILED")
frame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
frame:RegisterEvent("GROUP_JOINED")

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    Core:InitDB()
    ns.Widget:Init()
    C_Timer.NewTicker(15, function() Core:CheckStale() end)
  elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
    -- Fires for every search, including manual and empty-box ones in the
    -- Blizzard UI; only collect results from searches we triggered, or the
    -- apply queue fills with unfiltered groups. Can fire twice per search.
    if not ns.pendingSearch or ns.lastResultsAt == GetTime() then return end
    ns.lastResultsAt = GetTime()
    ns.pendingSearch = false
    ns.Search:CollectAndScore()
    ns.state = "SEARCHED"
    ns.Widget:Refresh()
  elseif event == "LFG_LIST_SEARCH_FAILED" then
    ns.Debug:Log("search", "failed: " .. tostring(...))
    ns.pendingSearch = false
    ns.state = "IDLE"
    ns.Widget:Flash("Throttled")
  elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
    local id, newStatus = ...
    Core:OnApplicationUpdate(id, newStatus)
    ns.Widget:Refresh()
  elseif event == "GROUP_JOINED" then
    ns.state = "IDLE"
    wipe(ns.results)
    ns.Widget:Refresh()
  end
end)
