local _, ns = ...

local Apply = {}
ns.Apply = Apply

local function roleFlags()
  if ns.db.roleOverride == "ANY" then
    local a, b, c = C_LFGList.GetRoles()
    if type(a) == "table" then
      return a.tank, a.healer, a.dps
    end
    return a, b, c
  end
  local role = ns.Search:MyRole()
  return role == "TANK", role == "HEALER", role == "DAMAGER"
end

function Apply:StillEligible(id)
  local info = C_LFGList.GetSearchResultInfo(id)
  if not info or info.isDelisted then return false end
  if ns.sessionDeclined[id] then return false end
  if ns.pendingApplies[id] then return false end
  if not ns.Search:RoleHasSpace(id) then return false end
  local _, appStatus = C_LFGList.GetApplicationInfo(id)
  return not appStatus or appStatus == "none"
end

-- Cancel applications that can no longer work out: the group delisted or my
-- role filled up while the leader lets the application hang. CancelApplication
-- is hardware-event protected, so this runs inside the widget click.
-- The server honors only ONE protected LFGList action (apply, cancel, search)
-- per hardware event; extra calls return fine but silently do nothing. So each
-- click performs exactly one action. Cancelling declined/timed-out entries
-- also does nothing (they expire on their own), so only live applications
-- whose group delisted or filled my role are worth a cancel.
function Apply:CancelOneDead()
  if not ns.db.autoCancel then return false end
  for _, id in ipairs(C_LFGList.GetApplications()) do
    local _, appStatus = C_LFGList.GetApplicationInfo(id)
    ns.Debug:Log("apps", ("id=%s status=%s"):format(tostring(id), tostring(appStatus)))
    if appStatus == "applied" then
      local info = C_LFGList.GetSearchResultInfo(id)
      if (info and info.isDelisted) or not ns.Search:RoleHasSpace(id) then
        ns.sessionDeclined[id] = true
        local ok = pcall(C_LFGList.CancelApplication, id)
        ns.Debug:Log("cancel", ("id=%s ok=%s"):format(tostring(id), tostring(ok)))
        return true
      end
    end
  end
  return false
end

function Apply:ApplyNext()
  local tank, healer, dps = roleFlags()
  while #ns.results > 0 do
    local id = table.remove(ns.results, 1)
    if self:StillEligible(id) then
      local ok, err = pcall(C_LFGList.ApplyToGroup, id, tank, healer, dps)
      ns.Debug:Log("apply", ("id=%s ok=%s%s"):format(tostring(id), tostring(ok), err and (" err=" .. tostring(err)) or ""))
      if ok then
        ns.pendingApplies[id] = GetTime()
      end
      break
    end
  end
  if #ns.results == 0 then
    ns.state = "IDLE"
  end
end
