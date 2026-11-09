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
local white = "Interface\\Buttons\\WHITE8X8"
local uiFont = "Fonts\\ARIALN.TTF"

local function CreateLabel(parent, text, size, r, g, b)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetFont(uiFont, size, "")
    label:SetTextColor(r or 0.91, g or 0.89, b or 0.84)
    label:SetText(text)
    return label
end

local function CreateSurface(parent, width, height)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(width, height)
    panel:SetBackdrop({ bgFile = white, edgeFile = white, edgeSize = 1 })
    panel:SetBackdropColor(0.095, 0.085, 0.073, 1)
    panel:SetBackdropBorderColor(0.23, 0.21, 0.18, 1)
    local highlight = panel:CreateTexture(nil, "BORDER")
    highlight:SetColorTexture(0.72, 0.64, 0.48, 0.10)
    highlight:SetPoint("TOPLEFT", 1, -1)
    highlight:SetPoint("TOPRIGHT", -1, -1)
    highlight:SetHeight(1)
    return panel
end

local function StopCue()
    if soundHandle then
        StopSound(soundHandle)
        soundHandle = nil
    end
end

local window = CreateFrame("Frame", "AzerobicsWindow", UIParent, "BackdropTemplate")
window:SetSize(688, 704)
window:SetPoint("CENTER")
window:SetFrameStrata("DIALOG")
window:EnableMouse(true)
window:SetClampedToScreen(true)
window:SetMovable(true)
local dragHandle = CreateFrame("Frame", nil, window)
dragHandle:SetSize(620, 54)
dragHandle:SetPoint("TOPLEFT", 0, 0)
dragHandle:EnableMouse(true)
dragHandle:RegisterForDrag("LeftButton")
dragHandle:SetScript("OnDragStart", function() window:StartMoving() end)
dragHandle:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
window:SetBackdrop({
    bgFile = white,
    edgeFile = white,
    edgeSize = 1,
})
window:SetBackdropColor(0.055, 0.049, 0.041, 1)
window:SetBackdropBorderColor(0.30, 0.27, 0.21, 1)
window:Hide()
table.insert(UISpecialFrames, "AzerobicsWindow")

local header = window:CreateTexture(nil, "BACKGROUND")
header:SetColorTexture(0.10, 0.087, 0.067, 1)
header:SetPoint("TOPLEFT", 1, -1)
header:SetSize(686, 52)
local headerAccent = window:CreateTexture(nil, "ARTWORK")
headerAccent:SetColorTexture(0.76, 0.58, 0.30, 1)
headerAccent:SetPoint("TOPLEFT", 24, -1)
headerAccent:SetSize(40, 2)
local headerLine = window:CreateTexture(nil, "BORDER")
headerLine:SetColorTexture(0.30, 0.25, 0.17, 1)
headerLine:SetPoint("TOPLEFT", 1, -53)
headerLine:SetSize(686, 1)
local logoPlate = CreateSurface(window, 40, 40)
logoPlate:SetPoint("TOPLEFT", 20, -6)
logoPlate:SetBackdropBorderColor(0.42, 0.33, 0.20, 1)
local logo = logoPlate:CreateTexture(nil, "ARTWORK")
logo:SetTexture(artPath .. "azerobics-icon.tga")
logo:SetSize(32, 32)
logo:SetPoint("CENTER")
local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetFont(STANDARD_TEXT_FONT, 20, "")
title:SetTextColor(0.96, 0.92, 0.82)
title:SetPoint("TOPLEFT", 72, -9)
title:SetText("Azerobics")
local subtitle = CreateLabel(window, "Your in-flight exercise break", 12, 0.64, 0.61, 0.54)
subtitle:SetPoint("TOPLEFT", 73, -33)

