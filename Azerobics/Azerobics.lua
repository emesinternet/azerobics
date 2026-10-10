local addonName = ...
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
local exercises = {
    { key = "pushups", label = "Push-ups" },
    { key = "situps", label = "Sit-ups", file = "situps" },
    { key = "jumpingJacks", label = "Jumping jacks", file = "jumping-jacks" },
}
local countdown, cycleTime, repetitions = 5, 0, 0
local debugMode, wasOnTaxi = false, false
local running, cuePose, soundHandle = false, nil, nil
local flightStartTime, flightRepetitions, flightHadGuide = 0, {}, false
local summaryShown = false
local speedButtons = {}
local exerciseButtons = {}
local factionButtons = {}
local factions = {
    Horde = { background = "horde-background", character = "orc", up = "orc-up", down = "orc-down" },
    Alliance = { background = "alliance-background", character = "night-elf", up = "night-elf-up", down = "night-elf-down" },
}

local sheets = {
    situps = {
        scale = 480 / 1000, left = 240, height = 1024,
        Horde = {
            scale = 1.15,
            origins = { -114, 327 },
            crops = { { 320, 20, 1140, 540 }, { 320, 660, 1140, 970 } },
            contact = { 320, 20, 1140, 540 },
        },
        Alliance = {
            origins = { -78, 343 },
            crops = { { 240, 10, 1210, 570 }, { 240, 630, 1210, 975 } },
            contact = { 240, 10, 1210, 570 },
        },
    },
    jumpingJacks = {
        scale = 576 / 1122, left = 93.5, bottom = 362, height = 2048,
        Horde = {
            origins = { 8, 645 },
            crops = { { 200, 50, 920, 715 }, { 200, 725, 920, 1360 } },
        },
        Alliance = {
            origins = { 28, 626 },
            crops = { { 290, 45, 835, 725 }, { 290, 730, 835, 1345 } },
        },
    },
}

local function StopCue()
    if soundHandle then
        StopSound(soundHandle)
        soundHandle = nil
    end
end

local window = CreateFrame("Frame", "AzerobicsWindow", UIParent, "BackdropTemplate")
window:SetSize(660, 566)
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

local function CreateControl(label, name)
    local button = CreateFrame("Button", name, window, "BackdropTemplate")
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
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

local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 0, 0)
close:SetScript("OnClick", function() window:Hide() end)
window:SetScript("OnHide", function()
    window:StopMovingOrSizing()
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

local up = CreateFrame("Frame", nil, stage)
local down = CreateFrame("Frame", nil, stage)
for _, pose in ipairs({ up, down }) do
    pose.pieces = {}
    for index = 1, 4 do
        pose.pieces[index] = pose:CreateTexture(nil, "ARTWORK")
    end
    pose.sprite = pose:CreateTexture(nil, "ARTWORK")
    pose.mask = pose:CreateMaskTexture()
    pose.mask:SetAllPoints(stage)
    pose.sprite:AddMaskTexture(pose.mask)
end
down:Hide()

local feet = stage:CreateTexture(nil, "ARTWORK")
local contacts = CreateFrame("Frame", nil, stage)
contacts:SetFrameLevel(up:GetFrameLevel() + 1)
local leftHand = contacts:CreateTexture(nil, "ARTWORK")
local contactMask = contacts:CreateMaskTexture()
contactMask:SetAllPoints(stage)
leftHand:AddMaskTexture(contactMask)
local rightHand = contacts:CreateTexture(nil, "ARTWORK")
local bodyShadow = stage:CreateTexture(nil, "BACKGROUND", nil, 1)
local footShadow = stage:CreateTexture(nil, "BACKGROUND", nil, 1)

local counter = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
counter:SetFont(STANDARD_TEXT_FONT, 32, "OUTLINE")
counter:SetPoint("TOP", 0, -16)
counter:SetSize(620, 52)

local function SetArt(texture, file)
    texture:SetTexture(artPath .. file .. ".tga")
    local width = file == "night-elf-up" and 1585 or 1586
    texture:SetTexCoord(0, width / 2048, 0, 992 / 1024)
end

local function SetPiece(texture, file, source, destination, lowerLeft, lowerRight)
    destination = destination or source
    local left, top, right, bottom = unpack(destination)
    texture:SetTexture(artPath .. file .. ".tga")
    texture:SetSize((right - left) * 480 / 1586, (bottom - top) * 300 / 992)
    texture:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 80 + left * 480 / 1586,
        304 - top * 300 / 992)
    local x1, y1, x2, y2 = unpack(source)
    local textureHeight = file == "ground-shadow" and 2048 or 1024
    texture:SetTexCoord(x1 / 2048, y1 / textureHeight, (lowerLeft or x1) / 2048, y2 / textureHeight,
        x2 / 2048, y1 / textureHeight, (lowerRight or x2) / 2048, y2 / textureHeight)
