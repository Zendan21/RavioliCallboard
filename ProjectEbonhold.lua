local addonName, Addon = ...
local PE = {}
Addon.PE = PE

PE.SUMMON_SPELL_ID = 600647
PE.SUMMON_SPELL_NAME = "Summon Callboard"
PE.CALLBOARD_NPC_NAMES = { "Callboard", "Objectives Board", "Objective Board" }

local nearbyScanAt = -1
local nearbyScanResult = false
local spellKnownScanAt = -1
local spellKnownResult = false
local boardAccessUntil = 0

local function timeNow()
    return GetTime and GetTime() or 0
end

local function callboardNameMatches(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    for i = 1, table.getn(PE.CALLBOARD_NPC_NAMES) do
        if name == PE.CALLBOARD_NPC_NAMES[i] then
            return true
        end
    end
    return false
end


local function gossipIsCallboard()
    if not GossipFrame or not GossipFrame.IsShown or not GossipFrame:IsShown() then
        return false
    end

    local name = UnitName and UnitName("npc") or nil
    if callboardNameMatches(name) then
        return true
    end

    if GossipFrameNpcNameText and GossipFrameNpcNameText.GetText then
        return callboardNameMatches(GossipFrameNpcNameText:GetText())
    end
    return false
end

function PE.MarkBoardAccess(duration)
    duration = tonumber(duration) or 30
    boardAccessUntil = math.max(boardAccessUntil or 0, timeNow() + duration)
end

function PE.ClearBoardAccess()
    boardAccessUntil = 0
end

function PE.HasBoardAccess()
    if PE.IsBoardVisible and PE.IsBoardVisible() then
        PE.MarkBoardAccess(30)
        return true
    end
    if gossipIsCallboard() then
        PE.MarkBoardAccess(30)
        return true
    end
    if (boardAccessUntil or 0) > timeNow() then
        local objectives = PE.GetObjectives and PE.GetObjectives() or nil
        return type(objectives) == "table" and table.getn(objectives) > 0
    end
    return false
end

local function targetIsNearbyCallboard()
    if not UnitExists or not UnitExists("target") then
        return false
    end
    if not callboardNameMatches(UnitName and UnitName("target") or nil) then
        return false
    end
    if CheckInteractDistance then
        return CheckInteractDistance("target", 3) and true or false
    end
    return true
end

function PE.IsCallboardNearby(forceScan)
    if targetIsNearbyCallboard() then
        nearbyScanAt = timeNow()
        nearbyScanResult = true
        return true
    end

    local currentTime = timeNow()
    if not forceScan and nearbyScanAt >= 0 and currentTime - nearbyScanAt < 0.25 then
        return nearbyScanResult
    end

    nearbyScanAt = currentTime
    nearbyScanResult = false
    for i = 1, table.getn(PE.CALLBOARD_NPC_NAMES) do
        if TargetByName then
            TargetByName(PE.CALLBOARD_NPC_NAMES[i], true)
        end
        if targetIsNearbyCallboard() then
            nearbyScanResult = true
            break
        end
    end
    return nearbyScanResult
end

function PE.TryInteractWithCallboard()
    if not PE.IsCallboardNearby(true) or not InteractUnit then
        return false
    end
    local ok = pcall(InteractUnit, "target")
    return ok == true
end

function PE.IsSummonSpellKnown(forceScan)
    local currentTime = timeNow()
    if not forceScan and spellKnownScanAt >= 0 and currentTime - spellKnownScanAt < 2 then
        return spellKnownResult
    end

    spellKnownScanAt = currentTime
    spellKnownResult = false

    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, PE.SUMMON_SPELL_ID)
        if ok and known then
            spellKnownResult = true
            return true
        end
    end

    if not GetNumSpellTabs or not GetSpellTabInfo then
        return false
    end

    local bookType = BOOKTYPE_SPELL or "spell"
    local tabCount = GetNumSpellTabs() or 0
    for tabIndex = 1, tabCount do
        local _, _, offset, spellCount = GetSpellTabInfo(tabIndex)
        offset = tonumber(offset) or 0
        spellCount = tonumber(spellCount) or 0
        for slot = offset + 1, offset + spellCount do
            local spellName
            if GetSpellBookItemName then
                local ok, name = pcall(GetSpellBookItemName, slot, bookType)
                if ok then
                    spellName = name
                end
            end
            if (not spellName or spellName == "") and GetSpellName then
                local ok, name = pcall(GetSpellName, slot, bookType)
                if ok then
                    spellName = name
                end
            end

            local spellID
            if GetSpellBookItemInfo then
                local ok, _, id = pcall(GetSpellBookItemInfo, slot, bookType)
                if ok then
                    spellID = tonumber(id)
                end
            end

            if spellName == PE.SUMMON_SPELL_NAME or spellID == PE.SUMMON_SPELL_ID then
                spellKnownResult = true
                return true
            end
        end
    end
    return false
end