local settingsPanel = CreateSurface(window, 640, 104)
settingsPanel:SetPoint("TOPLEFT", 24, -64)
local settingsDivider = settingsPanel:CreateTexture(nil, "ARTWORK")
settingsDivider:SetColorTexture(0.23, 0.21, 0.18, 1)
settingsDivider:SetSize(614, 1)
settingsDivider:SetPoint("TOPLEFT", 13, -70)
local footer = CreateFrame("Frame", nil, window)
footer:SetSize(640, 100)
footer:SetPoint("TOPLEFT", 24, -592)
local exerciseLabel = CreateLabel(footer, "Exercise", 12, 0.66, 0.62, 0.54)
exerciseLabel:SetPoint("TOPLEFT")
local exerciseLine = footer:CreateTexture(nil, "ARTWORK")
exerciseLine:SetColorTexture(0.23, 0.21, 0.18, 1)
exerciseLine:SetPoint("TOPLEFT", 64, -6)
exerciseLine:SetSize(576, 1)
local paceLabel = CreateLabel(footer, "Pace", 12, 0.66, 0.62, 0.54)
paceLabel:SetPoint("LEFT", footer, "TOPLEFT", 0, -84)
local summaryPanel = CreateSurface(window, 640, 116)
summaryPanel:SetPoint("TOPLEFT", 24, -58)
summaryPanel:Hide()

local function UpdateControl(button)
    if button.selected then
        button:SetBackdropColor(0.22, 0.17, 0.10, 1)
        button:SetBackdropBorderColor(0.64, 0.48, 0.26, 1)
        button.label:SetTextColor(1, 0.87, 0.62)
    elseif button.hovered then
        button:SetBackdropColor(0.17, 0.15, 0.12, 1)
        button:SetBackdropBorderColor(0.48, 0.40, 0.28, 1)
        button.label:SetTextColor(1, 0.96, 0.87)
    else
        button:SetBackdropColor(0.115, 0.10, 0.08, 1)
        button:SetBackdropBorderColor(0.28, 0.25, 0.20, 1)
        button.label:SetTextColor(0.82, 0.79, 0.72)
    end
    button.selectedMark:SetShown(button.selected)
end

local function CreateControl(label, name, parent)
    local button = CreateFrame("Button", name, parent or window, "BackdropTemplate")
    button:SetBackdrop({ bgFile = white, edgeFile = white, edgeSize = 1 })
    button.label = CreateLabel(button, label, 13)
    button.label:SetAllPoints(button)
    button:SetFontString(button.label)
    button:SetText(label)
    button.selectedMark = button:CreateTexture(nil, "ARTWORK")
    button.selectedMark:SetColorTexture(0.85, 0.66, 0.36, 1)
    button.selectedMark:SetPoint("BOTTOMLEFT", 1, 1)
    button.selectedMark:SetPoint("BOTTOMRIGHT", -1, 1)
    button.selectedMark:SetHeight(2)
    button:SetPushedTexture(white)
    button:GetPushedTexture():SetVertexColor(0, 0, 0, 0.22)
    button:SetScript("OnEnter", function(self)
        self.hovered = true
        UpdateControl(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.hovered = false
        UpdateControl(self)
    end)
    UpdateControl(button)
    return button
end

local function SelectControl(button, selected)
    button.selected = selected
    UpdateControl(button)
end

local function CloseMenus()
    for _, dropdown in ipairs(dropdowns) do
        dropdown.menu:Hide()
        SelectControl(dropdown, false)
    end
end

local dismissMenu = CreateFrame("Button", nil, window)
dismissMenu:SetAllPoints(window)
dismissMenu:SetFrameLevel(window:GetFrameLevel() + 5)
dismissMenu:SetScript("OnClick", function() CloseMenus(); dismissMenu:Hide() end)
dismissMenu:Hide()

local function CreateDropdown(label, name, column, options, choose)
    local button = CreateControl(label, name, settingsPanel)
    button:SetSize(200, 32)
    button:SetPoint("TOPLEFT", 12 + column * 208, -28)
    button:SetFrameLevel(window:GetFrameLevel() + 6)
    local caption = CreateLabel(button, label, 12, 0.66, 0.62, 0.54)
    caption:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 1, 6)
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", 10, 0)
    button.label:SetPoint("RIGHT", -26, 0)
    button.label:SetJustifyH("LEFT")
    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetSize(12, 12)
    arrow:SetVertexColor(0.76, 0.70, 0.58)
    arrow:SetPoint("RIGHT", -9, 0)
    local menu = CreateSurface(window, 200, #options * 30 + 12)
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -4)
    menu:SetFrameLevel(window:GetFrameLevel() + 10)
    menu:EnableMouse(true)
    menu:Hide()
    button.menu, button.options = menu, {}
    for index, option in ipairs(options) do
        local item = CreateControl(option.label, nil, menu)
        item:SetSize(188, 28)
        item:SetPoint("TOPLEFT", 6, -6 - (index - 1) * 30)
        item.label:ClearAllPoints()
        item.label:SetPoint("LEFT", 10, 0)
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
        SelectControl(button, show)
        dismissMenu:SetShown(show)
    end)
    dropdowns[#dropdowns + 1] = button
    return button
end

local close = CreateControl("x", "AzerobicsCloseButton")
close:SetSize(28, 28)
close:SetPoint("TOPRIGHT", -20, -13)
close.label:SetFont(uiFont, 18, "")
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
    flightHadGuide = false
    StopCue()
end)

