-- WoW API stub for the OXP-FUI skin seam (Seam 1).
--
-- Emulates the slice of the WoW (Forever, interface 16001) API that OXP-FUI
-- and the fake OpenXP use, outside the game. State lives in plain Lua tables
-- that Python tests reach through env.eval()/env.frame() helpers.
--
-- Conventions:
--   * Every mutating method call on a frame/texture/fontstring is appended to
--     the object's __calls list as { "Method", arg1, arg2, ... } so tests can
--     assert "this frame was never touched" or "no layout call happened".
--   * Getters mirror the real WoW API (GetBackdrop, GetTextColor, GetFont...).
--   * Unknown methods raise a loud error on purpose: extending the stub must
--     be a deliberate act, and silent no-ops would let tests pass vacuously.

HARNESS = {}
HARNESS.chat = {}          -- captured print() output
HARNESS.events = {}        -- event -> { [frame]=true }
HARNESS.inCombat = false
HARNESS.time = 1000.0
HARNESS.libs = {}          -- LibStub registry
HARNESS.addonMetadata = {  -- GetAddOnMetadata data
  ["OpenXP"] = { Title = "OpenXP", Version = "1.3.48" },
}
HARNESS.timers = { after = 0, tickers = 0 }
HARNESS.reloads = 0

local function record(obj, method, ...)
  local n = select("#", ...)
  local entry = { method }
  for i = 1, n do entry[i + 1] = select(i, ...) end
  obj.__calls[#obj.__calls + 1] = entry
end

local function copyShallow(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

-- ---------------------------------------------------------------------------
-- Frame / Texture / FontString objects
-- ---------------------------------------------------------------------------

-- Unknown keys read as nil (plain table): a typo'd method call fails loudly
-- with "attempt to call a nil value", while unset custom fields read as nil
-- exactly like real WoW frame tables.

-- Methods shared by frames, textures and font strings.
local function baseMethods(kind)
  return {
    __kind = kind,
    __calls = {},
    __children = {},

    GetName = function(self) return self.__name end,
    GetObjectType = function(self) return self.__type end,
    IsObjectType = function(self, t) return self.__type == t end,
    GetParent = function(self) return self.__parent end,
    IsProtected = function(self) return self.__protected == true end,

    Show = function(self) record(self, "Show"); self.__shown = true end,
    Hide = function(self) record(self, "Hide"); self.__shown = false end,
    IsShown = function(self) return self.__shown ~= false end,
    IsVisible = function(self) return self.__shown ~= false end,

    SetSize = function(self, w, h) record(self, "SetSize", w, h); self.__width, self.__height = w, h end,
    SetWidth = function(self, w) record(self, "SetWidth", w); self.__width = w end,
    SetHeight = function(self, h) record(self, "SetHeight", h); self.__height = h end,
    GetSize = function(self) return self.__width, self.__height end,
    GetWidth = function(self) return self.__width end,
    GetHeight = function(self) return self.__height end,

    SetPoint = function(self, ...) record(self, "SetPoint", ...); self.__points[#self.__points + 1] = { ... } end,
    SetAllPoints = function(self, rel) record(self, "SetAllPoints", rel); self.__points[#self.__points + 1] = { "*all*", rel } end,
    ClearAllPoints = function(self) record(self, "ClearAllPoints"); self.__points = {} end,
    GetNumPoints = function(self) return #self.__points end,
    GetPoint = function(self, i) local p = self.__points[i or 1]; return p[1], p[2], p[3], p[4], p[5] end,

    SetScale = function(self, s) record(self, "SetScale", s); self.__scale = s end,
    GetScale = function(self) return self.__scale or 1 end,
    GetEffectiveScale = function(self) return self.__scale or 1 end,
    SetAlpha = function(self, a) record(self, "SetAlpha", a); self.__alpha = a end,
    GetAlpha = function(self) return self.__alpha or 1 end,
    SetFrameStrata = function(self, s) record(self, "SetFrameStrata", s); self.__strata = s end,
    GetFrameStrata = function(self) return self.__strata end,
    SetFrameLevel = function(self, l) record(self, "SetFrameLevel", l); self.__level = l end,
    GetFrameLevel = function(self) return self.__level or 0 end,
    SetID = function(self, id) record(self, "SetID", id); self.__id = id end,
    GetID = function(self) return self.__id end,
    SetToplevel = function(self, v) record(self, "SetToplevel", v) end,
    SetDontSavePosition = function(self, v) record(self, "SetDontSavePosition", v) end,
    SetClampedToScreen = function(self, v) record(self, "SetClampedToScreen", v) end,
    SetMovable = function(self, v) record(self, "SetMovable", v) end,
    SetResizable = function(self, v) record(self, "SetResizable", v) end,
    SetUserPlaced = function(self, v) record(self, "SetUserPlaced", v) end,
    EnableMouse = function(self, v) record(self, "EnableMouse", v); self.__mouse = v end,
    EnableMouseWheel = function(self, v) record(self, "EnableMouseWheel", v) end,
    EnableKeyboard = function(self, v) record(self, "EnableKeyboard", v) end,
    SetHitRectInsets = function(self, ...) record(self, "SetHitRectInsets", ...) end,
    SetMaxResize = function(self, ...) record(self, "SetMaxResize", ...) end,
    SetMinResize = function(self, ...) record(self, "SetMinResize", ...) end,
    StartMoving = function(self) record(self, "StartMoving") end,
    StartSizing = function(self) record(self, "StartSizing") end,
    StopMovingOrSizing = function(self) record(self, "StopMovingOrSizing") end,
    Raise = function(self) record(self, "Raise") end,
    Lower = function(self) record(self, "Lower") end,

    SetBackdrop = function(self, bd)
      record(self, "SetBackdrop", bd)
      self.backdrop = bd and copyShallow(bd) or nil
      if bd and bd.insets then self.backdrop.insets = copyShallow(bd.insets) end
    end,
    GetBackdrop = function(self) return self.backdrop end,
    SetBackdropColor = function(self, r, g, b, a)
      record(self, "SetBackdropColor", r, g, b, a)
      self.__backdropColor = { r, g, b, a }
    end,
    GetBackdropColor = function(self)
      local c = self.__backdropColor or { 1, 1, 1, 1 }
      return c[1], c[2], c[3], c[4]
    end,
    SetBackdropBorderColor = function(self, r, g, b, a)
      record(self, "SetBackdropBorderColor", r, g, b, a)
      self.__backdropBorderColor = { r, g, b, a }
    end,
    GetBackdropBorderColor = function(self)
      local c = self.__backdropBorderColor or { 1, 1, 1, 1 }
      return c[1], c[2], c[3], c[4]
    end,

    SetScript = function(self, handler, fn)
      record(self, "SetScript", handler)
      self.__scripts = self.__scripts or {}
      self.__scripts[handler] = fn
    end,
    GetScript = function(self, handler)
      return self.__scripts and self.__scripts[handler] or nil
    end,
    HookScript = function(self, handler, fn)
      record(self, "HookScript", handler)
      self.__scripts = self.__scripts or {}
      local orig = self.__scripts[handler]
      self.__scripts[handler] = function(...)
        if orig then orig(...) end
        fn(...)
      end
    end,
    RegisterEvent = function(self, evt)
      record(self, "RegisterEvent", evt)
      HARNESS.events[evt] = HARNESS.events[evt] or {}
      HARNESS.events[evt][self] = true
    end,
    UnregisterEvent = function(self, evt)
      record(self, "UnregisterEvent", evt)
      if HARNESS.events[evt] then HARNESS.events[evt][self] = nil end
    end,
    RegisterForClicks = function(self, ...) record(self, "RegisterForClicks", ...) end,
    SetAttribute = function(self, k, v)
      record(self, "SetAttribute", k, v)
      self.__attributes = self.__attributes or {}
      self.__attributes[k] = v
    end,
    GetAttribute = function(self, k) return self.__attributes and self.__attributes[k] or nil end,
  }
end

local function newObject(kind, objectType, name, parent)
  if name ~= nil and name ~= false and rawget(_G, name) ~= nil then
    error("harness: global name already in use: " .. tostring(name))
  end
  local o = baseMethods(kind)
  o.__type = objectType
  o.__name = name
  o.__parent = parent
  o.__points = {}
  o.__shown = true
  o.__scripts = {}
  if name ~= nil and name ~= false then
    _G[name] = o
  end
  if parent then parent.__children[#parent.__children + 1] = o end
  return o
end

-- Frame-only methods (child creation, clicks, sliders, ...).
local function newFrame(frameType, name, parent, template)
  local f = newObject("Frame", frameType, name, parent)
  if template then f.template = template end

  if frameType == "Frame" or frameType == "Button" or frameType == "Slider" or frameType == "CheckButton" or frameType == "EditBox" then
    f.CreateTexture = function(self, name2, layer, _, template2)
      local tex = newObject("Texture", "Texture", name2, self)
      tex.__layer = layer
      if template2 then tex.template = template2 end
      return tex
    end
    f.CreateFontString = function(self, name2, layer, _, template2)
      local fs = newObject("FontString", "FontString", name2, self)
      fs.__layer = layer
      if template2 then fs.template = template2 end
      return fs
    end
  end

  if frameType == "Button" or frameType == "CheckButton" then
    -- Simulated click: runs the OnClick script like the real client.
    f.Click = function(self, buttonArg, downArg)
      record(self, "Click", buttonArg, downArg)
      local fn = self.__scripts["OnClick"]
      if fn then fn(self, buttonArg or "LeftButton", downArg) end
    end
    f.SetNormalTexture = function(self, texOrPath)
      record(self, "SetNormalTexture", texOrPath)
      self.__normalTexture = texOrPath
    end
    f.GetNormalTexture = function(self) return self.__normalTexture end
    f.SetPushedTexture = function(self, p) record(self, "SetPushedTexture", p); self.__pushedTexture = p end
    f.SetHighlightTexture = function(self, p) record(self, "SetHighlightTexture", p); self.__highlightTexture = p end
    f.SetDisabledTexture = function(self, p) record(self, "SetDisabledTexture", p) end
    f.Disable = function(self) record(self, "Disable") end
    f.Enable = function(self) record(self, "Enable") end
  end

  if frameType == "Slider" then
    f.SetMinMaxValues = function(self, lo, hi)
      record(self, "SetMinMaxValues", lo, hi)
      self.__min, self.__max = lo, hi
    end
    f.GetMinMaxValues = function(self) return self.__min or 0, self.__max or 1 end
    f.SetValueStep = function(self, step) record(self, "SetValueStep", step); self.__step = step end
    f.SetOrientation = function(self, o) record(self, "SetOrientation", o) end
    f.SetThumbTexture = function(self, t) record(self, "SetThumbTexture", t); self.__thumb = t end
    f.SetValue = function(self, v)
      record(self, "SetValue", v)
      local lo = self.__min or 0
      local hi = self.__max or 1
      if v < lo then v = lo end
      if v > hi then v = hi end
      self.__value = v
      local fn = self.__scripts and self.__scripts["OnValueChanged"]
      if fn then fn(self, v) end
    end
    f.GetValue = function(self) return self.__value or 0 end
  end

  return f
end

function CreateFrame(frameType, name, parent, template, id)
  local resolvedName = name
  if resolvedName and resolvedName:find("$parent", 1, true) then
    local pname = parent and parent.GetName and parent:GetName() or nil
    if not pname then error("harness: $parent name without a named parent") end
    resolvedName = resolvedName:gsub("%$parent", pname)
  end
  return newFrame(frameType, resolvedName, parent, template)
end

local texExtra = {
  SetTexture = function(self, tex, ...)
    record(self, "SetTexture", tex, ...)
    self.__texture = tex
    if select("#", ...) > 0 then self.__vertexColor = { tex, ... } end
  end,
  GetTexture = function(self) return self.__texture end,
  SetColorTexture = function(self, r, g, b, a)
    record(self, "SetColorTexture", r, g, b, a)
    self.__texture = nil
    self.__colorTexture = { r, g, b, a or 1 }
  end,
  SetVertexColor = function(self, r, g, b, a)
    record(self, "SetVertexColor", r, g, b, a)
    self.__vertexColor = { r, g, b, a }
  end,
  SetGradient = function(self, orientation, top, bottom)
    record(self, "SetGradient", orientation, top, bottom)
    self.__gradient = { orientation, top, bottom }
  end,
  SetTexCoord = function(self, ...) record(self, "SetTexCoord", ...) end,
  SetDrawLayer = function(self, layer, sublevel) record(self, "SetDrawLayer", layer, sublevel); self.__layer = layer end,
  GetDrawLayer = function(self) return self.__layer end,
  SetSnapToPixelGrid = function(self, v) record(self, "SetSnapToPixelGrid", v) end,
  SetTexelSnappingBias = function(self, v) record(self, "SetTexelSnappingBias", v) end,
}
local fsExtra = {
  SetText = function(self, text) record(self, "SetText", text); self.__text = text end,
  GetText = function(self) return self.__text end,
  SetTextColor = function(self, r, g, b, a)
    record(self, "SetTextColor", r, g, b, a)
    self.__textColor = { r, g, b, a }
  end,
  GetTextColor = function(self)
    local c = self.__textColor or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4]
  end,
  SetFont = function(self, path, size, flags)
    record(self, "SetFont", path, size, flags)
    self.__font = { path, size, flags or "" }
    return true
  end,
  GetFont = function(self)
    local f = self.__font
    if not f then return nil end
    return f[1], f[2], f[3]
  end,
  SetFontObject = function(self, obj) record(self, "SetFontObject", obj) end,
  SetShadowColor = function(self, r, g, b, a)
    record(self, "SetShadowColor", r, g, b, a)
    self.__shadowColor = { r, g, b, a }
  end,
  GetShadowColor = function(self)
    local c = self.__shadowColor or { 0, 0, 0, 0 }
    return c[1], c[2], c[3], c[4]
  end,
  SetShadowOffset = function(self, x, y)
    record(self, "SetShadowOffset", x, y)
    self.__shadowOffset = { x, y }
  end,
  GetShadowOffset = function(self)
    local o = self.__shadowOffset or { 0, 0 }
    return o[1], o[2]
  end,
  SetJustifyH = function(self, j) record(self, "SetJustifyH", j); self.__justifyH = j end,
  GetJustifyH = function(self) return self.__justifyH end,
  SetJustifyV = function(self, j) record(self, "SetJustifyV", j) end,
  SetWordWrap = function(self, v) record(self, "SetWordWrap", v) end,
  SetMaxLines = function(self, n) record(self, "SetMaxLines", n) end,
  SetTextShadowOffset = function(self, x, y)
    record(self, "SetTextShadowOffset", x, y)
    self.__shadowOffset = { x, y }
  end,
}
-- Mix texture/fontstring methods into every object created by newObject.
local origNewObject = newObject
newObject = function(kind, objectType, name, parent)
  local o = origNewObject(kind, objectType, name, parent)
  local extra = kind == "Texture" and texExtra or kind == "FontString" and fsExtra or nil
  if extra then
    for k, v in pairs(extra) do rawset(o, k, v) end
  end
  return o
end

-- ---------------------------------------------------------------------------
-- Events, chat, timers, slash commands, misc globals
-- ---------------------------------------------------------------------------

function HARNESS.FireEvent(evt, ...)
  local frames = HARNESS.events[evt]
  if not frames then return end
  for f in pairs(frames) do
    local fn = f:GetScript("OnEvent")
    if fn then fn(f, evt, ...) end
  end
end

function print(...)
  local n = select("#", ...)
  local parts = {}
  for i = 1, n do parts[#parts + 1] = tostring(select(i, ...)) end
  HARNESS.chat[#HARNESS.chat + 1] = table.concat(parts, " ")
end

function HARNESS.RunSlash(input)
  local cmd = input:match("^/([^%s]+)")
  if not cmd then return end
  local rest = input:match("^/%S+%s*(.*)$") or ""
  cmd = cmd:lower()
  for k, v in pairs(_G) do
    if type(k) == "string" and k:find("^SLASH_") and type(v) == "string" then
      if v:lower() == "/" .. cmd then
        local key = k:match("^SLASH_(.+)%d+$")
        local fn = key and _G.SlashCmdList and SlashCmdList[key]
        if fn then fn(rest) end
        return
      end
    end
  end
  error("harness: no slash handler for " .. input)
end

C_Timer = {}
function C_Timer.After(_, fn) HARNESS.timers.after = HARNESS.timers.after + 1; fn() end
function C_Timer.NewTicker(_, fn)
  HARNESS.timers.tickers = HARNESS.timers.tickers + 1
  fn()
  return { Cancel = function() end }
end

function InCombatLockdown() return HARNESS.inCombat end
function UnitAffectingCombat() return HARNESS.inCombat end

function GetAddOnMetadata(addonName, field)
  local meta = HARNESS.addonMetadata[addonName]
  return meta and meta[field] or nil
end
C_AddOns = { GetAddOnMetadata = GetAddOnMetadata }

function LibStub(major, silent)
  local lib = HARNESS.libs[major]
  if not lib and not silent then error("LibStub: library not found: " .. major) end
  return lib
end

local function hooksecurefuncImpl(tbl, key, hookFn)
  local orig = tbl[key]
  if type(orig) ~= "function" then
    error("harness: hooksecurefunc target not a function: " .. tostring(key))
  end
  tbl[key] = function(...)
    local results = table.pack(orig(...))
    hookFn(...)
    return table.unpack(results, 1, results.n)
  end
end

function hooksecurefunc(a, b, c)
  if type(a) == "table" then
    hooksecurefuncImpl(a, b, c)
  else
    -- hooksecurefunc("GlobalName", fn)
    hooksecurefuncImpl(_G, a, b)
  end
end

function GetLocale() return "enUS" end
function GetBuildInfo() return "1.17.0", "16001", "Nov 11 2026", 16001 end
function GetTime() return HARNESS.time end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function ReloadUI() HARNESS.reloads = HARNESS.reloads + 1 end

function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function tinsert(t, v) t[#t + 1] = v end
function tremove(t, i) return table.remove(t, i) end
if unpack == nil then unpack = table.unpack end

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
BackdropTemplateMixin = {}
PixelUtil = { GetPixelToUIUnitFactor = function() return 1 end }
UISpecialFrames = {}

SlashCmdList = {}

-- Base world frames and Blizzard frames the fakes anchor to.
UIParent = CreateFrame("Frame", "UIParent", nil)
WorldFrame = CreateFrame("Frame", "WorldFrame", nil)
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
Minimap = CreateFrame("Frame", "Minimap", UIParent)
GameTooltip = CreateFrame("Frame", "GameTooltip", UIParent)
ItemRefTooltip = CreateFrame("Frame", "ItemRefTooltip", UIParent)

-- File loader used by the Python side to load addon files with WoW varargs.
function HARNESS.LoadFile(path, arg1, arg2)
  local chunk = assert(loadfile(path))
  return chunk(arg1, arg2)
end
