local _, ns = ...

local Debug = {}
ns.Debug = Debug

local MAX_ENTRIES = 300

function Debug:Log(tag, message)
  if not (ns.db and ns.db.debugEnabled) then return end
  ns.db.debugLog = ns.db.debugLog or {}
  local log = ns.db.debugLog
  log[#log + 1] = date("%H:%M:%S") .. " [" .. tag .. "] " .. message
  if #log > MAX_ENTRIES then
    table.remove(log, 1)
  end
end

function Debug:StartSession()
  if not ns.db.debugEnabled then
    ns.db.debugLog = nil
    return
  end
  self:Log("debug", "--- session start " .. date("%Y-%m-%d") .. " ---")
end