local function CreateToggle(label, name, x, hint)
    local button = CreateFrame("CheckButton", name, settingsPanel, "BackdropTemplate")
    button:SetSize(18, 18)
    button:SetPoint("TOPLEFT", x, -78)
    button:SetHitRectInsets(0, -106, -4, -4)
    button:SetBackdrop({ bgFile = white, edgeFile = white, edgeSize = 1 })
    button:SetBackdropColor(0.045, 0.04, 0.033, 1)
    button:SetBackdropBorderColor(0.42, 0.35, 0.24, 1)
    button:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    button:GetCheckedTexture():SetVertexColor(1, 0.86, 0.59)
    button:SetHighlightTexture(white)
    button:GetHighlightTexture():SetVertexColor(0.85, 0.66, 0.36, 0.15)
    button.label = CreateLabel(button, label, 13)
    button.label:SetPoint("LEFT", button, "RIGHT", 8, 0)
    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.85, 0.66, 0.36, 1)
        self.label:SetTextColor(1, 0.96, 0.87)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(label)
        GameTooltip:AddLine(hint, 0.82, 0.79, 0.72, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.42, 0.35, 0.24, 1)
        self.label:SetTextColor(0.91, 0.89, 0.84)
        GameTooltip:Hide()
    end)
    return button
end

local soundButton = CreateToggle("Sound cues", "AzerobicsSoundButton", 14,
    "Play an up or down cue for each movement.")
soundButton:SetScript("OnClick", function(self)
    AzerobicsDB.soundCues = self:GetChecked()
    if not AzerobicsDB.soundCues then StopCue() end
end)

local autoButton = CreateToggle("Start on flights", "AzerobicsAutoButton", 146,
    "Open the exercise guide when a flight starts.")
autoButton:SetScript("OnClick", function(self)
    AzerobicsDB.autoStart = self:GetChecked()
end)

local cycleButton = CreateToggle("Cycle workouts", "AzerobicsCycleButton", 284,
    "Select the next exercise each time the guide opens while flying: push-ups, sit-ups, jumping jacks, then squats.")
cycleButton:SetScript("OnClick", function(self)
    AzerobicsDB.cycleWorkouts = self:GetChecked()
end)

