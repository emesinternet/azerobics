local addonName, addon = ...
local artPath = "Interface\\AddOns\\Azerobics\\Art\\"
local soundPath = "Interface\\AddOns\\Azerobics\\Sounds\\"
-- New sample data uses a new bank name to avoid older cached sounds.
local soundBank = "786082f73141"
local durations = { 6, 4, 3, 2, 1.5 }
local phaseTime = 0.75
local movementTime = phaseTime * 2
local rates = { "Slow", "Easy", "Steady", "Brisk", "Fast" }
local selectedSpeed = 3
local selectedExercise, activeFaction = 1, nil
local selectedRace, selectedSex = 5, "male"
local exercises = {
    { key = "pushups", label = "Push-ups" },
    { key = "situps", label = "Sit-ups" },
    { key = "jumpingJacks", label = "Jumping jacks" },
    { key = "squats", label = "Squats" },
}
local countdown, cycleTime, repetitions = 5, 0, 0
local debugMode, wasOnTaxi = false, false
local running, cuePose, soundHandle = false, nil, nil
local flightStartTime, flightRepetitions, flightHadGuide = 0, {}, false
local summaryShown = false
local speedButtons = {}
local exerciseButtons = {}
local dropdowns = {}
local factions = {
    Horde = { background = "horde-background" },
    Alliance = { background = "alliance-background" },
}

local function StopCue()
    if soundHandle then
        StopSound(soundHandle)
        soundHandle = nil
    end
end

local window = CreateFrame("Frame", "AzerobicsWindow", UIParent, "BackdropTemplate")
window:SetSize(660, 604)
window:SetPoint("CENTER")
window:SetFrameStrata("DIALOG")
window:EnableMouse(true)
window:SetClampedToScreen(true)
window:SetMovable(true)
local dragHandle = CreateFrame("Frame", nil, window)
dragHandle:SetSize(420, 44)
dragHandle:SetPoint("TOPLEFT", 8, 0)
dragHandle:EnableMouse(true)
dragHandle:RegisterForDrag("LeftButton")
dragHandle:SetScript("OnDragStart", function() window:StartMoving() end)
dragHandle:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
window:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
})
window:SetBackdropColor(0.07, 0.065, 0.055, 1)
window:SetBackdropBorderColor(0.65, 0.5, 0.25, 1)
window:Hide()
table.insert(UISpecialFrames, "AzerobicsWindow")

local logo = window:CreateTexture(nil, "ARTWORK")
logo:SetTexture(artPath .. "azerobics-icon.tga")
logo:SetSize(28, 28)
logo:SetPoint("TOPLEFT", 16, -12)
local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
title:SetText("Azerobics")

local function CreateControl(label, name, parent)
    local button = CreateFrame("Button", name, parent or window, "BackdropTemplate")
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    button:SetBackdropColor(0.13, 0.115, 0.09, 1)
    button:SetBackdropBorderColor(0.4, 0.32, 0.2, 1)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.label:SetAllPoints(button)
    button:SetFontString(button.label)
    button:SetText(label)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    button:GetHighlightTexture():SetVertexColor(0.8, 0.65, 0.3, 0.12)
    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.85, 0.68, 0.35, 1)
    end)
    button:SetScript("OnLeave", function(self)
        if self.selected then self:SetBackdropBorderColor(0.85, 0.68, 0.35, 1)
        else self:SetBackdropBorderColor(0.4, 0.32, 0.2, 1) end
    end)
    return button
end

local function SelectControl(button, selected)
    button.selected = selected
    if selected then
        button:LockHighlight()
        button:SetBackdropColor(0.25, 0.19, 0.1, 1)
        button:SetBackdropBorderColor(0.85, 0.68, 0.35, 1)
        button.label:SetTextColor(1, 0.88, 0.57)
    else
        button:UnlockHighlight()
        button:SetBackdropColor(0.13, 0.115, 0.09, 1)
        button:SetBackdropBorderColor(0.4, 0.32, 0.2, 1)
        button.label:SetTextColor(0.8, 0.75, 0.64)
    end
end

local function CloseMenus()
    for _, dropdown in ipairs(dropdowns) do dropdown.menu:Hide() end
end

