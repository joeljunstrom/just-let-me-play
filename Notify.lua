local _, ns = ...

local Notify = {}
ns.Notify = Notify

function Notify:SlotFreed()
  if ns.db.sounds then
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master")
  end
  ns.Widget:Refresh()
  ns.Widget:Pulse()
end

function Notify:Stale()
  ns.Widget:Pulse()
end