local function resolvePath(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local current = _G
    for part in string.gmatch(path, "[^%.]+") do
        current = current and current[part]
    end
    return current
end

local function clickFrame(target)
    if not target or (target.IsShown and not target:IsShown()) then
        return false
    end

    local ok, clicked = pcall(function()
        if target.Click then
            target:Click()
            return true
        end
        if target.GetScript then
            local handler = target:GetScript("OnClick")
            if handler then
                handler(target, "LeftButton")
                return true
            end
        end
        return false
    end)
    return ok and clicked == true
end

local function isEffectivelyVisible(frame)
    if not frame then
        return false
    end

    if frame.IsVisible then
        return frame:IsVisible() and true or false
    end

    -- Older clients may not expose IsVisible consistently. In that case,
    -- require the frame and every parent in its chain to be shown.
    local current = frame
    local depth = 0
    while current and depth < 12 do
        if current.IsShown and not current:IsShown() then
            return false
        end
        current = current.GetParent and current:GetParent() or nil
        depth = depth + 1
    end
    return true
end

function PE.GetService()
    if ProjectEbonhold and ProjectEbonhold.ObjectivesService then
        return ProjectEbonhold.ObjectivesService
    end
    return nil
end

function PE.RequestObjectives()
    local service = PE.GetService()
    if service and service.RequestObjectives then
        service.RequestObjectives()
        return true
    end
    return false
end

function PE.GetObjectives()
    local service = PE.GetService()
    if service and service.GetCurrentObjectives then
        local objectives = service.GetCurrentObjectives()
        if type(objectives) == "table" then
            return objectives
        end
    end
    return {}
end

function PE.GetActiveObjective()
    local service = PE.GetService()
    if service and service.GetActiveObjective then
        local objective = service.GetActiveObjective()
        if type(objective) == "table" then
            return objective
        end
    end
    return nil
end

function PE.GetSummonCooldownRemaining()
    if not GetSpellCooldown then
        return 0
    end

    local function remainingFor(spell)
        local start, duration = GetSpellCooldown(spell)
        start = tonumber(start) or 0
        duration = tonumber(duration) or 0
        if start > 0 and duration > 1.5 then
            return math.max(0, start + duration - (GetTime and GetTime() or 0))
        end
        return 0
    end

    local remaining = remainingFor(PE.SUMMON_SPELL_ID)
    if remaining <= 0 then
        remaining = remainingFor(PE.SUMMON_SPELL_NAME)
    end
    return remaining
end

function PE.IsBoardVisible()
    local frame = _G.ObjectivesMainFrame
    if frame and isEffectivelyVisible(frame) then
        PE.MarkBoardAccess(30)
        return true
    end

    for i = 1, 3 do
        local objectiveFrame = _G["ObjectiveFrame" .. tostring(i)]
        if isEffectivelyVisible(objectiveFrame) then
            PE.MarkBoardAccess(30)
            return true
        end
    end

    if gossipIsCallboard() then
        PE.MarkBoardAccess(30)
        return true
    end
    return false
end

function PE.CanAffordReroll()
    local service = PE.GetService()
    if service and service.CanAffordReroll then
        return service.CanAffordReroll() ~= false
    end
    return true
end

function PE.GetRerollCost()
    local service = PE.GetService()
    if service and service.GetRerollCost then
        return tonumber(service.GetRerollCost()) or 0
    end
    return 0
end

function PE.ConfirmReroll()
    for i = 1, 4 do
        local popup = _G["StaticPopup" .. tostring(i)]
        if popup and popup.IsShown and popup:IsShown() and popup.which == "EBONHOLD_CONFIRM_REROLL" then
            return clickFrame(_G["StaticPopup" .. tostring(i) .. "Button1"])
        end
    end
    return false
end

function PE.RequestReroll()
    if not PE.HasBoardAccess() then
        return false, "board_closed"
    end

    if not PE.CanAffordReroll() then
        return false, "no_gold"
    end

    local service = PE.GetService()
    if service and service.RequestRerollObjectives then
        service.RequestRerollObjectives()
        PE.ConfirmReroll()
        return true
    end

    if clickFrame(resolvePath("ObjectivesMainFrame.rerollBtn")) then
        PE.ConfirmReroll()
        return true
    end
    return false, "unavailable"
end

function PE.SelectObjective(index)
    if not index then
        return false
    end

    if ProjectEbonhold and ProjectEbonhold.sendToServer and ProjectEbonhold.CS
        and ProjectEbonhold.CS.REQUEST_SELECT_OBJECTIVE then
        ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_SELECT_OBJECTIVE, tostring(index - 1))
        return true
    end

    local frame = _G["ObjectiveFrame" .. tostring(index)]
    if frame and clickFrame(frame.selectBtn) then
        return true
    end
    return clickFrame(frame)
end

function PE.CloseBoard()
    if ProjectEbonhold and ProjectEbonhold.ObjectivesUI and ProjectEbonhold.ObjectivesUI.HideObjectives then
        ProjectEbonhold.ObjectivesUI.HideObjectives()
        return
    end
    if _G.ObjectivesMainFrame and _G.ObjectivesMainFrame.Hide then
        _G.ObjectivesMainFrame:Hide()
    end
end