local dismissMenu = CreateFrame("Button", nil, window)
dismissMenu:SetAllPoints(window)
dismissMenu:SetFrameLevel(window:GetFrameLevel() + 5)
dismissMenu:SetScript("OnClick", function() CloseMenus(); dismissMenu:Hide() end)
dismissMenu:Hide()

local function CreateDropdown(label, name, column, options, choose)
    local button = CreateControl(label, name)
    button:SetSize(202, 32)
    button:SetPoint("TOPLEFT", 18 + column * 210, -82)
    button:SetFrameLevel(window:GetFrameLevel() + 6)
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", 8, 0)
    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetSize(16, 16)
    arrow:SetPoint("RIGHT", -4, 0)
    local menu = CreateFrame("Frame", nil, window, "BackdropTemplate")
    menu:SetSize(202, #options * 30 + 12)
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -4)
    menu:SetFrameLevel(window:GetFrameLevel() + 10)
    menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    menu:SetBackdropColor(0.07, 0.065, 0.055, 1)
    menu:SetBackdropBorderColor(0.65, 0.5, 0.25, 1)
    menu:EnableMouse(true)
    menu:Hide()
    button.menu, button.options = menu, {}
    for index, option in ipairs(options) do
        local item = CreateControl(option.label, nil, menu)
        item:SetSize(190, 28)
        item:SetPoint("TOPLEFT", 6, -6 - (index - 1) * 30)
        item:SetScript("OnClick", function()
            CloseMenus()
            dismissMenu:Hide()
            choose(option.value)
        end)
        button.options[index] = { button = item, value = option.value }
    end
    button:SetScript("OnClick", function()
        local show = not menu:IsShown()
        CloseMenus()
        menu:SetShown(show)
        dismissMenu:SetShown(show)
    end)
    dropdowns[#dropdowns + 1] = button
    return button
end

local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 0, 0)
close:SetScript("OnClick", function() window:Hide() end)
window:SetScript("OnHide", function()
    window:StopMovingOrSizing()
    CloseMenus()
    dismissMenu:Hide()
    if summaryShown then
        table.insert(UISpecialFrames, "AzerobicsWindow")
        summaryShown = false
    end
    running, debugMode, cuePose = false, false, nil
    StopCue()
end)

local soundButton = CreateFrame("CheckButton", "AzerobicsSoundButton", window, "UICheckButtonTemplate")
soundButton:SetSize(24, 24)
soundButton:SetPoint("TOPLEFT", 14, -50)
soundButton.label = soundButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
soundButton.label:SetPoint("LEFT", soundButton, "RIGHT", 2, 0)
soundButton.label:SetText("Sound cues")
soundButton:SetScript("OnClick", function(self)
    AzerobicsDB.soundCues = self:GetChecked()
    if not AzerobicsDB.soundCues then StopCue() end
end)

local autoButton = CreateFrame("CheckButton", "AzerobicsAutoButton", window, "UICheckButtonTemplate")
autoButton:SetSize(24, 24)
autoButton:SetPoint("TOPLEFT", 200, -50)
autoButton.label = autoButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
autoButton.label:SetPoint("LEFT", autoButton, "RIGHT", 2, 0)
autoButton.label:SetText("Start on flights")
autoButton:SetScript("OnClick", function(self)
    AzerobicsDB.autoStart = self:GetChecked()
end)

local volumeSlider = CreateFrame("Slider", "AzerobicsVolumeSlider", window, "OptionsSliderTemplate")
volumeSlider:SetSize(144, 17)
volumeSlider:SetPoint("TOPLEFT", 458, -54)
volumeSlider:SetMinMaxValues(0, 100)
volumeSlider:SetValueStep(25)
volumeSlider:SetObeyStepOnDrag(true)
volumeSlider.Low:SetText("")
volumeSlider.High:SetText("")
volumeSlider.Text:ClearAllPoints()
volumeSlider.Text:SetPoint("LEFT", volumeSlider, "RIGHT", 8, 0)
local volumeIcon = window:CreateTexture(nil, "ARTWORK")
volumeIcon:SetSize(20, 20)
volumeIcon:SetPoint("RIGHT", volumeSlider, "LEFT", -8, 0)
volumeSlider:SetScript("OnValueChanged", function(self, value)
    local volume = math.floor(value / 25 + 0.5) * 25
    if value ~= volume then self:SetValue(volume); return end
    AzerobicsDB.cueVolume = volume
    self.Text:SetFormattedText("%d%%", volume)
    volumeIcon:SetTexture(volume == 0 and "Interface\\Common\\VoiceChat-Muted"
        or "Interface\\Common\\VoiceChat-Speaker")
    StopCue()
end)
volumeSlider:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Sound cue volume")
    GameTooltip:Show()