local volumeSlider = CreateFrame("Slider", "AzerobicsVolumeSlider", settingsPanel)
volumeSlider:SetSize(130, 18)
volumeSlider:SetPoint("TOPLEFT", 444, -78)
volumeSlider:SetOrientation("HORIZONTAL")
volumeSlider:EnableMouse(true)
local volumeTrack = volumeSlider:CreateTexture(nil, "BACKGROUND")
volumeTrack:SetColorTexture(0.30, 0.26, 0.20, 1)
volumeTrack:SetSize(130, 3)
volumeTrack:SetPoint("CENTER")
local volumeFill = volumeSlider:CreateTexture(nil, "ARTWORK")
volumeFill:SetColorTexture(0.72, 0.54, 0.29, 1)
volumeFill:SetPoint("LEFT")
volumeFill:Hide()
volumeSlider:SetThumbTexture(white)
volumeSlider:GetThumbTexture():SetVertexColor(0.85, 0.68, 0.40, 1)
volumeSlider:GetThumbTexture():SetSize(8, 16)
volumeSlider:SetMinMaxValues(0, 100)
volumeSlider:SetValueStep(25)
volumeSlider:SetObeyStepOnDrag(true)
volumeSlider.Text = CreateLabel(volumeSlider, "0%", 12, 0.82, 0.79, 0.72)
volumeSlider.Text:SetPoint("LEFT", volumeSlider, "RIGHT", 8, 0)
local volumeIcon = settingsPanel:CreateTexture(nil, "ARTWORK")
volumeIcon:SetTexture("Interface\\Common\\VoiceChat-Muted")
volumeIcon:SetSize(16, 16)
volumeIcon:SetPoint("RIGHT", volumeSlider, "LEFT", -8, 0)
volumeIcon:SetVertexColor(0.82, 0.75, 0.61)
volumeSlider:SetScript("OnValueChanged", function(self, value)
    local volume = math.floor(value / 25 + 0.5) * 25
    if value ~= volume then self:SetValue(volume); return end
    AzerobicsDB.cueVolume = volume
    self.Text:SetFormattedText("%d%%", volume)
    volumeFill:SetSize(130 * volume / 100, 3)
    volumeFill:SetShown(volume > 0)
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

local stageBorder = CreateSurface(window, 642, 402)
stageBorder:SetPoint("TOP", 0, -179)
local stage = CreateFrame("Frame", nil, stageBorder)
stage:SetSize(640, 400)
stage:SetPoint("CENTER")

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
    local button = CreateControl(rate, nil, footer)
    button:SetSize(110, 32)
    button:SetPoint("TOPLEFT", 58 + (index - 1) * 118, -68)
    button:SetScript("OnClick", function()
        cycleTime = math.min(cycleTime, durations[index])
        selectedSpeed = index
        AzerobicsDB.speed = index
        UpdateSpeedButtons()
    end)
    speedButtons[index] = button
end

local summaryButton = CreateControl("Close summary", "AzerobicsSummaryClose")
summaryButton:SetSize(180, 34)
summaryButton:SetPoint("BOTTOM", 0, 16)
local summaryHint = CreateLabel(summaryButton, "Your totals stay here until you close the window.", 13, 0.66, 0.62, 0.54)
summaryHint:SetPoint("BOTTOM", summaryButton, "TOP", 0, 18)
SelectControl(summaryButton, true)
summaryButton:SetScript("OnClick", function() window:Hide() end)
summaryButton:Hide()

local function Start(faction, isDebug)
    if summaryShown then return end
    faction = faction or (AzerobicsDB.faction == "auto" and UnitFactionGroup("player") or AzerobicsDB.faction)
    local images = factions[faction]
    if not images then return end
    if AzerobicsDB.cycleWorkouts and UnitOnTaxi("player") and not window:IsShown() then
        selectedExercise = selectedExercise % #exercises + 1
        AzerobicsDB.exercise = exercises[selectedExercise].key
        UpdateExerciseButtons()
    end
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
    summaryPanel:Hide()
    settingsPanel:Show()
    footer:Show()
    subtitle:SetText("Your in-flight exercise break")
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
    local button = CreateControl(exercise.label, nil, footer)
    button:SetSize(154, 36)
    button:SetPoint("TOPLEFT", (index - 1) * 162, -20)
    button:SetScript("OnClick", function()
        if selectedExercise == index then return end
        selectedExercise = index
        AzerobicsDB.exercise = exercise.key
        UpdateExerciseButtons()
        Start(activeFaction, debugMode)
    end)
    exerciseButtons[index] = button
end

CreateDropdown("Background", "AzerobicsFactionButton", 0, {
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
minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 5)
minimapButton:RegisterForClicks("LeftButtonUp")
minimapButton:RegisterForDrag("LeftButton")
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

local function UpdateMinimapPosition()
    local angle = math.rad(AzerobicsDB.minimapAngle)
    minimapButton:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * (Minimap:GetWidth() / 2 + 5),
        math.sin(angle) * (Minimap:GetHeight() / 2 + 5))
end

local function DragMinimapButton()
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    AzerobicsDB.minimapAngle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX)) % 360
    UpdateMinimapPosition()