end

local function SetSprite(texture, file, crop, originY, sheet, scale)
    scale = scale or 1
    local left, top, right, bottom = unpack(crop)
    texture:SetTexture(artPath .. file .. ".tga")
    texture:SetSize((right - left) * sheet.scale * scale, (bottom - top) * sheet.scale * scale)
    texture:SetPoint("BOTTOMLEFT", stage, "BOTTOMLEFT", 320 + (80 + (left - sheet.left) * sheet.scale - 320) * scale,
        16 + ((sheet.bottom or 304) - (bottom - originY) * sheet.scale - 16) * scale)
    texture:SetTexCoord(left / 2048, right / 2048, top / sheet.height, bottom / sheet.height)
end

local function SetCharacter(images, faction)
    local exercise = exercises[selectedExercise]
    local pushups = exercise.key == "pushups"
    local sheet = sheets[exercise.key]
    local poses = sheet and sheet[faction]
    local file = sheet and images.character .. "-" .. exercise.file
    leftHand:ClearAllPoints()
    contactMask:SetTexture("Interface\\Buttons\\WHITE8X8")
    contacts:SetShown(pushups or exercise.key == "situps")
    leftHand:SetShown(pushups or exercise.key == "situps")
    rightHand:SetShown(pushups)
    feet:SetShown(pushups)
    footShadow:SetShown(pushups)
    for index, pose in ipairs({ up, down }) do
        pose.mask:SetTexture("Interface\\Buttons\\WHITE8X8")
        pose.sprite:SetShown(not pushups)
        for _, piece in ipairs(pose.pieces) do piece:SetShown(pushups) end
        if not pushups then
            SetSprite(pose.sprite, file, poses.crops[index], poses.origins[index], sheet, poses.scale)
            if poses.contact then
                pose.mask:SetTexture(artPath .. file .. "-body-mask.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            end
        end
    end
    if not pushups then
        if poses.contact then
            -- One masked lower body keeps the hips, knees, calves and boots joined.
            SetSprite(leftHand, file, poses.contact, poses.origins[1], sheet, poses.scale)
            contactMask:SetTexture(artPath .. file .. "-legs-mask.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
        SetPiece(bodyShadow, "ground-shadow", { 0, 0, 1254, 1254 }, { 350, 900, 1236, 984 })
        return
    end
    -- Ground contacts use one texture each; only the body frames change pose.
    SetPiece(leftHand, images.up, { 100, 827, 600, 992 })
    SetPiece(rightHand, images.up, { 986, 827, 1486, 992 })
    local isOrc = faction == "Horde"
    if isOrc then
        SetPiece(feet, images.up, { 600, 700, 986, 855 })
    else
        SetPiece(feet, images.down, { 650, 775, 936, 856 })
    end
    for _, pose in ipairs({ up, down }) do
        local raised = pose == up
        local file = raised and images.up or images.down
        local centerLeft = isOrc and not raised and 500 or 620
        local centerRight = isOrc and not raised and 1086 or 966
        local joinTop = isOrc and not raised and 770 or 560
        SetPiece(pose.pieces[1], file, { 0, 0, 1586, joinTop })
        SetPiece(pose.pieces[2], file, { 0, joinTop, centerLeft, raised and 827 or 810 },
            { 0, joinTop, centerLeft, 827 }, raised and 0 or (isOrc and -65 or -50),
            isOrc and not raised and 473 or centerLeft)
        SetPiece(pose.pieces[3], file, { centerRight, joinTop, 1586, raised and 827 or 810 },
            { centerRight, joinTop, 1586, 827 }, isOrc and not raised and 1113 or centerRight,
            raised and 1586 or (isOrc and 1651 or 1636))
        if raised then
            SetPiece(pose.pieces[4], file, { 620, 560, 966, isOrc and 700 or 690 },
                { 620, 560, 966, isOrc and 700 or 775 })
        else
            -- The orc chest covers the fixed boots; the elf chest ends above them.
            SetPiece(pose.pieces[4], file, { centerLeft, joinTop, centerRight, isOrc and 910 or 775 })
        end
    end
    SetPiece(bodyShadow, "ground-shadow", { 0, 0, 1254, 1254 }, { 440, 850, 1146, 974 })
    SetPiece(footShadow, "ground-shadow", { 0, 0, 1254, 1254 },
        { 600, isOrc and 745 or 795, 986, isOrc and 835 or 855 })
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

local function UpdateFactionButtons()
    for faction, button in pairs(factionButtons) do SelectControl(button, faction == activeFaction) end
end

local speedLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
speedLabel:SetPoint("BOTTOMLEFT", 18, 18)
speedLabel:SetText("Pace")
for index, rate in ipairs(rates) do
    local button = CreateControl(rate)
    button:SetSize(100, 28)
    button:SetPoint("BOTTOMLEFT", 92 + (index - 1) * 108, 10)
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
    local images = factions[faction]
    if not images then return end
    activeFaction = faction
    UpdateFactionButtons()
    SetArt(background, images.background)
    SetCharacter(images, faction)
    countdown, cycleTime, repetitions = 5, 0, 0
    StopCue()
    running, cuePose = true, nil
    debugMode = isDebug and not wasOnTaxi
    if wasOnTaxi then
        flightHadGuide = true
    end
    summaryButton:Hide()
    speedLabel:Show()
    for _, button in ipairs(speedButtons) do button:Show() end
    for _, button in ipairs(exerciseButtons) do button:Show() end
    for _, button in pairs(factionButtons) do button:Show() end
    local restDown = exercises[selectedExercise].key == "situps"
    up:SetShown(not restDown)
    down:SetShown(restDown)
    counter:SetTextColor(1, 0.85, 0.3)
    counter:SetFont(STANDARD_TEXT_FONT, 32, "OUTLINE")
    counter:SetSize(620, 52)
    counter:SetText("Starting in 5")
    window:Show()
end

for index, exercise in ipairs(exercises) do
    local button = CreateControl(exercise.label)
    button:SetSize(200, 28)
    button:SetPoint("TOPLEFT", 18 + (index - 1) * 212, -86)
    button:SetScript("OnClick", function()
        if selectedExercise == index then return end
        selectedExercise = index
        AzerobicsDB.exercise = exercise.key
        UpdateExerciseButtons()
        Start(activeFaction, debugMode)
    end)
    exerciseButtons[index] = button
end

for index, faction in ipairs({ "Horde", "Alliance" }) do
    local button = CreateControl(faction)
    button:SetSize(88, 28)
    button:SetPoint("TOPLEFT", 438 + (index - 1) * 96, -12)
    button:SetScript("OnClick", function()
        if summaryShown or activeFaction == faction then return end
        activeFaction = faction
        SetArt(background, factions[faction].background)
        SetCharacter(factions[faction], faction)
        UpdateFactionButtons()
    end)
    factionButtons[faction] = button
end

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
        Start(UnitFactionGroup("player"), true)
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
    if exercise.key == "situps" then pose = pose == "up" and "down" or "up" end
    if pose ~= cuePose then
        up:SetShown(pose == "up")
        down:SetShown(pose == "down")
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
        if AzerobicsDB.autoStart then Start(UnitFactionGroup("player"), false) end
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
        counter:SetSize(620, 104)
        counter:SetText(flightTime .. (#counts == 1 and " | " or "\n") .. table.concat(counts, "\n"))
        summaryShown = true
        for index, name in ipairs(UISpecialFrames) do
            if name == "AzerobicsWindow" then
                table.remove(UISpecialFrames, index)
                break
            end
        end
        speedLabel:Hide()
        for _, button in ipairs(speedButtons) do button:Hide() end
        for _, button in ipairs(exerciseButtons) do button:Hide() end
        for _, button in pairs(factionButtons) do button:Hide() end
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
        Start(UnitFactionGroup("player"), true)
    elseif command == "h" or command == "horde" then
        Start("Horde", true)
    elseif command == "a" or command == "alliance" then
        Start("Alliance", true)
    else
        print("Azerobics: /azerobics [a | h | hide]")
    end
end
