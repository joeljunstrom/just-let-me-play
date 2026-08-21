local _, ns = ...

local Debug = {}
ns.Debug = Debug

local MAX_ENTRIES = 300

function Debug:Log(tag, message)
  local log = ns.db and ns.db.debugLog
  if not log then return end
  log[#log + 1] = date("%H:%M:%S") .. " [" .. tag .. "] " .. message
  if #log > MAX_ENTRIES then
    table.remove(log, 1)
  end
end

function Debug:StartSession()
  ns.db.debugLog = ns.db.debugLog or {}
  self:Log("debug", "--- session start " .. date("%Y-%m-%d") .. " ---")
end
