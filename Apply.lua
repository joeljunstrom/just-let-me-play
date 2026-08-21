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
local LINGERING = {
  declined = true,
  declined_full = true,
  declined_delisted = true,
  timedout = true,
  failed = true,
  invitedeclined = true,
}

function Apply:CancelDeadApplications()
  if not ns.db.autoCancel then return end
  for _, id in ipairs(C_LFGList.GetApplications()) do
    local _, appStatus = C_LFGList.GetApplicationInfo(id)
    ns.Debug:Log("apps", ("id=%s status=%s"):format(tostring(id), tostring(appStatus)))
    local dead = false
    if LINGERING[appStatus] then
      dead = true
    elseif appStatus == "applied" then
      local info = C_LFGList.GetSearchResultInfo(id)
      dead = (info and info.isDelisted) or not ns.Search:RoleHasSpace(id)
    end
    if dead then
      ns.sessionDeclined[id] = true
      local ok = pcall(C_LFGList.CancelApplication, id)
      ns.Debug:Log("cancel", ("id=%s status=%s ok=%s"):format(tostring(id), tostring(appStatus), tostring(ok)))
    end
  end
end

-- Hardware-event context only: C_LFGList.ApplyToGroup is protected.
function Apply:ApplyTop()
  local free = ns.Core:FreeSlots()
  local tank, healer, dps = roleFlags()

  local remaining = {}
  for _, id in ipairs(ns.results) do
    if self:StillEligible(id) then
      if free > 0 then
        local ok, err = pcall(C_LFGList.ApplyToGroup, id, tank, healer, dps)
        ns.Debug:Log("apply", ("id=%s ok=%s%s"):format(tostring(id), tostring(ok), err and (" err=" .. tostring(err)) or ""))
        if ok then
          ns.pendingApplies[id] = GetTime()
        end
        free = free - 1
      else
        remaining[#remaining + 1] = id
      end
    end
  end

  ns.results = remaining
  if #ns.results == 0 then
    ns.state = "IDLE"
  end
end
