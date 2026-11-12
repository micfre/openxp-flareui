-- Fake FlareUI Quest Tracker for the OXP-FUI dock seam tests.
--
-- Mirrors the holder of FlareUI's ObjectiveTracker.lua: the global frame
-- FlareUI_ObjectiveTracker is only created when FlareUI is installed and
-- its tracker module is enabled; its Render keeps the holder's width and
-- height in step with the quest list and hides it (SetShown) when nothing
-- is tracked or when minimized with the "button" style. Show/Hide here
-- fire the OnShow/OnHide scripts like the real client, so a docked
-- addon's hooks run; SetShown mirrors the real API the harness lacks.

HARNESS.flareui = {}

-- FlareUI's addon metadata (Core.lua reads its switch from the profile;
-- GetAddOnMetadata reporting it is how OXP-FUI knows FlareUI is installed).
HARNESS.addonMetadata["FlareUI"] = { Title = "FlareUI", Version = "1.0" }

function HARNESS.CreateFlareUITracker()
  if _G.FlareUI_ObjectiveTracker then return _G.FlareUI_ObjectiveTracker end
  local holder = CreateFrame("Frame", "FlareUI_ObjectiveTracker", UIParent,
    "BackdropTemplate")
  -- ObjectiveTracker.lua C: WIDTH 250, HEADER 30; Render sets the real
  -- height from the list (header + list top + list + list bottom).
  holder:SetWidth(250)
  holder:SetHeight(166)
  holder:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -300)
  -- Real client semantics the harness base lacks.
  local origShow, origHide = holder.Show, holder.Hide
  holder.Show = function(self)
    if self:IsShown() then return end
    origShow(self)
    local fn = self:GetScript("OnShow")
    if fn then fn(self) end
  end
  holder.Hide = function(self)
    if not self:IsShown() then return end
    origHide(self)
    local fn = self:GetScript("OnHide")
    if fn then fn(self) end
  end
  holder.SetShown = function(self, v)
    if v then self:Show() else self:Hide() end
  end
  -- Test drivers mirroring what FlareUI's Render/OT:SetMinimized do.
  holder.MinimizeToList = function(self)  -- header-only, still visible
    self:SetHeight(33)                    -- C.HEADER + 3
  end
  holder.MinimizeToButton = function(self) -- lone "+", holder hidden
    self:Hide()
  end
  holder.Resize = function(self, w)       -- the Width edit-mode setting
    self:SetWidth(w)
  end
  HARNESS.flareui.holder = holder
  return holder
end

if HARNESS.flareuiDeferred ~= true then
  HARNESS.CreateFlareUITracker()
end
