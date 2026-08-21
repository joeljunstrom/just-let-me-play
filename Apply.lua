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
  local _, appStatus = C_LFGList.GetApplicationInfo(id)
  return not appStatus or appStatus == "none"
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
