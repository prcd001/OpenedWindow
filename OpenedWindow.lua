-- OpenedWindow v1.1.3 (2026-10-16)
-- v1.1.3: tyre branch fixed - the channel key is tyres (British spelling), tires never matched.
-- OpenedWindow v1.1.2 (2026-10-16)
-- v1.1.2: tyres are 1.75x quieter in INTERIOR mode and ramp back to their default
-- volume as the window opens.
-- OpenedWindow v1.1.1 (2026-10-16)
-- v1.1.1: animation runs at its own SMOOTH linear tempo (no audio kick curve);
-- animation nodes re-found every frame (fixes animation dying on exterior cameras);
-- cockpitOnly/camera changes snap the mix instantly (a setting, not the toggle);
-- animation + exterior-mix checkboxes moved to Extra tab; Reset also resets the
-- sounds toggle; window widened so slider labels fit.
-- OpenedWindow v1.1.0 (2026-10-16)
-- v1.1.0: window ANIMATION integration: when the car ships window open/close ksanim
-- files, the same toggle that plays the motor sound also drives the car's own window
-- animation, using openBlend as progress so windows roll in exact sync with the audio.
-- Also fixed latent dot-syntax file bugs (f.write/f.close -> f:write/f:close).
-- OpenedWindow v1.0.2 (2026-10-14)
-- v1.0.2: exterior motor volume 0.5 -> 0.25 (user request); long texts now wrap so they
-- cannot overflow a narrowed app window.
-- Renamed from WindowAudioSwitch in v1.0.1: install as apps/lua/OpenedWindow/OpenedWindow.lua.
-- UI restructured: tabs Volume | Sounds | Key mapping | Extra (wind settings, experimental).
-- Verified in-game through 7 test rounds (Round 7: all tests PASS).
-- Known limitations: replay toggle-recording impossible from apps (ac.StructItem
-- not implemented for apps/lua in CSP v0.2.11); wipers/carComponents/transmission
-- refuse setAudioVolume; opponents boost capped at 1.0; mode always starts INTERIOR.
-- OpenedWindow: one button toggles the audio mix between:
--   mode 0 "Interior"     -> the normal cockpit mix (only the interior volume slider applied)
--   mode 1 "Open window"  -> same mix, but sounds coming from OUTSIDE the car are louder
--
-- The switch is NOT instant: pressing the button ramps the mix over
-- `transitionTime` seconds (default 3.5 s, matching the bundled motor sound) in
-- two phases, like a real window motor: opening, 75% of the change happens in
-- the first 150 ms (the initial kick), the remaining 25% creeps in while the
-- window keeps rolling. Closing is the time-reversed shape: it creeps through
-- 25% first and the remaining 75% lands in the LAST 150 ms.
--
-- Panning experiments (Pan DSP balance, CarAudioTweak.setTransform position
-- shift) were tested over several rounds and REMOVED: results were unreliable
-- and confusing in practice. Findings are documented in
-- workflow/WindowAudioSwitch/RESULTS_ROUND5.md. The global channels (track,
-- weather, rain, wipers, carComponents) only expose volume in the API and are
-- left untouched.
--
-- Audio mechanism (verified in CSP SDK v0.2.11, ac_apps/lib.lua):
--   ac.getAudioVolume(audioChannelKey, carIndex?, fallbackValue?) -> number (0..1)
--   ac.setAudioVolume(audioChannelKey, value, carIndex?)          -> boolean
--     * value is CLAMPED to 0..1: boosting above 1 is silently inaudible
--     * without carIndex: sets the global volume of that channel
--   Car channels (dirt/engine/surfaces/tyres/wind/transmission) are boosted via
--   ac.CarAudioTweak.setVolume(eventID, multiplier) instead — multipliers there
--   CAN exceed 1.0 (verified working in Round 5). 'opponents' has no per-event
--   API and stays on the capped ac.setAudioVolume (attenuation only).
-- CSP exposes exactly these channels (ac.AudioChannel):
--   main, rain, weather, track, wipers, carComponents, wind, tyres, surfaces,
--   dirt, engine, transmission, opponents
-- There is no separate "interior vs exterior" recording per channel, so "outside"
-- is approximated by the channel list below. Everything we touch is restored on unload.

-- CSP's native per-script settings: settings.ini in the script's own folder,
-- persisted by CSP across restarts (the officially supported mechanism).
local settings = ac.INIConfig.scriptSettings() or ac.INIConfig(ac.INIFormat.Default)
local settingsPath = settings.filename or ac.getFolder(ac.FolderID.ScriptConfig) .. '/settings.ini'
local logPath = (settingsPath:match('^(.*)[/\\]') or settingsPath) .. '/OpenedWindow.log'

local DEFAULTS = {
  mode = 0,            -- 0 = interior, 1 = open window
  interiorVolume = 1.0,
  outsideGain = 2.0,   -- multiplier for outside sounds in open window mode
  cockpitOnly = true,  -- effect applies only while the camera is inside the car
  showDebug = false,
  exteriorMix = true, -- CSP built-in exterior audio blend in open mode (ON by default)
  transitionTime = 3.5, -- FIXED at 3.5 s: matches the ~1.5-2 s motor sound + tail; slider removed after testing
  soundsEnabled = true,
  motorVolume = 0.8,
  windVolume = 0.7,
  windMinSpeed = 40,   -- km/h at which wind starts to fade in
  windMaxSpeed = 120,  -- km/h at which wind reaches full volume
  animEnabled = true,  -- drive the car's own window ksanim with the toggle (v1.1.0)
}