end)
volumeSlider:SetScript("OnLeave", function() GameTooltip:Hide() end)

local stage = CreateFrame("Frame", nil, window)
stage:SetSize(640, 400)
stage:SetPoint("TOP", 0, -124)

local background = stage:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints(stage)

local feet = stage:CreateTexture(nil, "ARTWORK")
feet:SetSize(128, 60)
feet:SetPoint("BOTTOM", stage, "BOTTOM", 0, 42)

local up = CreateFrame("Frame", nil, stage)
local down = CreateFrame("Frame", nil, stage)
for _, pose in ipairs({ up, down }) do
    pose:SetAllPoints(stage)
    pose.sprite = pose:CreateTexture(nil, "ARTWORK")
    pose.mask = pose:CreateMaskTexture()
    pose.mask:SetSize(512, 512)
    pose.mask:SetPoint("BOTTOM", stage, "BOTTOM", 0, 10)
    pose.sprite:AddMaskTexture(pose.mask)
end
down:Hide()

local contacts = CreateFrame("Frame", nil, stage)
contacts:SetAllPoints(stage)
contacts:SetFrameLevel(up:GetFrameLevel() + 1)
local fixedContacts = contacts:CreateTexture(nil, "ARTWORK")
local contactMask = contacts:CreateMaskTexture()
contactMask:SetSize(512, 512)
contactMask:SetPoint("BOTTOM", stage, "BOTTOM", 0, 10)
fixedContacts:AddMaskTexture(contactMask)
local bodyShadow = stage:CreateTexture(nil, "BACKGROUND", nil, 1)
bodyShadow:SetTexture(artPath .. "ground-shadow.tga")
bodyShadow:SetPoint("BOTTOM", 0, 10)

local counter = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
counter:SetFont(STANDARD_TEXT_FONT, 32, "OUTLINE")
counter:SetPoint("TOP", 0, -16)
counter:SetSize(620, 52)

local function SetArt(texture, file)
    texture:SetTexture(artPath .. file .. ".blp")
    texture:SetTexCoord(0, 1, 0, 640 / 1024)
end

local function SetPose(texture, file, region)
    local x, y, width, height, left, top = unpack(region)
    texture:SetTexture(file .. ".blp")
    texture:SetSize(width, height)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", stage, "TOPLEFT", 64 + left, 122 - top)
    texture:SetTexCoord(x / 1024, (x + width) / 1024, y / 1024, (y + height) / 1024)
end

