local _, ns = ...

local Notify = {}
ns.Notify = Notify

-- Ordered for menus. Whisper default: familiar, audible, not raid-alarm loud.
Notify.SOUNDS = {
  { key = "whisper", label = "Whisper", kit = SOUNDKIT.TELL_MESSAGE },
  { key = "ping", label = "Map ping", kit = SOUNDKIT.MAP_PING },
  { key = "auction", label = "Auction house", kit = SOUNDKIT.AUCTION_WINDOW_OPEN },
  { key = "alarm", label = "Alarm clock", kit = SOUNDKIT.ALARM_CLOCK_WARNING_3 },
  { key = "readycheck", label = "Ready check", kit = SOUNDKIT.READY_CHECK },
  { key = "raidwarning", label = "Raid warning", kit = SOUNDKIT.RAID_WARNING },
}

function Notify:Play()
  local chosen
  for _, sound in ipairs(self.SOUNDS) do
    if sound.key == ns.db.sound then
      chosen = sound.kit
      break
    end
  end
  PlaySound(chosen or SOUNDKIT.TELL_MESSAGE, "Master")
end

function Notify:SlotFreed()
  if ns.db.sounds then
    self:Play()
  end
  ns.Widget:Refresh()
  ns.Widget:Pulse()
end

function Notify:Stale()
  ns.Widget:Pulse()
end