local state = {
  mode = DEFAULTS.mode,  -- never saved: every session starts with the window closed
  interiorVolume = settings:get('volume', 'interior', DEFAULTS.interiorVolume),
  outsideGain = settings:get('volume', 'outsideGain', DEFAULTS.outsideGain),
  cockpitOnly = settings:get('general', 'cockpitOnly', DEFAULTS.cockpitOnly),
  showDebug = settings:get('general', 'showDebug', DEFAULTS.showDebug),
  exteriorMix = settings:get('general', 'exteriorMix', DEFAULTS.exteriorMix),
  transitionTime = DEFAULTS.transitionTime,  -- fixed: slider removed after testing
  soundsEnabled = settings:get('sounds', 'enabled', DEFAULTS.soundsEnabled),
  motorVolume = settings:get('sounds', 'motorVolume', DEFAULTS.motorVolume),
  windVolume = settings:get('sounds', 'windVolume', DEFAULTS.windVolume),
  windMinSpeed = settings:get('sounds', 'windMinSpeed', DEFAULTS.windMinSpeed),
  windMaxSpeed = settings:get('sounds', 'windMaxSpeed', DEFAULTS.windMaxSpeed),
  animEnabled = settings:get('general', 'animEnabled', DEFAULTS.animEnabled),
}

local dirty = false

local function saveState()
  -- mode is deliberately NOT saved: the window always starts closed
  settings:set('volume', 'interior', state.interiorVolume)
  settings:set('volume', 'outsideGain', state.outsideGain)
  settings:set('general', 'cockpitOnly', state.cockpitOnly)
  settings:set('general', 'showDebug', state.showDebug)
  settings:set('general', 'exteriorMix', state.exteriorMix)
  settings:set('sounds', 'enabled', state.soundsEnabled)
  settings:set('sounds', 'motorVolume', state.motorVolume)
  settings:set('sounds', 'windVolume', state.windVolume)
  settings:set('sounds', 'windMinSpeed', state.windMinSpeed)
  settings:set('sounds', 'windMaxSpeed', state.windMaxSpeed)
  settings:set('general', 'animEnabled', state.animEnabled)
  settings:save(settingsPath)
  dirty = false
end

-- Channel groups. Car channels are adjusted with a per-car multiplier for the
-- player's car (index 0); global channels are set as absolute values.
local OUTSIDE_CAR = { 'tyres', 'surfaces', 'dirt', 'wind', 'opponents' }
local OUTSIDE_GLOBAL = { 'track', 'weather', 'rain' }
local INSIDE_CAR = { 'engine', 'transmission' }
local INSIDE_GLOBAL = { 'wipers', 'carComponents' }
local ALL_CAR = { 'tyres', 'surfaces', 'dirt', 'wind', 'opponents', 'engine', 'transmission' }
local ALL_GLOBAL = { 'track', 'weather', 'rain', 'wipers', 'carComponents' }

-- Channel -> ac.CarAudioEventID groups for CarAudioTweak.setVolume (per-event
-- multiplier that CAN exceed 1.0; ac.setAudioVolume is capped at 0..1).
-- Enum verified against CSP SDK v0.2.11 ac.CarAudioEventID.
local CAR_EVENT_GROUPS = {
  engine = { 0, 1 },                    -- EngineExt, EngineInt
  transmission = { 2, 3, 7, 9, 14 },   -- GearExt, GearInt, Downshift, GearGrind, Transmission
  wind = { 5 },                         -- Wind
  dirt = { 6 },                         -- Dirt
  surfaces = { 4 },                     -- Bodywork
  tyres = { 20, 21, 22, 23, 30, 31, 32, 33, 40, 41, 42, 43 },  -- wheels + skid int/ext
  -- 'opponents' intentionally absent: other cars' audio has no per-event API
}
local tweakBaseline = nil
local tweakBaselineCar = nil
local unSettableGlobal = {}  -- CSP refuses setAudioVolume on some globals (rain)
local unSettableCar = {}     -- same for car channels (e.g. 'transmission' on some cars)
local appliedFactor = {}     -- last factor actually applied per channel (for debug:
                             -- getAudioVolume only returns 0..1, never our multiplier)
local motorVolDebug = nil
local motorDebug = nil

-- Baseline: the game's own channel volumes at the moment the app loaded.
-- Everything is computed relative to this, so the mix always returns to normal.
local baseline = {}
local lastError = nil
local lastSignature = nil

local function rebaseline()
  for _, ch in ipairs(ALL_CAR) do baseline[ch] = ac.getAudioVolume(ch, 0, 1) end
  for _, ch in ipairs(ALL_GLOBAL) do baseline[ch] = ac.getAudioVolume(ch, nil, 1) end
  lastSignature = nil  -- force re-apply with the new baseline
end
rebaseline()

local function clamp01(v)
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

-- Window 'openness' blend: 0 = fully interior, 1 = fully open.
-- Two-phase ramp like a real window motor. Opening: KICK (75%) of the change
-- in the first FAST_PHASE seconds, the remaining 25% over the rest of
-- state.transitionTime. Closing: the opening curve flipped in time -- (1-KICK)
-- creeps over the first total-FAST_PHASE seconds, KICK lands in the LAST
-- FAST_PHASE. Reversing mid-roll restarts the matching curve from the blend
-- reached so far.
local FAST_PHASE = 0.15
local KICK = 0.75
local openBlend = 0
local transTarget = 0
local transFrom = 0
local transElapsed = 0