local function SetCharacter()
    local key = addon.races[selectedRace].key .. "-" .. selectedSex
    local file = artPath .. "Characters\\" .. key
    local frames = addon.frames[key]
    local first = frames[(selectedExercise - 1) * 2 + 1]
    -- Masks use separate square files; the game does not crop mask atlases.
    local maskFile = file .. "-" .. exercises[selectedExercise].key
    for index, pose in ipairs({ up, down }) do
        SetPose(pose.sprite, file, frames[(selectedExercise - 1) * 2 + index])
        pose.mask:SetTexture(maskFile .. "-body-mask.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    SetPose(fixedContacts, file, first)
    contactMask:SetTexture(maskFile .. "-contact-mask.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    contacts:SetShown(exercises[selectedExercise].key ~= "jumpingJacks")
    -- Fixed boots sit behind the body so the lowered chest can cover them.
    local standing = frames[1]
    feet:SetTexture(file .. ".blp")
    feet:SetTexCoord((standing[1] + 192 - standing[5]) / 1024, (standing[1] + 320 - standing[5]) / 1024,
        (standing[2] + 420 - standing[6]) / 1024, (standing[2] + 480 - standing[6]) / 1024)
    feet:SetShown(selectedExercise == 1)
    bodyShadow:SetSize(selectedExercise == 2 and 420 or 300, 26)
end

local function ResolveCharacter()
    local _, playerRace = UnitRace("player")
    selectedRace = 5
    for index, race in ipairs(addon.races) do
        if (AzerobicsDB.race == "auto" and race.token == playerRace)
            or AzerobicsDB.race == race.key then selectedRace = index end
    end
    selectedSex = AzerobicsDB.sex == "auto" and (UnitSex("player") == 3 and "female" or "male")
        or AzerobicsDB.sex
end

local function UpdateSelectors()
    local values = { AzerobicsDB.faction, AzerobicsDB.race, AzerobicsDB.sex }
    local resolved = { activeFaction or UnitFactionGroup("player"), addon.races[selectedRace].label,
        selectedSex == "female" and "Female" or "Male" }
    for index, dropdown in ipairs(dropdowns) do
        dropdown:SetText(values[index] == "auto" and "Auto (" .. resolved[index] .. ")" or resolved[index])
        for _, option in ipairs(dropdown.options) do
            SelectControl(option.button, option.value == values[index])
        end
    end
end

local function UpdateSpeedButtons()
    for index, button in ipairs(speedButtons) do
        SelectControl(button, index == selectedSpeed)
    end
end

local function UpdateExerciseButtons()
    for index, button in ipairs(exerciseButtons) do
        SelectControl(button, index == selectedExercise)
    end
end

for index, rate in ipairs(rates) do
    local button = CreateControl(rate)
    button:SetSize(118, 28)
    button:SetPoint("BOTTOMLEFT", 18 + (index - 1) * 126, 10)
    button:SetScript("OnClick", function()
        cycleTime = math.min(cycleTime, durations[index])
        selectedSpeed = index
        AzerobicsDB.speed = index
        UpdateSpeedButtons()
    end)
    speedButtons[index] = button
end

local summaryButton = CreateControl("Close summary", "AzerobicsSummaryClose")
summaryButton:SetSize(160, 28)
summaryButton:SetPoint("BOTTOM", 0, 10)
summaryButton:SetScript("OnClick", function() window:Hide() end)
summaryButton:Hide()

local function Start(faction, isDebug)
    if summaryShown then return end
    faction = faction or (AzerobicsDB.faction == "auto" and UnitFactionGroup("player") or AzerobicsDB.faction)
    local images = factions[faction]
    if not images then return end
    activeFaction = faction
    ResolveCharacter()
    UpdateSelectors()
    SetArt(background, images.background)
    SetCharacter()
    countdown, cycleTime, repetitions = 5, 0, 0
    StopCue()
    running, cuePose = true, nil
    debugMode = isDebug and not wasOnTaxi
    if wasOnTaxi then
        flightHadGuide = true
    end
    summaryButton:Hide()
    CloseMenus()
    dismissMenu:Hide()
    for _, dropdown in ipairs(dropdowns) do dropdown:Show() end
    for _, button in ipairs(speedButtons) do button:Show() end
    for _, button in ipairs(exerciseButtons) do button:Show() end
    up:Show()
    down:Hide()
    counter:SetTextColor(1, 0.85, 0.3)
    counter:SetFont(STANDARD_TEXT_FONT, 32, "OUTLINE")
    counter:ClearAllPoints()
    counter:SetPoint("TOP", stage, "TOP", 0, -16)
    counter:SetSize(620, 52)
    counter:SetText("Starting in 5")
    window:Show()
end

for index, exercise in ipairs(exercises) do
    local button = CreateControl(exercise.label)
    button:SetSize(150, 28)
    button:SetPoint("BOTTOMLEFT", 18 + (index - 1) * 158, 46)
    button:SetScript("OnClick", function()
        if selectedExercise == index then return end
        selectedExercise = index
        AzerobicsDB.exercise = exercise.key
        UpdateExerciseButtons()
        Start(activeFaction, debugMode)
    end)
    exerciseButtons[index] = button
end

CreateDropdown("Faction", "AzerobicsFactionButton", 0, {
    { label = "Auto", value = "auto" }, { label = "Horde", value = "Horde" },
    { label = "Alliance", value = "Alliance" },
}, function(value)
    AzerobicsDB.faction = value
    activeFaction = value == "auto" and UnitFactionGroup("player") or value
    SetArt(background, factions[activeFaction].background)
    UpdateSelectors()
end)

local raceOptions = { { label = "Auto", value = "auto" } }
for _, race in ipairs(addon.races) do
    raceOptions[#raceOptions + 1] = { label = race.label, value = race.key }
end
CreateDropdown("Race", "AzerobicsRaceButton", 1, raceOptions, function(value)
    AzerobicsDB.race = value
    ResolveCharacter()
    UpdateSelectors()
    SetCharacter()
end)

CreateDropdown("Sex", "AzerobicsSexButton", 2, {
    { label = "Auto", value = "auto" }, { label = "Male", value = "male" },
    { label = "Female", value = "female" },
}, function(value)
    AzerobicsDB.sex = value
    ResolveCharacter()
    UpdateSelectors()
    SetCharacter()
end)

local minimapButton = CreateFrame("Button", "AzerobicsMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetPoint("TOPLEFT", -8, 0)
minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 5)
minimapButton:RegisterForClicks("LeftButtonUp")
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local minimapBackground = minimapButton:CreateTexture(nil, "BACKGROUND")
minimapBackground:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
minimapBackground:SetSize(25, 25)
minimapBackground:SetPoint("TOPLEFT", 3, -4)
local minimapIcon = minimapButton:CreateTexture(nil, "ARTWORK")
minimapIcon:SetTexture(artPath .. "azerobics-icon.tga")
minimapIcon:SetSize(20, 20)
minimapIcon:SetPoint("TOPLEFT", 7, -6)
local minimapBorder = minimapButton:CreateTexture(nil, "OVERLAY")
minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapBorder:SetSize(54, 54)
minimapBorder:SetPoint("TOPLEFT")
minimapButton:SetScript("OnClick", function()
    if summaryShown then return end
    if window:IsShown() then
        window:Hide()
    else
        Start(nil, true)
    end
end)
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Azerobics")
    GameTooltip:AddLine(summaryShown and "Click Close summary in the window."
        or "Click to open or close the guide.", 1, 1, 1)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

window:SetScript("OnUpdate", function(_, elapsed)
    if not running then return end
    if countdown > 0 then
        countdown = countdown - elapsed
        if countdown > 0 then
            counter:SetFormattedText("Starting in %d", math.ceil(countdown))
            return
        end
        elapsed = -countdown
        countdown = 0
        counter:SetTextColor(1, 1, 1)
    end
    local duration = durations[selectedSpeed]
    local exercise = exercises[selectedExercise]
    local countTime = exercise.key == "situps" and phaseTime or movementTime
    local completed = math.floor((cycleTime + elapsed - countTime) / duration)
        - math.floor((cycleTime - countTime) / duration)
    cycleTime = cycleTime + elapsed
    repetitions = repetitions + completed
    if wasOnTaxi then
        flightRepetitions[exercise.key] = (flightRepetitions[exercise.key] or 0) + completed
    end
    cycleTime = cycleTime % duration
    if completed > 0 or cuePose == nil then
        counter:SetFormattedText("%s: %d", exercise.label, repetitions)
    end
    local pose = cycleTime >= phaseTime and cycleTime < movementTime and "down" or "up"
    local activePose = pose == "down"
    if exercise.key == "situps" then pose = activePose and "up" or "down" end
    if pose ~= cuePose then
        up:SetShown(not activePose)
        down:SetShown(activePose)
        cuePose = pose
        StopCue()
        if AzerobicsDB.soundCues and AzerobicsDB.cueVolume > 0 then
            local played, handle = PlaySoundFile(soundPath .. pose .. "-" .. soundBank .. "-" .. AzerobicsDB.cueVolume .. ".ogg", "SFX")
            soundHandle = played and handle or nil
        end
    end
end)

local function CheckFlight()
    local onTaxi = not not UnitOnTaxi("player")
    if onTaxi == wasOnTaxi then return end
    wasOnTaxi = onTaxi
    if onTaxi then
        flightStartTime, flightRepetitions, flightHadGuide = GetTime(), {}, false
        if AzerobicsDB.autoStart then Start(nil, false) end
    elseif flightHadGuide then
        running, debugMode, cuePose = false, false, nil
        StopCue()
        down:Hide()
        up:Show()
        local seconds = math.floor(GetTime() - flightStartTime)
        counter:SetFont(STANDARD_TEXT_FONT, 22, "OUTLINE")
        counter:SetTextColor(1, 1, 1)
        local counts = {}
        for _, exercise in ipairs(exercises) do
            local count = flightRepetitions[exercise.key] or 0
            if count > 0 then counts[#counts + 1] = string.format("%s: %d", exercise.label, count) end
        end
        if #counts == 0 then counts[1] = exercises[selectedExercise].label .. ": 0" end
        local flightTime = string.format("Flight time: %d:%02d", math.floor(seconds / 60), seconds % 60)
        counter:ClearAllPoints()
        counter:SetPoint("TOP", window, "TOP", 0, -74)
        counter:SetSize(620, 120)
        counter:SetText(flightTime .. (#counts == 1 and " | " or "\n") .. table.concat(counts, "\n"))
        summaryShown = true
        for index, name in ipairs(UISpecialFrames) do
            if name == "AzerobicsWindow" then
                table.remove(UISpecialFrames, index)
                break
            end
        end
        CloseMenus()
        dismissMenu:Hide()
        for _, dropdown in ipairs(dropdowns) do dropdown:Hide() end
        for _, button in ipairs(speedButtons) do button:Hide() end
        for _, button in ipairs(exerciseButtons) do button:Hide() end
        summaryButton:Show()
        window:Show()
    elseif not debugMode and not summaryShown then
        window:Hide()
    end
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_CONTROL_LOST")
driver:RegisterEvent("PLAYER_CONTROL_GAINED")
driver:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addonName then return end
        if type(AzerobicsDB) ~= "table" then AzerobicsDB = {} end
        local savedSpeed = AzerobicsDB.speed
        if AzerobicsDB.speedVersion ~= 2 then
            local previousSpeeds = { 2, 3, 4, 5, 5 }
            savedSpeed = type(savedSpeed) == "number" and previousSpeeds[savedSpeed] or nil
        end
        if type(savedSpeed) == "number" and durations[savedSpeed] then
            selectedSpeed = savedSpeed
        end
        AzerobicsDB.speed = selectedSpeed
        AzerobicsDB.speedVersion = 2
        for index, exercise in ipairs(exercises) do
            if AzerobicsDB.exercise == exercise.key then selectedExercise = index end
        end
        AzerobicsDB.exercise = exercises[selectedExercise].key
        local validRace = AzerobicsDB.race == "auto"
        for index, race in ipairs(addon.races) do
            if AzerobicsDB.race == race.key then validRace = true end
        end
        if not validRace then AzerobicsDB.race = "auto" end
        if AzerobicsDB.sex ~= "male" and AzerobicsDB.sex ~= "female" then AzerobicsDB.sex = "auto" end
        if not factions[AzerobicsDB.faction] then AzerobicsDB.faction = "auto" end
        ResolveCharacter()
        UpdateSelectors()
        if type(AzerobicsDB.soundCues) ~= "boolean" then AzerobicsDB.soundCues = true end
        if type(AzerobicsDB.autoStart) ~= "boolean" then AzerobicsDB.autoStart = true end
        local volumes = { [0] = true, [25] = true, [50] = true, [75] = true, [100] = true }
        if not volumes[AzerobicsDB.cueVolume] then AzerobicsDB.cueVolume = 100 end
        soundButton:SetChecked(AzerobicsDB.soundCues)
        autoButton:SetChecked(AzerobicsDB.autoStart)
        volumeSlider:SetValue(AzerobicsDB.cueVolume)
        UpdateSpeedButtons()
        UpdateExerciseButtons()
    else
        CheckFlight()
    end
end)
local pollTime = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    pollTime = pollTime + elapsed
    if pollTime >= 0.2 then
        pollTime = 0
        CheckFlight()
    end
end)

SLASH_AZEROBICS1 = "/azerobics"
SlashCmdList.AZEROBICS = function(message)
    if summaryShown then return end
    local command = message:lower():match("^%s*(%a*)%s*$")
    if command == "hide" then
        window:Hide()
    elseif command == "" then
        Start(nil, true)
    elseif command == "h" or command == "horde" then
        Start("Horde", true)
    elseif command == "a" or command == "alliance" then
        Start("Alliance", true)
    else
        print("Azerobics: /azerobics [a | h | hide]")
    end
end
