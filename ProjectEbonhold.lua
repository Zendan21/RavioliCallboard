local addonName, Addon = ...
local PE = {}
Addon.PE = PE

PE.SUMMON_SPELL_ID = 600647
PE.SUMMON_SPELL_NAME = "Summon Callboard"

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
    if frame then
        return isEffectivelyVisible(frame)
    end

    for i = 1, 3 do
        local objectiveFrame = _G["ObjectiveFrame" .. tostring(i)]
        if isEffectivelyVisible(objectiveFrame) then
            return true
        end
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
    if not PE.IsBoardVisible() then
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