local function rampCurve(elapsed, total, opening)
  if elapsed >= total then return 1 end
  if opening then
    if elapsed <= FAST_PHASE then return KICK * elapsed / FAST_PHASE end
    return KICK + (1 - KICK) * (elapsed - FAST_PHASE) / math.max(0.001, total - FAST_PHASE)
  end
  -- closing: the opening curve flipped in time
  if elapsed <= total - FAST_PHASE then
    return (1 - KICK) * elapsed / math.max(0.001, total - FAST_PHASE)
  end
  return (1 - KICK) + KICK * (elapsed - (total - FAST_PHASE)) / FAST_PHASE
end

local lastMode = 0
local lastOpenActive = false
local function applyMix(sim, dt)
  local openActive = state.mode == 1 and (not state.cockpitOnly or sim.isFocusedOnInterior)
  local target = openActive and 1 or 0
  if state.mode ~= lastMode then
    -- the main toggle: two-phase motor curve ramp
    lastMode = state.mode
    if transTarget ~= target then
      transFrom = openBlend
      transTarget = target
      transElapsed = 0
    end
  elseif openActive ~= lastOpenActive then
    -- camera in/out or cockpitOnly tick: a SETTING, not a toggle -> snap instantly
    openBlend, transTarget, transFrom, transElapsed = target, target, target, 0
  end
  lastOpenActive = openActive
  if openBlend ~= transTarget then
    transElapsed = transElapsed + dt
    local total = math.max(FAST_PHASE + 0.01, state.transitionTime)
    openBlend = transFrom + (transTarget - transFrom) * rampCurve(transElapsed, total, transTarget == 1)
    if transElapsed >= total then openBlend = transTarget end
  end

  local insideFactor = state.interiorVolume  -- scales ONLY the interior channels
  -- outside gain interpolates from 1x (closed) to outsideGain (fully open)
  local outsideFactor = 1 + openBlend * (state.outsideGain - 1)  -- interior slider no longer touches outside channels

  -- The blend changes every frame during the transition, so the signature
  -- includes it and the mix is re-applied as it ramps.
  local signature = string.format('%.4f|%.4f|%.4f|%s|%s', insideFactor, outsideFactor,
    openBlend, tostring(sim.focusedCar), tostring(state.exteriorMix))
  if signature == lastSignature then return end
  lastSignature = signature

  if sim.focusedCar >= 0 then
    if tweakBaselineCar ~= sim.focusedCar then
      -- capture each event's own config multiplier once per car so the mix
      -- scales the car's intended volumes instead of flattening them to 1.0
      tweakBaselineCar = sim.focusedCar
      tweakBaseline = {}
      for _, ids in pairs(CAR_EVENT_GROUPS) do
        for _, id in ipairs(ids) do
          local ok, v = pcall(ac.CarAudioTweak.getVolume, id)
          tweakBaseline[id] = (ok and type(v) == 'number' and v > 0) and v or 1.0
        end
      end
    end
    for _, ch in ipairs(ALL_CAR) do
      local factor
      if ch == 'transmission' then
        factor = insideFactor
      elseif ch == 'engine' then
        -- engine blends from interior volume (window closed) to exterior gain
        -- (window open), so the Interior mix slider is actually audible
        factor = insideFactor + openBlend * (outsideFactor - insideFactor)
      elseif ch == 'tyres' then
        -- v1.1.2/1.1.3: tyres 1.75x quieter with the window closed, back to the default
        -- (1.0) volume fully open — ramps with the window blend in between.
        -- NOTE: the channel key is 'tyres' (British spelling) — 'tires' never matches.
        factor = 1 / 1.75 + openBlend * (1 - 1 / 1.75)
      else
        factor = outsideFactor
      end
      appliedFactor[ch] = factor
      local group = CAR_EVENT_GROUPS[ch]
      if group then
        -- CarAudioTweak.setVolume: per-event multiplier that CAN exceed 1.0.
        -- (ac.setAudioVolume is documented 'value from 0 to 1', so boosts above
        -- 1.0 were silently clamped: Round 4 saw x3.50 in debug but no audio.)
        for _, id in ipairs(group) do
          pcall(ac.CarAudioTweak.setVolume, id, (tweakBaseline[id] or 1.0) * factor)
        end
      elseif not unSettableCar[ch] then
        -- 'opponents' (other cars' audio) has no per-event API: stays on the
        -- capped 0..1 channel path, so it can only be attenuated, never boosted.
        if not ac.setAudioVolume(ch, baseline[ch] * factor, 0) then
          unSettableCar[ch] = true  -- this car has no such channel; remember and skip
        end
      end
    end
  end
  for _, ch in ipairs(ALL_GLOBAL) do
    -- CSP refuses setAudioVolume on 'wipers' and 'carComponents' (dynamic
    -- component channels), so they are left completely untouched.
    if ch ~= 'wipers' and ch ~= 'carComponents' and not unSettableGlobal[ch] then
      -- CSP refuses setAudioVolume on weather-driven channels (rain); once a
      -- channel fails we remember it and stop trying, so it never pollutes Last error.
      local factor = outsideFactor  -- track, weather, rain are all exterior sounds
      appliedFactor[ch] = factor
      if not ac.setAudioVolume(ch, baseline[ch] * factor) then unSettableGlobal[ch] = true end
    end
  end
  -- CSP's own realism feature: blend the real exterior game audio into the
  -- interior view when the "window" is open (the shipped exteriorAudioToggle
  -- app uses exactly this).
  ac.setExteriorAudioMix(state.exteriorMix and openBlend or 0)
  -- Note: 'ok and nil or ...' was a Lua trap (ok and nil is always falsy, so
  -- the error string was produced EVERY frame even when nothing failed).
  -- Real failures are now remembered in unSettableCar/unSettableGlobal instead.
end

local function restoreOriginal()
  openBlend = 0
  for _, ids in pairs(CAR_EVENT_GROUPS) do
    for _, id in ipairs(ids) do
      pcall(ac.CarAudioTweak.setVolume, id, tweakBaseline[id] or 1.0)
    end
  end
  if not unSettableCar['opponents'] then ac.setAudioVolume('opponents', baseline['opponents'], 0) end
  for _, ch in ipairs(ALL_GLOBAL) do
    if ch ~= 'wipers' and ch ~= 'carComponents' then ac.setAudioVolume(ch, baseline[ch]) end
  end
  ac.setExteriorAudioMix(0)
end

-- Always put the audio back to normal when the app is unloaded (AC closed).
ac.onRelease(function() restoreOriginal() end)

-- ---------------------------------------------------------------------------
-- Sound engine (verified in CSP SDK v0.2.11):
-- ac.AudioEvent.fromFile(params, reverb) creates an FMOD audio event directly
-- from an audio file (.wav/.ogg/.mp3/.flac) - no soundbank needed. Multiple
-- events play simultaneously and FMOD mixes them; .volume/.pitch are live and
-- can be changed every frame. DSP effects (LowPass, HighPass, Echo, Distortion,
-- PitchShift, Tremolo, Pan, ThreeEQ, ...) attach via params.dsp and tweak with
-- event:setDSPParameter(dsp, key, value).
-- Drop files into OpenedWindow/sounds/ :
--   window_open.*   one-shot, ~1-2 s window motor sound (played when opening)
--   window_close.*  one-shot, closing sound (optional)
--   wind_low.*      LOOPABLE gentle airflow/road hum (dominant at low speed)
--   wind_high.*     LOOPABLE brutal wind blast (dominant at high speed)
-- ---------------------------------------------------------------------------
local soundsDir = ac.dirname() .. '/sounds'
local SOUND_EXTS = { '.wav', '.ogg', '.mp3', '.flac' }

local function findSound(name)
  for _, ext in ipairs(SOUND_EXTS) do
    local p = soundsDir .. '/' .. name .. ext
    local f = io.open(p, 'r')
    if f then f:close() return p end
  end
  return nil
end

local sounds = {
  open = findSound('window_open'),
  close = findSound('window_close'),
  windLow = findSound('wind_low'),
  windHigh = findSound('wind_high'),
}

local windLowEvent, windHighEvent, motorEvent
local windLowVol, windHighVol = 0, 0



-- SDK: AudioEvent.volume is a LIVE field ('from 0 to 1, can go above too'),
-- so the volume of a RUNNING loop can be changed directly, without recreating
-- it (recreating pauses the sound). Round 5: the Fader DSP call reported
-- 'applied' but had no audible effect, so the direct live field is used.
-- Round 6/8: when the camera is OUTSIDE the car the motor sound is heard from
-- outside the car, so it plays at quarter volume (v1.0.2: 0.5 -> 0.25 per user).
local MOTOR_EXTERIOR_FACTOR = 0.25
local function motorEffectiveVolume()
  return state.motorVolume * (ac.getSim().isFocusedOnInterior and 1 or MOTOR_EXTERIOR_FACTOR)
end

local function applyMotorVolume(ev, vol)
  if not ev then return end
  vol = vol or state.motorVolume
  local ok, err = pcall(function() ev.volume = vol end)
  motorVolDebug = 'motor loop volume: ' .. string.format('%.2f', vol) ..
    (ok and ' applied' or ' FAILED: ' .. tostring(err))
  if not ok then lastError = 'loop volume failed: ' .. tostring(err) end
end

local function makeEvent(path, loop, volume)
  local ok, ev = pcall(ac.AudioEvent.fromFile, {
    filename = path,
    use3D = false,   -- 2D: audible everywhere, no positional attenuation
    loop = loop,
    volume = volume or 0,  -- CSP applies volume at creation time
  }, false)
  if not ok or not ev then
    lastError = 'failed to load sound: ' .. path
    return nil
  end
  -- by default custom events are quieter inside the cockpit (0.25); we want full level
  ev.cameraInteriorMultiplier = 1
  ev.cameraExteriorMultiplier = 1
  ev.cameraTrackMultiplier = 1
  return ev
end

local function playMotor(opening)
  local path = opening and sounds.open or sounds.close
  if not path then return end
  if motorEvent then motorEvent:dispose() end  -- one-shot events become invalid after playing
  local effVol = motorEffectiveVolume()
  motorEvent = makeEvent(path, false, effVol)
  if motorEvent then
    motorEvent.volume = effVol
    motorEvent:start()
    -- debug: after a camera change the game rebuilds the audiosystem, which can leave
    -- the native FMOD channel dead even though the Lua event looks fine
    motorDebug = 'motor: vol=' .. tostring(motorEvent.volume) .. ' valid=' .. tostring(motorEvent:isValid())
    if not motorEvent:isValid() then
      motorEvent:dispose()
      motorEvent = makeEvent(path, false, effVol)
      if motorEvent then
        motorEvent.volume = effVol
        motorEvent:start()
        lastError = 'motor: recreated, vol=' .. tostring(motorEvent.volume) .. ' valid=' .. tostring(motorEvent:isValid())
      end
    end
  end
end

-- Loops window_open.wav so live slider changes can be heard.
local panTestEvent
local function stopPanTest()
  if panTestEvent then
    panTestEvent:dispose()
    panTestEvent = nil
  end
end

local function ensureWindEvents()
  if not windLowEvent and sounds.windLow then windLowEvent = makeEvent(sounds.windLow, true) end
  if not windHighEvent and sounds.windHigh then windHighEvent = makeEvent(sounds.windHigh, true) end
  if windLowEvent and not windLowEvent:isPlaying() then windLowEvent:start() end
  if windHighEvent and not windHighEvent:isPlaying() then windHighEvent:start() end
end

local function updateWind(sim, dt)
  local ramp = math.min(1, dt * 3)
  if not state.soundsEnabled or openBlend < 0.001 then
    windLowVol = windLowVol * (1 - ramp)
    windHighVol = windHighVol * (1 - ramp)
    if windLowEvent then windLowEvent.volume = windLowVol end
    if windHighEvent then windHighEvent.volume = windHighVol end
    if windLowEvent and windLowVol < 0.001 then windLowEvent:stop() end
    if windHighEvent and windHighVol < 0.001 then windHighEvent:stop() end
    return
  end
  local speed = sim.focusedCar >= 0 and ac.getCar(sim.focusedCar).speedKmh or 0
  -- crossfade: gentle wind fades out while the brutal wind fades in, driven by
  -- speed; the whole wind layer is gated by the window blend, so it fades in
  -- gradually while the window rolls open.
  local span = math.max(1, state.windMaxSpeed - state.windMinSpeed)
  local t = math.saturate((speed - state.windMinSpeed) / span)
  local targetLow = state.windVolume * openBlend * (1 - t)
  local targetHigh = state.windVolume * openBlend * t
  if targetLow > 0.001 or targetHigh > 0.001 then ensureWindEvents() end
  local k = math.min(1, dt * 4)
  windLowVol = windLowVol + (targetLow - windLowVol) * k
  windHighVol = windHighVol + (targetHigh - windHighVol) * k
  if windLowEvent then windLowEvent.volume = windLowVol end
  if windHighEvent then windHighEvent.volume = windHighVol end
end



-- Toggle button. CSP stores the binding itself (keyboard, wheel or gamepad),
-- so it keeps working in-game even when this app window is closed.
-- ---------------------------------------------------------------------------
-- Window animation integration (v1.1.0)
-- If the car ships window open/close ksanim files (validated detection:
-- filename filter + window node names inside the ksanim; 25 true positives
-- across 556 cars), the toggle drives the car's OWN animation using openBlend
-- as progress, so windows roll in exact sync with the motor sound ramp.
-- Lua patterns have NO '|' alternation: word lists are tables + plain find.
-- ---------------------------------------------------------------------------
local WINDOW_WORDS = { 'window', 'glass', 'vetro', 'steklo', 'finestrino', 'ventana', 'vitre', 'lunette', 'vidro', 'ventanilla' }
local NODE_EXCLUDE = { 'helmet', 'damage', 'hatch', 'wiper', 'cluster', 'visor', 'ntglass', 'intglass', 'license', 'fog', 'head', 'tail', 'lamp', 'light', 'gauge', 'display', 'screen', 'mirror', 'antenna', 'windowframe', 'brake', 'shift', 'steer', 'hood', 'bonnet', 'boot', 'trunk', 'roof', 'wheel', 'seat', 'belt', 'radio', 'dial' }
local FILE_EXCLUDE = { 'door', 'hood', 'bonnet', 'boot', 'trunk', 'hatch', 'wiper', 'light', 'cluster', 'steer', 'shift', 'claim', 'fanspeed', 'drive', 'luk', 'visor', 'gear', 'handbrake' }

local function containsAny(s, list)
  for _, w in ipairs(list) do
    if s:find(w, 1, true) then return true end
  end
  return false
end

local function isWindowName(n)
  local s = n:lower()
  return containsAny(s, WINDOW_WORDS) and not containsAny(s, NODE_EXCLUDE)
end

local function isWindowFile(f)
  local s = f:lower()
  return containsAny(s, WINDOW_WORDS) and not containsAny(s, FILE_EXCLUDE)
end

local function windowNodesInKsanime(data)
  local seen, names = {}, {}
  for token in data:gmatch('[%w_]+') do
    if not seen[token] and isWindowName(token) then
      seen[token] = true
      names[#names+1] = token
    end
  end
  return names
end

local animFiles, animNames, animCarID, animStatus = nil, nil, nil, 'no car'
local animBlend, animTransTarget, animTransFrom, animTransElapsed = 0, 0, 0, 0

local function detectWindowAnims()
  animFiles, animNames = nil, nil
  local slot = ac.getCarID(0)
  if not slot then animStatus = 'no car' return end
  local animDir = ac.getFolder(ac.FolderID.Root) .. '/content/cars/' .. slot .. '/animations'
  if not io.dirExists(animDir) then animStatus = 'no animations dir' return end
  local files, names = {}, {}
  for _, f in ipairs(io.scanDir(animDir, '*.ksanim')) do
    if isWindowFile(f) then
      local data = io.load(animDir .. '/' .. f)
      if data and #windowNodesInKsanime(data) > 0 then
        files[#files+1] = animDir .. '/' .. f
        names[#names+1] = f
      end
    end
  end
  if #files > 0 then
    animFiles, animNames = files, names
    animStatus = #files .. ' window ksanim: ' .. table.concat(names, ', ')
  else
    animStatus = 'no window ksanim in ' .. slot
  end
  lastError = 'anim: ' .. animStatus
end

-- Animation progress: LINEAR ramp over transitionTime. The ksanim plays at its
-- own original tempo (its keyframe curve), just fitted inside the transition;
-- deliberately NOT the two-phase audio kick curve (that would make the window
-- lurch 75% then crawl).
local function driveAnimation(dt)
  if not animFiles or not state.animEnabled then return end
  local target = state.mode == 1 and 1 or 0
  if animTransTarget ~= target then
    animTransFrom = animBlend
    animTransTarget = target
    animTransElapsed = 0
  end
  if animBlend ~= animTransTarget then
    animTransElapsed = animTransElapsed + dt
    local total = math.max(0.01, state.transitionTime)
    animBlend = animTransFrom + (animTransTarget - animTransFrom) * math.min(1, animTransElapsed / total)
    if animTransElapsed >= total then animBlend = animTransTarget end
  end
  -- re-find nodes EVERY frame: camera switches rebuild the scene and invalidate
  -- cached SceneReferences (that is why the animation died on exterior cameras)
  local nodes = ac.findNodes('carRoot:0')
  if not nodes then return end
  for _, f in ipairs(animFiles) do
    nodes:setAnimation(f, animBlend, true)
  end
end

local toggleButton = ac.ControlButton('OpenedWindow.toggle')
toggleButton:setAlwaysActive(true)

local function toggleMode()
  state.mode = state.mode == 0 and 1 or 0
  if state.soundsEnabled then playMotor(state.mode == 1) end
  dirty = true
end

-- Replay recording: CSP lets custom scripts attach a small data stream to a
-- replay. We record the window mode every frame, so a replay applies exactly
-- the toggles the player made while recording.

local lastLoggedError = nil

function script.update(dt)
  local sim = ac.getSim()

  if toggleButton:pressed() then toggleMode() end
  applyMix(sim, dt)
  updateWind(sim, dt)
  -- car change: re-detect window animations; the window starts closed on a new car
  local carID = ac.getCarID(0)
  if carID ~= animCarID then
    animCarID = carID
    state.mode = 0
    openBlend, transTarget, transFrom, transElapsed = 0, 0, 0, 0
    animBlend, animTransTarget, animTransFrom, animTransElapsed = 0, 0, 0, 0
    lastMode, lastOpenActive = 0, false
    detectWindowAnims()
  end
  driveAnimation(dt)
  -- keep RUNNING motor sounds in sync with the slider and the camera: AudioEvent.volume
  -- is live, so a playing loop or one-shot follows changes immediately (Round 6 request).
  -- This also refreshes the 'motor loop volume' debug line every frame.
  local effVol = state.motorVolume * (sim.isFocusedOnInterior and 1 or MOTOR_EXTERIOR_FACTOR)
  if panTestEvent and panTestEvent:isPlaying() then applyMotorVolume(panTestEvent, effVol) end
  if motorEvent and motorEvent:isPlaying() then applyMotorVolume(motorEvent, effVol) end
  -- append every new error to a log file next to the app's settings.ini
  if lastError and lastError ~= lastLoggedError then
    lastLoggedError = lastError
    local f = io.open(logPath, 'a')
    if f then
      f:write(os.date('%Y-%m-%d %H:%M:%S') .. ' | ' .. lastError .. '\r\n')
      f:close()
    end
  end
end

local function soundStatus(name, path)
  return name .. ': ' .. (path and 'found' or 'missing')
end

function windowMain(dt)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(6, 8))

  ui.text('OpenedWindow v1.1.3')
  if state.mode == 0 then
    ui.textColored('Mode: INTERIOR (normal mix)', rgb(0.3, 0.7, 1.0))
  else
    ui.textColored('Mode: OPEN WINDOW (outside x' .. string.format('%.1f', state.outsideGain) .. ')', rgb(0.3, 1.0, 0.5))
  end
  if openBlend > 0.001 and openBlend < 0.999 then
    ui.textColored(string.format('Window rolling... %.0f%% open', openBlend * 100), rgb(1.0, 0.8, 0.3))
  end
  ui.textWrapped('Animation: ' .. animStatus .. (state.animEnabled and '' or ' (animation is OFF)'))

  if ui.button('Toggle mode') then toggleMode() end

  ui.separator()
  if ui.checkbox('Show debug info', state.showDebug) then
    state.showDebug = not state.showDebug
    dirty = true
  end
  if state.showDebug then
    local sim = ac.getSim()
    ui.textWrapped(string.format('Window blend: %.0f%% open | transition: %.1f s (opening: 75%% kick in first 150 ms; closing: 75%% lands in last 150 ms)', openBlend * 100, state.transitionTime))

    ui.textWrapped(string.format('Applied: interior x%.2f, outside x%.2f',
      state.interiorVolume, 1 + openBlend * (state.outsideGain - 1)))
    ui.textWrapped(string.format('Car: %s | camera in car: %s | replay: %s',
      sim.focusedCar >= 0 and ac.getCarName(sim.focusedCar) or 'none',
      tostring(sim.isFocusedOnInterior), tostring(sim.isReplayActive)))
    ui.textWrapped(string.format('Speed: %.0f km/h | wind low: %.2f | wind high: %.2f',
      sim.focusedCar >= 0 and ac.getCar(sim.focusedCar).speedKmh or 0, windLowVol, windHighVol))
    ui.textWrapped('Channel values (baseline -> current):')
    for _, ch in ipairs(ALL_CAR) do
      ui.textWrapped(string.format('  %s: %.2f -> %.2f (x%.2f)', ch, baseline[ch], baseline[ch] * (appliedFactor[ch] or 1), appliedFactor[ch] or 1))
    end
    for _, ch in ipairs(ALL_GLOBAL) do
      ui.textWrapped(string.format('  %s: %.2f -> %.2f (x%.2f)', ch, baseline[ch], baseline[ch] * (appliedFactor[ch] or 1), appliedFactor[ch] or 1))
    end
    ui.textWrapped('Last error: ' .. (lastError or 'none'))
    ui.textWrapped(motorDebug or 'motor: not played yet')
    ui.textWrapped(motorVolDebug or 'motor loop volume: not applied')
    ui.textWrapped('Animation: ' .. animStatus)
    if ui.button('Copy all debug info to clipboard') then
      local lines = {
        string.format('Window blend: %.0f%% open | transition: %.1f s', openBlend * 100, state.transitionTime),
        string.format('Mode: %s | interior x%.2f | outside x%.2f', state.mode == 0 and 'INTERIOR' or 'OPEN',
          state.interiorVolume, state.outsideGain),
        string.format('Cockpit only: %s', state.cockpitOnly),
        string.format('Car: %s | camera in car: %s | replay: %s', sim.focusedCar >= 0 and ac.getCarName(sim.focusedCar) or 'none',
          tostring(sim.isFocusedOnInterior), tostring(sim.isReplayActive)),
        'Channel values (baseline -> current):',
      }
      for _, ch in ipairs(ALL_CAR) do
        lines[#lines + 1] = string.format('  %s: %.2f -> %.2f (x%.2f)', ch, baseline[ch], baseline[ch] * (appliedFactor[ch] or 1), appliedFactor[ch] or 1)
      end
      for _, ch in ipairs(ALL_GLOBAL) do
        lines[#lines + 1] = string.format('  %s: %.2f -> %.2f (x%.2f)', ch, baseline[ch], baseline[ch] * (appliedFactor[ch] or 1), appliedFactor[ch] or 1)
      end
      lines[#lines + 1] = 'Last error: ' .. (lastError or 'none')
      lines[#lines + 1] = motorDebug or 'motor: not played yet'
      lines[#lines + 1] = motorVolDebug or 'motor loop volume: not applied'
      lines[#lines + 1] = 'Animation: ' .. animStatus
      ac.setClipboardText(table.concat(lines, '\n'))
    end
    ui.textWrapped('The app remembers each car\'s original channel volumes as the "window closed" baseline and ramps the mix relative to them. If AC changes the car\'s volumes mid-session (e.g. you edit audio settings), press this to re-capture the baseline. Done automatically for each new car.')
    if ui.button('Re-baseline (take current game volumes as the normal mix)') then rebaseline() end
  end

  ui.separator()

  -- middle mouse click on a slider restores its default (like other AC apps do)
  local function sliderWithReset(name, value, min, max, format, default)
    local v = ui.slider(name, value, min, max, format)
    if ui.mouseClicked(ui.MouseButton.Middle) and ui.itemHovered() then v = default end
    return v
  end
  local function checkboxWithReset(name, value, default)
    local toggled = ui.checkbox(name, value)
    if ui.mouseClicked(ui.MouseButton.Middle) and ui.itemHovered() then return default end
    if toggled then return not value end
    return value
  end

  ui.beginTabBar('tabs')

  if ui.beginTabItem('Volume') then
    ui.textWrapped('Tip: middle-click any slider to reset it to its default.')
    state.interiorVolume = sliderWithReset('Interior mix volume', state.interiorVolume * 100, 0, 150, '%.0f%%', DEFAULTS.interiorVolume * 100) / 100
    state.outsideGain = sliderWithReset('Outside sounds gain', state.outsideGain, 1.0, 4.0, '%.1fx', DEFAULTS.outsideGain)
    local nc = checkboxWithReset('Only apply when camera is inside the car', state.cockpitOnly, DEFAULTS.cockpitOnly)
    if nc ~= state.cockpitOnly then state.cockpitOnly = nc; dirty = true end
    ui.dummy(vec2(0, 6))
    local newMotor = sliderWithReset('Window motor volume', state.motorVolume * 100, 0, 100, '%.0f%%', DEFAULTS.motorVolume * 100) / 100
    if newMotor ~= state.motorVolume then
      state.motorVolume = newMotor
      dirty = true
      applyMotorVolume(panTestEvent, motorEffectiveVolume())  -- live volume change on the running loop
    end
    if ui.button(panTestEvent and 'Stop motor volume test' or 'Motor volume test (window_open sound)') then
      if panTestEvent then
        stopPanTest()
      elseif sounds.open then
        panTestEvent = makeEvent(sounds.open, true, motorEffectiveVolume())
        if panTestEvent then
          applyMotorVolume(panTestEvent, motorEffectiveVolume())
          panTestEvent:start()
        end
      else
        lastError = 'motor volume test needs window_open.* in sounds/'
      end
    end
    ui.dummy(vec2(0, 6))
    if ui.button('Reset to defaults') then
      -- the toggle mode is a live control, not a setting: reset leaves it alone
      state.interiorVolume = DEFAULTS.interiorVolume
      state.outsideGain = DEFAULTS.outsideGain
      state.motorVolume = DEFAULTS.motorVolume
      state.windVolume = DEFAULTS.windVolume
      state.windMinSpeed = DEFAULTS.windMinSpeed
      state.windMaxSpeed = DEFAULTS.windMaxSpeed
      state.cockpitOnly = DEFAULTS.cockpitOnly
      state.exteriorMix = DEFAULTS.exteriorMix
      state.animEnabled = DEFAULTS.animEnabled
      state.soundsEnabled = DEFAULTS.soundsEnabled
      dirty = true
    end
    ui.endTabItem()
  end

  if ui.beginTabItem('Sounds') then
    local ns = checkboxWithReset('Enable window/wind sounds', state.soundsEnabled, DEFAULTS.soundsEnabled)
    if ns ~= state.soundsEnabled then
      state.soundsEnabled = ns
      if not state.soundsEnabled then stopPanTest() end
      dirty = true
    end
    ui.dummy(vec2(0, 6))
    ui.textWrapped('Put sound files in OpenedWindow/sounds/ (wav, ogg, mp3 or flac):')
    ui.textWrapped('  window_open.*  - one-shot window motor (~1-2 s), played when opening')
    ui.textWrapped('  window_close.* - one-shot closing sound (optional)')
    ui.textWrapped('  wind_low.*     - loopable gentle airflow, dominant at low speed')
    ui.textWrapped('  wind_high.*    - loopable brutal wind, dominant at high speed')
    ui.textWrapped('Detected: ' .. soundStatus('window_open', sounds.open) .. ' | ' ..
      soundStatus('window_close', sounds.close) .. ' | ' ..
      soundStatus('wind_low', sounds.windLow) .. ' | ' .. soundStatus('wind_high', sounds.windHigh))
    ui.dummy(vec2(0, 6))

    ui.endTabItem()
  end

  if ui.beginTabItem('Key mapping') then
    if toggleButton:control(vec2(160, 0)) then
      -- the assignment widget was clicked: re-enable the binding if it was cleared
      toggleButton:setDisabled(false)
    end
    ui.textWrapped('Bound to: ' .. (toggleButton:boundTo() or 'nothing (click Assign, then press a key/wheel/gamepad button)'))
    if toggleButton:configured() then
      if toggleButton:disabled() then
        if ui.button('Re-enable binding') then toggleButton:setDisabled(false) end
      else
        if ui.button('Clear binding') then toggleButton:setDisabled(true) end
      end
    end
    ui.textWrapped('The binding is stored by CSP itself, so it works in-game even when this window is closed.')
    ui.textWrapped('Note: the binding name changed to OpenedWindow.toggle in v1.0.1 — reassign your key once.')
    ui.endTabItem()
  end

  if ui.beginTabItem('Extra') then
    local na = checkboxWithReset('Animate car windows with the toggle (car\'s own ksanim)', state.animEnabled, DEFAULTS.animEnabled)
    if na ~= state.animEnabled then state.animEnabled = na; dirty = true end
    ui.textWrapped('Plays the car\'s own window roll animation in sync with the motor sound, at the animation\'s smooth original tempo. Works only on cars that ship window ksanim files (the main tab status line shows which).')
    local ne = checkboxWithReset('Blend real exterior game audio in open mode (CSP built-in)', state.exteriorMix, DEFAULTS.exteriorMix)
    if ne ~= state.exteriorMix then state.exteriorMix = ne; dirty = true end
    ui.dummy(vec2(0, 6))
    ui.textColored('Experimental: these settings may change or move in future versions.', rgb(1.0, 0.8, 0.3))
    state.windVolume = sliderWithReset('Wind volume (at high speed)', state.windVolume * 100, 0, 100, '%.0f%%', DEFAULTS.windVolume * 100) / 100
    state.windMinSpeed = sliderWithReset('Wind starts fading in at', state.windMinSpeed, 0, 100, '%.0f km/h', DEFAULTS.windMinSpeed)
    state.windMaxSpeed = sliderWithReset('Full wind reached at', state.windMaxSpeed, 20, 200, '%.0f km/h', DEFAULTS.windMaxSpeed)
    ui.endTabItem()
  end

  ui.endTabBar()
  ui.popStyleVar()

  if dirty then saveState() end
end

-- dispose custom sounds when the app unloads
ac.onRelease(function()
  stopPanTest()
  if windLowEvent then windLowEvent:dispose() end
  if windHighEvent then windHighEvent:dispose() end
  if motorEvent then motorEvent:dispose() end
end)
