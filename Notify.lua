local _, ns = ...

local Notify = {}
ns.Notify = Notify

function Notify:SlotFreed()
  if ns.db.sounds then
    PlaySound(SOUNDKIT.READY_CHECK, "Master")
  end
  ns.Widget:Refresh()
  ns.Widget:Pulse()
end

function Notify:Stale()
  ns.Widget:Pulse()
end