end

local function StopMinimapDrag(self)
    self:SetScript("OnUpdate", nil)
    self.dragging = false
    self:UnlockHighlight()
end

minimapButton:SetScript("OnMouseDown", function(self) self.dragged = false end)
minimapButton:SetScript("OnDragStart", function(self)
    self.dragging, self.dragged = true, true
    self:LockHighlight()
    GameTooltip:Hide()
    self:SetScript("OnUpdate", DragMinimapButton)
    DragMinimapButton()
end)
minimapButton:SetScript("OnDragStop", StopMinimapDrag)
minimapButton:SetScript("OnHide", StopMinimapDrag)
minimapButton:SetScript("OnClick", function(self)
    if self.dragged or summaryShown then return end
    if window:IsShown() then
        window:Hide()
    else
        Start(nil, true)
    end
end)
minimapButton:SetScript("OnEnter", function(self)
    if self.dragging then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Azerobics")
    GameTooltip:AddLine(summaryShown and "Click Close summary in the window."
        or "Click to open or close the guide.", 1, 1, 1)
    GameTooltip:AddLine("Hold the left mouse button and drag to move around the minimap.", 0.8, 0.75, 0.64)
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
        counter:SetFont(uiFont, 19, "")
        counter:SetTextColor(0.96, 0.92, 0.82)
        local counts = {}
        for _, exercise in ipairs(exercises) do
            local count = flightRepetitions[exercise.key] or 0
            if count > 0 then counts[#counts + 1] = string.format("%s: %d", exercise.label, count) end
        end
        if #counts == 0 then counts[1] = exercises[selectedExercise].label .. ": 0" end
        local flightTime = string.format("Flight time: %d:%02d", math.floor(seconds / 60), seconds % 60)
        counter:ClearAllPoints()
        counter:SetPoint("TOP", summaryPanel, "TOP", 0, -10)
        counter:SetSize(612, 102)
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
        settingsPanel:Hide()
        footer:Hide()
        summaryPanel:Show()
        subtitle:SetText("Flight complete - your session totals")
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
        local minimapAngle = AzerobicsDB.minimapAngle
        if type(minimapAngle) ~= "number" or not (minimapAngle >= 0 and minimapAngle < 360) then
            AzerobicsDB.minimapAngle = 135
        end
        UpdateMinimapPosition()
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
        if type(AzerobicsDB.cycleWorkouts) ~= "boolean" then AzerobicsDB.cycleWorkouts = false end
        local volumes = { [0] = true, [25] = true, [50] = true, [75] = true, [100] = true }
        if not volumes[AzerobicsDB.cueVolume] then AzerobicsDB.cueVolume = 100 end
        soundButton:SetChecked(AzerobicsDB.soundCues)
        autoButton:SetChecked(AzerobicsDB.autoStart)
        cycleButton:SetChecked(AzerobicsDB.cycleWorkouts)
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
