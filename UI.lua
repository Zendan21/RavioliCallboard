local addonName, Addon = ...
local Core = Addon.Core

local UI = {
    routeRows = {},
    catalogRows = {},
    savedRouteRows = {},
    routeOffset = 0,
    catalogOffset = 0,
    savedRouteOffset = 0,
    selectedRouteIndex = nil,
    searchText = "",
}
Addon.UI = UI

local COLORS = {
    background = { 0.035, 0.043, 0.055, 0.98 },
    panel = { 0.065, 0.075, 0.095, 0.98 },
    panelLight = { 0.090, 0.102, 0.125, 1 },
    border = { 0.22, 0.25, 0.30, 1 },
    gold = { 0.86, 0.64, 0.25, 1 },
    text = { 0.92, 0.92, 0.92, 1 },
    muted = { 0.58, 0.62, 0.68, 1 },
    green = { 0.35, 0.78, 0.48, 1 },
    red = { 0.88, 0.32, 0.30, 1 },
    input = { 0.025, 0.030, 0.040, 1 },
    hover = { 0.14, 0.16, 0.20, 1 },
}

local COLOR_CODES = {
    gold = "|cffdba340",
    text = "|cffebebeb",
    muted = "|cff949ead",
    green = "|cff59c77a",
    red = "|cffe0524d",
}

local FONT = "Fonts\\FRIZQT__.TTF"

local function setTextStyle(label, size, color, justify)
    if not label then
        return label
    end
    if size and size >= 15 and GameFontNormalLarge then
        label:SetFontObject(GameFontNormalLarge)
    elseif size and size <= 11 and GameFontHighlightSmall then
        label:SetFontObject(GameFontHighlightSmall)
    elseif GameFontHighlight then
        label:SetFontObject(GameFontHighlight)
    end
    color = color or COLORS.text
    label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    label:SetJustifyH(justify or "LEFT")
    label:SetJustifyV("MIDDLE")
    return label
end

local function setBackdrop(frame, color, border)
    if not frame or not frame.SetBackdrop then
        return
    end
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(unpack(color or COLORS.panel))
    frame:SetBackdropBorderColor(unpack(border or COLORS.border))
end

local function refreshButtonStyle(button)
    local kind = button.styleKind or "normal"
    local border = COLORS.border
    local textColor = COLORS.text
    if kind == "primary" then
        border = COLORS.gold
    elseif kind == "success" then
        border = COLORS.green
    elseif kind == "danger" then
        border = COLORS.red
        textColor = COLORS.red
    end
    if button.label then
        button.label:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
    end
end

local function setButtonKind(button, kind)
    button.styleKind = kind or "normal"
    refreshButtonStyle(button)
end

local function styleButton(button, text, kind)
    button:SetText(text or "")
    button.label = button:GetFontString()
    if button.label then
        setTextStyle(button.label, 11, COLORS.text, "CENTER")
    end
    setButtonKind(button, kind)
    function button:SetButtonEnabled(enabled)
        if enabled then
            self:Enable()
            self:SetAlpha(1)
        else
            self:Disable()
            self:SetAlpha(0.48)
        end
        refreshButtonStyle(self)
    end
    return button
end

local function makeButton(parent, text, width, height, kind)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(height)
    return styleButton(button, text, kind)
end

local function makeInput(parent, name)
    local input = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    input:SetAutoFocus(false)
    if ChatFontNormal then
        input:SetFontObject(ChatFontNormal)
    end
    input:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    return input
end

local function makeCheckbox(parent, label)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetWidth(24)
    checkbox:SetHeight(24)
    checkbox.label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    checkbox.label:SetText(label)
    checkbox.label:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    return checkbox
end

local function makePanel(parent, title, width, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(width)
    panel:SetHeight(height)
    setBackdrop(panel, COLORS.panel)

    panel.title = panel:CreateFontString(nil, "OVERLAY")
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
    panel.title:SetText(title)
    setTextStyle(panel.title, 12, COLORS.gold, "LEFT")
    return panel
end

local function setRowState(row, background, border)
    row.baseBackground = background or COLORS.panel
    row.baseBorder = border or COLORS.border
    row:SetBackdropColor(unpack(row.baseBackground))
    row:SetBackdropBorderColor(unpack(row.baseBorder))
end

local function addRowHover(row)
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.hover))
        self:SetBackdropBorderColor(unpack(COLORS.gold))
    end)
    row:SetScript("OnLeave", function(self)
        setRowState(self, self.baseBackground, self.baseBorder)
    end)
end

local function statusColor(message)
    local lower = string.lower(tostring(message or ""))
    if string.find(lower, "stopped", 1, true)
        or string.find(lower, "could not", 1, true)
        or string.find(lower, "not enough", 1, true)
        or string.find(lower, "repeat-locked", 1, true)
        or string.find(lower, "unavailable", 1, true)
        or string.find(lower, "failed", 1, true)
    then
        return COLORS.red
    end
    if string.find(lower, "completed", 1, true)
        or string.find(lower, "route complete", 1, true)
        or string.find(lower, "accepted", 1, true)
        or string.find(lower, "saved", 1, true)
        or string.find(lower, "imported", 1, true)
        or string.find(lower, "added:", 1, true)
        or string.find(lower, "settings saved", 1, true)
    then
        return COLORS.green
    end
    if string.find(lower, "running", 1, true)
        or string.find(lower, "waiting", 1, true)
        or string.find(lower, "reroll", 1, true)
        or string.find(lower, "active step", 1, true)
    then
        return COLORS.gold
    end
    return COLORS.muted
end

local function clampOffset(offset, count, visible)
    return math.max(0, math.min(offset or 0, math.max(0, count - visible)))
end

local function createRouteRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(27)
    row:SetPoint("LEFT", parent, "LEFT", 8, 0)
    row:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    setBackdrop(row, COLORS.panel, COLORS.border)
    setRowState(row, COLORS.panel, COLORS.border)
    addRowHover(row)

    row.number = row:CreateFontString(nil, "OVERLAY")
    row.number:SetPoint("LEFT", row, "LEFT", 7, 0)
    row.number:SetWidth(32)
    row.number:SetJustifyH("RIGHT")
    setTextStyle(row.number, 11, COLORS.gold, "RIGHT")

    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetPoint("LEFT", row.number, "RIGHT", 8, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.label:SetJustifyH("LEFT")
    setTextStyle(row.label, 11, COLORS.text, "LEFT")

    row:SetScript("OnClick", function(self)
        UI.selectedRouteIndex = self.routeIndex
        UI:Refresh()
    end)
    return row
end

local function createCatalogRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(27)
    row:SetPoint("LEFT", parent, "LEFT", 8, 0)
    row:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    row:EnableMouse(true)
    setBackdrop(row, COLORS.panel, COLORS.border)
    setRowState(row, COLORS.panel, COLORS.border)
    addRowHover(row)

    row.add = makeButton(row, "+", 28, 21)
    row.add:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.add:SetScript("OnClick", function(self)
        if self.questKey then
            Addon:AddRouteQuest(self.questKey)
        end
    end)

    row.info = makeButton(row, "?", 26, 21)
    row.info:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.info:SetScript("OnClick", function(self)
        if self.questKey then
            UI:ToggleQuestDetails(self.questKey, row)
        end
    end)
    row.info:HookScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Show quest objective", 1, 0.82, 0)
            GameTooltip:Show()
        end
    end)
    row.info:HookScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetPoint("LEFT", row.add, "RIGHT", 7, 0)
    row.label:SetPoint("RIGHT", row.info, "LEFT", -5, 0)
    row.label:SetJustifyH("LEFT")
    setTextStyle(row.label, 11, COLORS.text, "LEFT")
    row:SetScript("OnMouseUp", function(self)
        if self.groupId then
            UI:ToggleCatalogGroup(self.groupId)
        end
    end)
    return row
end

function UI:HideQuestDetails()
    if self.detailPopup then
        self.detailPopup.questKey = nil
        self.detailPopup:Hide()
    end
end

function UI:ToggleQuestDetails(key, owner)
    if not self.detailPopup or not key then
        return
    end
    if self.detailPopup:IsShown() and self.detailPopup.questKey == key then
        self:HideQuestDetails()
        return
    end

    local quest = Addon.db and Addon.db.knownQuests[key]
    if not quest then
        return
    end

    local classification = Core.ClassifyCatalogZone(quest)
    local objective = tostring(quest.objectiveText or "")
    if objective == "" then
        objective = "No objective text has been learned yet. Open the Callboard when this quest is offered to refresh its details."
    end

    self.detailPopup.questKey = key
    self.detailPopup.title:SetText(Core.QuestTitle(quest))
    self.detailPopup.meta:SetText(classification.label
        .. (quest.questId and ("  " .. COLOR_CODES.muted .. "Quest #" .. tostring(quest.questId) .. "|r") or ""))
    self.detailPopup.objective:SetText(objective)
    self.detailPopup.add.questKey = key
    if Core.RouteContains(Addon.profile and Addon.profile.route, key) then
        self.detailPopup.add:SetText("Already Added")
        self.detailPopup.add:SetButtonEnabled(false)
    else
        self.detailPopup.add:SetText("Add to Route")
        self.detailPopup.add:SetButtonEnabled(true)
    end

    local textHeight = math.max(34, self.detailPopup.objective:GetStringHeight() or 34)
    self.detailPopup:SetHeight(math.min(170, 82 + textHeight))
    self.detailPopup:ClearAllPoints()
    self.detailPopup:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -2)
    self.detailPopup:Show()
    self.detailPopup:Raise()
end

function UI:ToggleCatalogGroup(groupId)
    if not Addon.profile or type(groupId) ~= "string" then
        return
    end
    self:HideQuestDetails()
    Addon.profile.catalogCollapsed = Addon.profile.catalogCollapsed or {}
    if Addon.profile.catalogCollapsed[groupId] then
        Addon.profile.catalogCollapsed[groupId] = nil
    else
        Addon.profile.catalogCollapsed[groupId] = true
    end
    self:Refresh()
end

function UI:SetAllCatalogGroupsCollapsed(collapsed)
    if not Addon.profile then
        return
    end
    self:HideQuestDetails()
    Addon.profile.catalogCollapsed = {}
    if collapsed then
        local ids = Core.CatalogGroupIDs(Addon.db, self.searchText)
        for i = 1, table.getn(ids) do
            Addon.profile.catalogCollapsed[ids[i]] = true
        end
    end
    self.catalogOffset = 0
    self:Refresh()
end

function UI:SavePosition()
    if not self.frame or not Addon.profile then
        return
    end
    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    Addon.profile.window.point = point or "CENTER"
    Addon.profile.window.relativePoint = relativePoint or point or "CENTER"
    Addon.profile.window.x = x or 0
    Addon.profile.window.y = y or 0
end

function UI:UpdateSummonCooldown()
    if (not self.summon and not self.miniSummon) or not Addon.PE or not Addon.PE.GetSummonCooldownRemaining then
        return
    end
    local remaining = Addon.PE.GetSummonCooldownRemaining()
    local seconds = remaining > 0 and math.max(1, math.ceil(remaining)) or 0
    if self.lastSummonCooldownSecond == seconds then
        return
    end
    self.lastSummonCooldownSecond = seconds
    local label = seconds > 0 and ("Callboard " .. tostring(seconds) .. "s") or "Summon Board"
    if self.summon then
        self.summon:SetText(label)
    end
    if self.miniSummon then
        self.miniSummon:SetText(label)
    end
end

function UI:UpdateStartAction()
    if not self.start or not Addon.PE or not Addon.PE.IsBoardVisible then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    local shouldCast = not Addon.PE.IsBoardVisible()
    if self.startActionCasts == shouldCast then
        return
    end
    self.startActionCasts = shouldCast
    self.start:SetAttribute("macrotext", shouldCast and "/cast Summon Callboard" or "")
end

function UI:SaveMiniLayout()
    if not self.miniFrame or not Addon.profile then
        return
    end
    local point, _, relativePoint, x, y = self.miniFrame:GetPoint(1)
    Addon.profile.miniWindow.point = point or "CENTER"
    Addon.profile.miniWindow.relativePoint = relativePoint or point or "CENTER"
    Addon.profile.miniWindow.x = x or 0
    Addon.profile.miniWindow.y = y or 0
    Addon.profile.miniWindow.width = self.miniFrame:GetWidth()
    Addon.profile.miniWindow.height = self.miniFrame:GetHeight()
end

function UI:RefreshMini()
    if not self.miniFrame or not Addon.profile or not Addon.db then
        return
    end
    local route = Addon.profile.route or {}
    local currentIndex = Addon.profile.currentStep or 1
    local routeCount = table.getn(route)
    local wantedCount = math.max(1, math.min(20, Addon.profile.miniQuestCount or 5))
    local shownCount = math.min(wantedCount, routeCount)
    local lines = {}

    if currentIndex > routeCount or routeCount == 0 then
        table.insert(lines, COLOR_CODES.muted .. "Route complete|r")
        shownCount = 1
    else
        for offset = 0, shownCount - 1 do
            local routeIndex = currentIndex + offset
            if routeIndex > routeCount then
                if Addon.profile.autoLoop then
                    routeIndex = routeIndex - routeCount
                else
                    break
                end
            end

            local key = route[routeIndex]
            local quest = key and Addon.db.knownQuests[key]
            local title = quest and Core.QuestTitle(quest) or tostring(key or "Unknown quest")
            if offset == 0 then
                table.insert(lines, COLOR_CODES.gold .. "> " .. tostring(routeIndex) .. ". " .. title .. "|r")
            else
                table.insert(lines, "  " .. tostring(routeIndex) .. ". " .. COLOR_CODES.text .. title .. "|r")
            end
        end
        shownCount = table.getn(lines)
    end

    self.miniFrame.title:SetText(Addon.profile.activeRouteName
        and ("RavioliCallboard — " .. Addon.profile.activeRouteName)
        or "RavioliCallboard Route")
    self.miniCurrent:SetText(table.concat(lines, "\n"))
    self.miniStatus:SetText(Addon.statusMessage or "")
    local miniStatusColor = statusColor(Addon.statusMessage)
    self.miniStatus:SetTextColor(unpack(miniStatusColor))

    local minimumHeight = 134 + (shownCount * 16)
    if self.miniFrame.SetMinResize then
        self.miniFrame:SetMinResize(360, math.max(165, minimumHeight))
    end
    if self.miniFrame:GetWidth() < 360 then
        self.miniFrame:SetWidth(360)
    end
    if self.miniFrame:GetHeight() < minimumHeight then
        self.miniFrame:SetHeight(minimumHeight)
        self:SaveMiniLayout()
    end
    self:UpdateSummonCooldown()
    self:RefreshGroupProgress()
end

function UI:RefreshGroupProgress()
    if not self.miniGroup or not self.groupProgressFrame or not Addon.profile then
        return
    end
    if Addon.profile.showGroupProgress ~= true then
        self.miniGroup:SetText("Group Off")
        self.groupProgressFrame.subtitle:SetText("Live group progress is disabled in Settings.")
        self.groupProgressText:SetText("")
        return
    end

    local group = Addon.Group
    local display = group and group.GetDisplay and group:GetDisplay() or nil
    if not display then
        self.miniGroup:SetText("Group")
        return
    end

    if display.grouped then
        self.miniGroup:SetText("Group " .. tostring(display.completeCount) .. "/" .. tostring(display.memberCount))
    else
        self.miniGroup:SetText("Group")
    end
    self.groupProgressFrame.subtitle:SetText(display.title)

    local lines = {}
    if not display.grouped then
        table.insert(lines, COLOR_CODES.muted .. "You are not currently in a group.|r")
    else
        for index = 1, table.getn(display.rows or {}) do
            local row = display.rows[index]
            local color = COLOR_CODES.text
            if row.color == "complete" then
                color = COLOR_CODES.green
            elseif row.color == "missing" then
                color = COLOR_CODES.gold
            elseif row.color == "unknown" then
                color = COLOR_CODES.muted
            end
            table.insert(lines, color .. tostring(row.name) .. "|r  —  " .. tostring(row.status))
        end
        if display.addonCount < display.memberCount then
            table.insert(lines, "")
            table.insert(lines, COLOR_CODES.muted .. "No addon data means that player has not responded from RavioliCallboard.|r")
        end
    end

    self.groupProgressText:SetText(table.concat(lines, "\n"))
    local contentHeight = math.max(250, (table.getn(lines) * 18) + 12)
    self.groupProgressChild:SetHeight(contentHeight)
end

function UI:ToggleGroupProgress()
    if not self.groupProgressFrame then
        return
    end
    if self.groupProgressFrame:IsShown() then
        self.groupProgressFrame:Hide()
    else
        self:RefreshGroupProgress()
        self.groupProgressFrame:Show()
        self.groupProgressFrame:Raise()
    end
end

function UI:ShowMini()
    if not self.miniFrame then
        return
    end
    self.frame:Hide()
    self.miniFrame:Show()
    self:RefreshMini()
end

function UI:ShowMain()
    if self.miniFrame then
        self.miniFrame:Hide()
    end
    self.frame:Show()
    self:Refresh()
end

function UI:RefreshSettings()
    if not self.settingsFrame or not Addon.profile then
        return
    end
    self.settingsAutoLoop:SetChecked(Addon.profile.autoLoop == true)
    self.settingsAutoAccept:SetChecked(Addon.profile.autoAccept == true)
    self.settingsAutoShare:SetChecked(Addon.profile.autoShare == true)
    self.settingsGroupProgress:SetChecked(Addon.profile.showGroupProgress == true)
    self.settingsMaxRerolls:SetText(tostring(Addon.profile.maxRerolls or 50))
    self.settingsRerollDelay:SetText(tostring(Addon.profile.rerollDelay or 1.6))
    self.settingsMiniQuestCount:SetText(tostring(Addon.profile.miniQuestCount or 5))
end

function UI:ToggleSettings()
    if not self.settingsFrame then
        return
    end
    self:HideQuestDetails()
    if self.routeManager and self.routeManager:IsShown() then
        self.routeManager:Hide()
    end
    if self.settingsFrame:IsShown() then
        self.settingsFrame:Hide()
    else
        self:RefreshSettings()
        self.settingsFrame:Show()
        self.settingsFrame:Raise()
    end
end

local function sortedSavedRouteNames()
    local names = {}
    local savedRoutes = Addon.profile and Addon.profile.savedRoutes or {}
    for name in pairs(savedRoutes) do
        table.insert(names, name)
    end
    table.sort(names, function(left, right)
        return string.lower(left) < string.lower(right)
    end)
    return names
end

function UI:UpdateRouteSaveButton()
    if not self.routeManagerSave or not self.routeManagerName then
        return
    end
    local name = self.routeManagerName:GetText() or ""
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    local exists = Addon.profile and Addon.profile.savedRoutes and Addon.profile.savedRoutes[name]
    self.routeManagerSave:SetText(exists and "Overwrite" or "Save Current")
end

function UI:RefreshRouteManager()
    if not self.routeManager or not Addon.profile then
        return
    end
    local names = sortedSavedRouteNames()
    self.savedRouteOffset = clampOffset(self.savedRouteOffset, table.getn(names), 8)
    if self.routeManagerEmpty then
        if table.getn(names) == 0 then
            self.routeManagerEmpty:Show()
        else
            self.routeManagerEmpty:Hide()
        end
    end

    for visibleIndex = 1, 8 do
        local row = self.savedRouteRows[visibleIndex]
        local name = names[self.savedRouteOffset + visibleIndex]
        if name then
            local saved = Addon.profile.savedRoutes[name]
            local activePrefix = Addon.profile.activeRouteName == name and (COLOR_CODES.green .. "*|r ") or ""
            local loopSuffix = saved.autoLoop and ("  " .. COLOR_CODES.gold .. "[Loop]|r") or ""
            row.load.routeName = name
            row.share.routeName = name
            row.delete.routeName = name
            row.load:SetText(activePrefix .. name .. loopSuffix)
            row.delete:SetText(self.pendingDeleteName == name and "Confirm" or "Delete")
            row:Show()
        else
            row.load.routeName = nil
            row.share.routeName = nil
            row.delete.routeName = nil
            row:Hide()
        end
    end
    self.routeManagerPage:SetText(tostring(table.getn(names)) .. " saved route(s)")
    self:UpdateRouteSaveButton()
end

function UI:ToggleRouteManager()
    if not self.routeManager then
        return
    end
    self:HideQuestDetails()
    if self.settingsFrame and self.settingsFrame:IsShown() then
        self.settingsFrame:Hide()
    end
    if self.routeManager:IsShown() then
        self.routeManager:Hide()
    else
        self.pendingDeleteName = nil
        self.routeManagerName:SetText(Addon.profile.activeRouteName or "")
        self:RefreshRouteManager()
        self.routeManager:Show()
        self.routeManager:Raise()
    end
end

function UI:CaptureShiftClickedPlayer(link)
    if not self.routeManagerShareTarget or not IsShiftKeyDown or not IsShiftKeyDown() then
        return
    end
    local linkType, playerName = string.match(tostring(link or ""), "^([^:]+):([^:]+)")
    if linkType ~= "player" or not playerName or playerName == "" then
        return
    end
    self.routeManagerShareTarget:SetText(playerName)
    self.routeManagerShareTarget:HighlightText(0, 0)
end

function UI:InstallChatNameHook()
    if self.chatNameHooked or not hooksecurefunc or type(SetItemRef) ~= "function" then
        return
    end
    self.chatNameHooked = true
    hooksecurefunc("SetItemRef", function(link)
        UI:CaptureShiftClickedPlayer(link)
    end)
end

function UI:Create()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "RavioliCallboardFrame", UIParent)
    frame:SetWidth(900)
    frame:SetHeight(590)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    setBackdrop(frame, COLORS.background)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI:SavePosition()
    end)
    frame:SetScript("OnShow", function()
        UI:Refresh()
    end)
    frame:SetScript("OnHide", function()
        UI:HideQuestDetails()
        if UI.settingsFrame then
            UI.settingsFrame:Hide()
        end
        if UI.routeManager then
            UI.routeManager:Hide()
        end
    end)
    frame:Hide()
    self.frame = frame

    local window = Addon.profile and Addon.profile.window or {}
    frame:SetPoint(window.point or "CENTER", UIParent, window.relativePoint or "CENTER", window.x or 0, window.y or 0)

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
    frame.title:SetText("RavioliCallboard")
    setTextStyle(frame.title, 16, COLORS.gold, "LEFT")

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY")
    frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 12, 0)
    frame.subtitle:SetText("Ordered Callboard route builder")
    setTextStyle(frame.subtitle, 11, COLORS.muted, "LEFT")

    frame.close = makeButton(frame, "X", 28, 24)
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -10)
    frame.close:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.settingsButton = makeButton(frame, "Settings", 72, 24)
    frame.settingsButton:SetPoint("RIGHT", frame.close, "LEFT", -6, 0)
    frame.settingsButton:SetScript("OnClick", function()
        UI:ToggleSettings()
    end)

    frame.routesButton = makeButton(frame, "Routes", 66, 24)
    frame.routesButton:SetPoint("RIGHT", frame.settingsButton, "LEFT", -6, 0)
    frame.routesButton:SetScript("OnClick", function()
        UI:ToggleRouteManager()
    end)

    self.routePanel = makePanel(frame, "Quest route", 426, 430)
    self.routePanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -52)
    self.routePanel:EnableMouseWheel(true)
    self.routePanel:SetScript("OnMouseWheel", function(_, delta)
        local count = Addon.profile and table.getn(Addon.profile.route) or 0
        UI.routeOffset = clampOffset(UI.routeOffset - delta, count, 13)
        UI:Refresh()
    end)

    self.catalogPanel = makePanel(frame, "Learned Callboard quests", 426, 430)
    self.catalogPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -52)
    self.catalogPanel:EnableMouseWheel(true)
    self.catalogPanel:SetScript("OnMouseWheel", function(_, delta)
        local count = table.getn(UI.catalog or {})
        UI.catalogOffset = clampOffset(UI.catalogOffset - delta, count, 12)
        UI:Refresh()
    end)

    self.search = makeInput(self.catalogPanel, "RavioliCallboardSearchBox")
    self.search:SetHeight(24)
    self.search:SetPoint("TOPLEFT", self.catalogPanel, "TOPLEFT", 14, -31)
    self.search:SetPoint("TOPRIGHT", self.catalogPanel, "TOPRIGHT", -14, -31)
    self.search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    self.search:SetScript("OnTextChanged", function(self)
        UI:HideQuestDetails()
        UI.searchText = self:GetText() or ""
        if UI.searchHint then
            if UI.searchText == "" then
                UI.searchHint:Show()
            else
                UI.searchHint:Hide()
            end
        end
        UI.catalogOffset = 0
        UI:Refresh()
    end)

    self.searchHint = self.catalogPanel:CreateFontString(nil, "OVERLAY")
    self.searchHint:SetPoint("LEFT", self.search, "LEFT", 9, 0)
    self.searchHint:SetText("Search quests...")
    setTextStyle(self.searchHint, 11, COLORS.muted, "LEFT")

    for i = 1, 13 do
        local row = createRouteRow(self.routePanel, i)
        row:SetPoint("TOP", self.routePanel, "TOP", 0, -32 - ((i - 1) * 29))
        self.routeRows[i] = row
    end

    for i = 1, 12 do
        local row = createCatalogRow(self.catalogPanel, i)
        row:SetPoint("TOP", self.catalogPanel, "TOP", 0, -63 - ((i - 1) * 29))
        self.catalogRows[i] = row
    end

    self.routeEmpty = self.routePanel:CreateFontString(nil, "OVERLAY")
    self.routeEmpty:SetPoint("CENTER", self.routePanel, "CENTER", 0, 0)
    self.routeEmpty:SetWidth(350)
    self.routeEmpty:SetText("No route steps yet. Add quests from the catalogue to begin.")
    setTextStyle(self.routeEmpty, 12, COLORS.muted, "CENTER")

    self.catalogEmpty = self.catalogPanel:CreateFontString(nil, "OVERLAY")
    self.catalogEmpty:SetPoint("CENTER", self.catalogPanel, "CENTER", 0, 0)
    self.catalogEmpty:SetWidth(350)
    setTextStyle(self.catalogEmpty, 12, COLORS.muted, "CENTER")

    self.detailPopup = CreateFrame("Frame", "RavioliCallboardQuestDetailPopup", frame)
    self.detailPopup:SetWidth(390)
    self.detailPopup:SetHeight(125)
    self.detailPopup:SetFrameStrata("TOOLTIP")
    self.detailPopup:SetClampedToScreen(true)
    setBackdrop(self.detailPopup, COLORS.background, COLORS.gold)
    self.detailPopup:EnableMouse(true)

    self.detailPopup.title = self.detailPopup:CreateFontString(nil, "OVERLAY")
    self.detailPopup.title:SetPoint("TOPLEFT", self.detailPopup, "TOPLEFT", 12, -10)
    self.detailPopup.title:SetPoint("RIGHT", self.detailPopup, "RIGHT", -38, 0)
    self.detailPopup.title:SetJustifyH("LEFT")
    setTextStyle(self.detailPopup.title, 13, COLORS.gold, "LEFT")

    self.detailPopup.meta = self.detailPopup:CreateFontString(nil, "OVERLAY")
    self.detailPopup.meta:SetPoint("TOPLEFT", self.detailPopup.title, "BOTTOMLEFT", 0, -5)
    self.detailPopup.meta:SetPoint("RIGHT", self.detailPopup, "RIGHT", -12, 0)
    self.detailPopup.meta:SetJustifyH("LEFT")
    setTextStyle(self.detailPopup.meta, 11, COLORS.muted, "LEFT")

    self.detailPopup.objective = self.detailPopup:CreateFontString(nil, "OVERLAY")
    self.detailPopup.objective:SetPoint("TOPLEFT", self.detailPopup.meta, "BOTTOMLEFT", 0, -8)
    self.detailPopup.objective:SetPoint("RIGHT", self.detailPopup, "RIGHT", -12, 0)
    self.detailPopup.objective:SetJustifyH("LEFT")
    self.detailPopup.objective:SetJustifyV("TOP")
    setTextStyle(self.detailPopup.objective, 11, COLORS.text, "LEFT")
    self.detailPopup.objective:SetJustifyV("TOP")

    self.detailPopup.close = makeButton(self.detailPopup, "X", 24, 21)
    self.detailPopup.close:SetPoint("TOPRIGHT", self.detailPopup, "TOPRIGHT", -6, -6)
    self.detailPopup.close:SetScript("OnClick", function()
        UI:HideQuestDetails()
    end)

    self.detailPopup.add = makeButton(self.detailPopup, "Add to Route", 94, 23, "primary")
    self.detailPopup.add:SetPoint("BOTTOMRIGHT", self.detailPopup, "BOTTOMRIGHT", -9, 8)
    self.detailPopup.add:SetScript("OnClick", function(self)
        if self.questKey then
            Addon:AddRouteQuest(self.questKey)
            UI:HideQuestDetails()
        end
    end)
    self.detailPopup:Hide()

    self.settingsFrame = CreateFrame("Frame", "RavioliCallboardSettingsFrame", frame)
    self.settingsFrame:SetWidth(480)
    self.settingsFrame:SetHeight(440)
    self.settingsFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
    self.settingsFrame:SetFrameStrata("TOOLTIP")
    self.settingsFrame:SetClampedToScreen(true)
    setBackdrop(self.settingsFrame, COLORS.background, COLORS.gold)
    self.settingsFrame:EnableMouse(true)

    self.settingsFrame.title = self.settingsFrame:CreateFontString(nil, "OVERLAY")
    self.settingsFrame.title:SetPoint("TOPLEFT", self.settingsFrame, "TOPLEFT", 16, -15)
    self.settingsFrame.title:SetText("RavioliCallboard Settings")
    setTextStyle(self.settingsFrame.title, 16, COLORS.gold, "LEFT")

    self.settingsFrame.close = makeButton(self.settingsFrame, "X", 26, 22)
    self.settingsFrame.close:SetPoint("TOPRIGHT", self.settingsFrame, "TOPRIGHT", -9, -9)
    self.settingsFrame.close:SetScript("OnClick", function()
        UI.settingsFrame:Hide()
    end)

    self.settingsAutoLoop = makeCheckbox(self.settingsFrame, "Automatically loop to step 1 when the route finishes")
    self.settingsAutoLoop:SetPoint("TOPLEFT", self.settingsFrame, "TOPLEFT", 18, -57)
    self.settingsAutoLoop.label:SetWidth(410)
    self.settingsAutoLoop.label:SetJustifyH("LEFT")

    self.settingsAutoAccept = makeCheckbox(self.settingsFrame, "Auto-accept only the exact current route quest")
    self.settingsAutoAccept:SetPoint("TOPLEFT", self.settingsAutoLoop, "BOTTOMLEFT", 0, -14)
    self.settingsAutoAccept.label:SetWidth(410)
    self.settingsAutoAccept.label:SetJustifyH("LEFT")

    self.settingsAutoShare = makeCheckbox(self.settingsFrame, "Automatically share each accepted route quest with the group")
    self.settingsAutoShare:SetPoint("TOPLEFT", self.settingsAutoAccept, "BOTTOMLEFT", 0, -10)
    self.settingsAutoShare.label:SetWidth(410)
    self.settingsAutoShare.label:SetJustifyH("LEFT")

    self.settingsGroupProgress = makeCheckbox(self.settingsFrame, "Exchange live quest progress with other RavioliCallboard users")
    self.settingsGroupProgress:SetPoint("TOPLEFT", self.settingsAutoShare, "BOTTOMLEFT", 0, -10)
    self.settingsGroupProgress.label:SetWidth(410)
    self.settingsGroupProgress.label:SetJustifyH("LEFT")

    self.settingsMaxLabel = self.settingsFrame:CreateFontString(nil, "OVERLAY")
    self.settingsMaxLabel:SetPoint("TOPLEFT", self.settingsGroupProgress, "BOTTOMLEFT", 2, -24)
    self.settingsMaxLabel:SetWidth(320)
    self.settingsMaxLabel:SetJustifyH("LEFT")
    self.settingsMaxLabel:SetText("Maximum rerolls per route step")
    setTextStyle(self.settingsMaxLabel, 12, COLORS.text, "LEFT")

    self.settingsMaxRerolls = makeInput(self.settingsFrame)
    self.settingsMaxRerolls:SetWidth(70)
    self.settingsMaxRerolls:SetHeight(24)
    self.settingsMaxRerolls:SetAutoFocus(false)
    self.settingsMaxRerolls:SetNumeric(true)
    self.settingsMaxRerolls:SetPoint("LEFT", self.settingsMaxLabel, "RIGHT", 14, 0)

    self.settingsDelayLabel = self.settingsFrame:CreateFontString(nil, "OVERLAY")
    self.settingsDelayLabel:SetPoint("TOPLEFT", self.settingsMaxLabel, "BOTTOMLEFT", 0, -26)
    self.settingsDelayLabel:SetWidth(320)
    self.settingsDelayLabel:SetJustifyH("LEFT")
    self.settingsDelayLabel:SetText("Reroll response delay (seconds)")
    setTextStyle(self.settingsDelayLabel, 12, COLORS.text, "LEFT")

    self.settingsRerollDelay = makeInput(self.settingsFrame)
    self.settingsRerollDelay:SetWidth(70)
    self.settingsRerollDelay:SetHeight(24)
    self.settingsRerollDelay:SetAutoFocus(false)
    self.settingsRerollDelay:SetPoint("LEFT", self.settingsDelayLabel, "RIGHT", 14, 0)

    self.settingsMiniCountLabel = self.settingsFrame:CreateFontString(nil, "OVERLAY")
    self.settingsMiniCountLabel:SetPoint("TOPLEFT", self.settingsDelayLabel, "BOTTOMLEFT", 0, -26)
    self.settingsMiniCountLabel:SetWidth(320)
    self.settingsMiniCountLabel:SetJustifyH("LEFT")
    self.settingsMiniCountLabel:SetText("Quests shown in mini window (1-20)")
    setTextStyle(self.settingsMiniCountLabel, 12, COLORS.text, "LEFT")

    self.settingsMiniQuestCount = makeInput(self.settingsFrame)
    self.settingsMiniQuestCount:SetWidth(70)
    self.settingsMiniQuestCount:SetHeight(24)
    self.settingsMiniQuestCount:SetAutoFocus(false)
    self.settingsMiniQuestCount:SetNumeric(true)
    self.settingsMiniQuestCount:SetPoint("LEFT", self.settingsMiniCountLabel, "RIGHT", 14, 0)

    self.settingsFrame.note = self.settingsFrame:CreateFontString(nil, "OVERLAY")
    self.settingsFrame.note:SetPoint("TOPLEFT", self.settingsMiniCountLabel, "BOTTOMLEFT", 0, -27)
    self.settingsFrame.note:SetWidth(440)
    self.settingsFrame.note:SetHeight(72)
    self.settingsFrame.note:SetJustifyH("LEFT")
    self.settingsFrame.note:SetJustifyV("TOP")
    if self.settingsFrame.note.SetWordWrap then
        self.settingsFrame.note:SetWordWrap(true)
    end
    self.settingsFrame.note:SetText("Group progress requires RavioliCallboard on each player. Without it, they show as No addon data. Looping is saved per route and requires at least four different quests because the Callboard locks a quest for the next three completions.")
    setTextStyle(self.settingsFrame.note, 11, COLORS.muted, "LEFT")
    self.settingsFrame.note:SetJustifyV("TOP")

    self.settingsFrame.save = makeButton(self.settingsFrame, "Save Settings", 112, 27, "primary")
    self.settingsFrame.save:SetPoint("BOTTOMRIGHT", self.settingsFrame, "BOTTOMRIGHT", -14, 12)
    self.settingsFrame.save:SetScript("OnClick", function()
        Addon:ApplySettings(
            UI.settingsAutoLoop:GetChecked(),
            UI.settingsAutoAccept:GetChecked(),
            UI.settingsMaxRerolls:GetText(),
            UI.settingsRerollDelay:GetText(),
            UI.settingsMiniQuestCount:GetText(),
            UI.settingsAutoShare:GetChecked(),
            UI.settingsGroupProgress:GetChecked()
        )
    end)
    self.settingsFrame:Hide()

    self.routeManager = CreateFrame("Frame", "RavioliCallboardRouteManager", frame)
    self.routeManager:SetWidth(460)
    self.routeManager:SetHeight(465)
    self.routeManager:SetPoint("CENTER", frame, "CENTER", 0, 0)
    self.routeManager:SetFrameStrata("TOOLTIP")
    setBackdrop(self.routeManager, COLORS.background, COLORS.gold)
    self.routeManager:EnableMouse(true)
    self.routeManager:EnableMouseWheel(true)
    self.routeManager:SetScript("OnMouseWheel", function(_, delta)
        local count = table.getn(sortedSavedRouteNames())
        UI.savedRouteOffset = clampOffset(UI.savedRouteOffset - delta, count, 8)
        UI:RefreshRouteManager()
    end)

    self.routeManager.title = self.routeManager:CreateFontString(nil, "OVERLAY")
    self.routeManager.title:SetPoint("TOPLEFT", self.routeManager, "TOPLEFT", 16, -15)
    self.routeManager.title:SetText("Saved Routes")
    setTextStyle(self.routeManager.title, 16, COLORS.gold, "LEFT")

    self.routeManager.close = makeButton(self.routeManager, "X", 26, 22)
    self.routeManager.close:SetPoint("TOPRIGHT", self.routeManager, "TOPRIGHT", -9, -9)
    self.routeManager.close:SetScript("OnClick", function()
        UI.routeManager:Hide()
    end)

    self.routeManager.nameLabel = self.routeManager:CreateFontString(nil, "OVERLAY")
    self.routeManager.nameLabel:SetPoint("TOPLEFT", self.routeManager, "TOPLEFT", 16, -50)
    self.routeManager.nameLabel:SetText("Route name")
    setTextStyle(self.routeManager.nameLabel, 11, COLORS.muted, "LEFT")

    self.routeManagerName = makeInput(self.routeManager)
    self.routeManagerName:SetHeight(24)
    self.routeManagerName:SetPoint("TOPLEFT", self.routeManager, "TOPLEFT", 16, -66)
    self.routeManagerName:SetPoint("TOPRIGHT", self.routeManager, "TOPRIGHT", -132, -66)
    self.routeManagerName:SetScript("OnTextChanged", function()
        UI:UpdateRouteSaveButton()
    end)
    self.routeManagerName:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    self.routeManagerName:SetScript("OnEnterPressed", function(self)
        Addon:SaveCurrentRoute(self:GetText())
        self:ClearFocus()
    end)

    self.routeManagerSave = makeButton(self.routeManager, "Save Current", 106, 25, "primary")
    self.routeManagerSave:SetPoint("TOPRIGHT", self.routeManager, "TOPRIGHT", -14, -65)
    self.routeManagerSave:SetScript("OnClick", function()
        Addon:SaveCurrentRoute(UI.routeManagerName:GetText())
    end)

    for i = 1, 8 do
        local row = CreateFrame("Frame", nil, self.routeManager)
        row:SetHeight(29)
        row:SetPoint("TOPLEFT", self.routeManager, "TOPLEFT", 14, -105 - ((i - 1) * 31))
        row:SetPoint("RIGHT", self.routeManager, "RIGHT", -14, 0)
        setBackdrop(row, COLORS.panel, COLORS.border)

        row.load = makeButton(row, "", 258, 23)
        row.load:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.load:SetScript("OnClick", function(self)
            if self.routeName then
                UI.pendingDeleteName = nil
                Addon:LoadSavedRoute(self.routeName)
                UI.routeManagerName:SetText(self.routeName)
                UI:RefreshRouteManager()
            end
        end)

        row.share = makeButton(row, "Share", 82, 23)
        row.share:SetPoint("RIGHT", row, "RIGHT", -82, 0)
        row.share:SetScript("OnClick", function(self)
            if self.routeName then
                Addon:ShareSavedRoute(self.routeName, UI.routeManagerShareTarget:GetText())
                UI.routeManagerShareTarget:ClearFocus()
            end
        end)

        row.delete = makeButton(row, "Delete", 72, 23, "danger")
        row.delete:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.delete:SetScript("OnClick", function(self)
            if not self.routeName then
                return
            end
            if UI.pendingDeleteName == self.routeName then
                local name = self.routeName
                UI.pendingDeleteName = nil
                Addon:DeleteSavedRoute(name)
            else
                UI.pendingDeleteName = self.routeName
                UI:RefreshRouteManager()
            end
        end)

        self.savedRouteRows[i] = row
    end


    self.routeManagerEmpty = self.routeManager:CreateFontString(nil, "OVERLAY")
    self.routeManagerEmpty:SetPoint("CENTER", self.routeManager, "CENTER", 0, -12)
    self.routeManagerEmpty:SetWidth(380)
    self.routeManagerEmpty:SetText("No saved routes yet. Name the current route and save it above.")
    setTextStyle(self.routeManagerEmpty, 12, COLORS.muted, "CENTER")

    self.routeManager.shareLabel = self.routeManager:CreateFontString(nil, "OVERLAY")
    self.routeManager.shareLabel:SetPoint("BOTTOMLEFT", self.routeManager, "BOTTOMLEFT", 16, 51)
    self.routeManager.shareLabel:SetText("Recipient for Share buttons (addon required)")
    setTextStyle(self.routeManager.shareLabel, 11, COLORS.muted, "LEFT")

    self.routeManagerShareTarget = makeInput(self.routeManager)
    self.routeManagerShareTarget:SetHeight(24)
    self.routeManagerShareTarget:SetPoint("BOTTOMLEFT", self.routeManager, "BOTTOMLEFT", 16, 17)
    self.routeManagerShareTarget:SetPoint("BOTTOMRIGHT", self.routeManager, "BOTTOMRIGHT", -130, 17)
    if self.routeManagerShareTarget.SetMaxLetters then
        self.routeManagerShareTarget:SetMaxLetters(48)
    end
    self.routeManagerShareTarget:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    self.routeManagerShareTarget:SetScript("OnEnterPressed", function(self)
        Addon:ShareCurrentRoute(self:GetText(), UI.routeManagerName:GetText())
        self:ClearFocus()
    end)

    self.routeManagerShare = makeButton(self.routeManager, "Share Current", 108, 25, "primary")
    self.routeManagerShare:SetPoint("BOTTOMRIGHT", self.routeManager, "BOTTOMRIGHT", -14, 17)
    self.routeManagerShare:SetScript("OnClick", function()
        Addon:ShareCurrentRoute(UI.routeManagerShareTarget:GetText(), UI.routeManagerName:GetText())
        UI.routeManagerShareTarget:ClearFocus()
    end)

    self.routeManagerPage = self.routeManager:CreateFontString(nil, "OVERLAY")
    self.routeManagerPage:SetPoint("BOTTOMLEFT", self.routeManager, "BOTTOMLEFT", 16, 85)
    setTextStyle(self.routeManagerPage, 11, COLORS.muted, "LEFT")
    self.routeManager:Hide()
    self:InstallChatNameHook()

    self.routePage = self.routePanel:CreateFontString(nil, "OVERLAY")
    self.routePage:SetPoint("BOTTOMLEFT", self.routePanel, "BOTTOMLEFT", 12, 10)

    setTextStyle(self.routePage, 11, COLORS.muted, "LEFT")

    self.catalogPage = self.catalogPanel:CreateFontString(nil, "OVERLAY")
    self.catalogPage:SetPoint("BOTTOMLEFT", self.catalogPanel, "BOTTOMLEFT", 12, 10)
    setTextStyle(self.catalogPage, 11, COLORS.muted, "LEFT")

    self.up = makeButton(frame, "Up", 62, 25)
    self.up:SetPoint("TOPLEFT", self.routePanel, "BOTTOMLEFT", 0, -8)
    self.up:SetScript("OnClick", function()
        if UI.selectedRouteIndex then
            Addon:MoveRouteStep(UI.selectedRouteIndex, UI.selectedRouteIndex - 1)
            UI.selectedRouteIndex = math.max(1, UI.selectedRouteIndex - 1)
        end
    end)

    self.down = makeButton(frame, "Down", 62, 25)
    self.down:SetPoint("LEFT", self.up, "RIGHT", 5, 0)
    self.down:SetScript("OnClick", function()
        if UI.selectedRouteIndex then
            Addon:MoveRouteStep(UI.selectedRouteIndex, UI.selectedRouteIndex + 1)
            UI.selectedRouteIndex = math.min(table.getn(Addon.profile.route), UI.selectedRouteIndex + 1)
        end
    end)

    self.remove = makeButton(frame, "Remove", 72, 25, "danger")
    self.remove:SetPoint("LEFT", self.down, "RIGHT", 5, 0)
    self.remove:SetScript("OnClick", function()
        if UI.selectedRouteIndex then
            Addon:RemoveRouteStep(UI.selectedRouteIndex)
            UI.selectedRouteIndex = nil
        end
    end)

    self.setCurrent = makeButton(frame, "Set Current", 94, 25)
    self.setCurrent:SetPoint("LEFT", self.remove, "RIGHT", 5, 0)
    self.setCurrent:SetScript("OnClick", function()
        if UI.selectedRouteIndex then
            Addon:SetCurrentStep(UI.selectedRouteIndex)
        end
    end)

    self.collapseZones = makeButton(frame, "Collapse", 76, 25)
    self.collapseZones:SetPoint("TOPLEFT", self.catalogPanel, "BOTTOMLEFT", 0, -8)
    self.collapseZones:SetScript("OnClick", function()
        UI:SetAllCatalogGroupsCollapsed(true)
    end)

    self.expandZones = makeButton(frame, "Expand", 76, 25)
    self.expandZones:SetPoint("LEFT", self.collapseZones, "RIGHT", 5, 0)
    self.expandZones:SetScript("OnClick", function()
        UI:SetAllCatalogGroupsCollapsed(false)
    end)

    self.import = makeButton(frame, "Import AutoCallboard", 148, 25, "primary")
    self.import:SetPoint("TOPRIGHT", self.catalogPanel, "BOTTOMRIGHT", 0, -8)
    self.import:SetScript("OnClick", function()
        Addon:ImportAutoCallboard()
    end)

    self.status = frame:CreateFontString(nil, "OVERLAY")
    self.status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 53)
    self.status:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 53)
    self.status:SetJustifyH("LEFT")
    self.status:SetText("Ready.")
    setTextStyle(self.status, 12, COLORS.muted, "LEFT")

    self.start = CreateFrame("Button", "RavioliCallboardStartRouteButton", frame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    self.start:SetWidth(104)
    self.start:SetHeight(28)
    styleButton(self.start, "Start Route", "primary")
    self.start:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 15)
    self.start:SetAttribute("type", "macro")
    self.start:SetAttribute("macrotext", "/cast Summon Callboard")
    self.start:SetScript("PostClick", function()
        Addon:BeginStartFlow()
    end)
    self.startActionCasts = true
    self:UpdateStartAction()

    self.summon = CreateFrame("Button", "RavioliCallboardSummonButton", frame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    self.summon:SetWidth(112)
    self.summon:SetHeight(28)
    self.summon:SetPoint("LEFT", self.start, "RIGHT", 8, 0)
    styleButton(self.summon, "Summon Board")
    self.summon:SetAttribute("type", "macro")
    self.summon:SetAttribute("macrotext", "/cast Summon Callboard")
    self.summon:SetScript("PostClick", function()
        Addon:BeginBoardOpenFlow(false)
    end)
    self:UpdateSummonCooldown()

    self.advance = makeButton(frame, "Complete Step", 112, 28, "success")
    self.advance:SetPoint("LEFT", self.summon, "RIGHT", 8, 0)
    self.advance:SetScript("OnClick", function()
        Addon:AdvanceRoute("Marked complete by user")
    end)

    self.reset = makeButton(frame, "Reset to Step 1", 112, 28)
    self.reset:SetPoint("LEFT", self.advance, "RIGHT", 8, 0)
    self.reset:SetScript("OnClick", function()
        Addon:ResetRoute()
    end)

    self.clear = makeButton(frame, "Clear Route", 96, 28, "danger")
    self.clear:SetPoint("LEFT", self.reset, "RIGHT", 8, 0)
    self.clear:SetScript("OnClick", function()
        Addon:ClearRoute()
        UI.selectedRouteIndex = nil
    end)

    local miniLayout = Addon.profile.miniWindow
    self.miniFrame = CreateFrame("Frame", "RavioliCallboardMiniFrame", UIParent)
    self.miniFrame:SetWidth(math.max(360, miniLayout.width or 390))
    self.miniFrame:SetHeight(miniLayout.height or 190)
    self.miniFrame:SetPoint(
        miniLayout.point or "CENTER",
        UIParent,
        miniLayout.relativePoint or "CENTER",
        miniLayout.x or 0,
        miniLayout.y or 180
    )
    self.miniFrame:SetFrameStrata("DIALOG")
    self.miniFrame:SetClampedToScreen(true)
    self.miniFrame:SetMovable(true)
    self.miniFrame:SetResizable(true)
    if self.miniFrame.SetMinResize then
        self.miniFrame:SetMinResize(360, 165)
    end
    if self.miniFrame.SetMaxResize then
        self.miniFrame:SetMaxResize(700, 600)
    end
    self.miniFrame:EnableMouse(true)
    self.miniFrame:RegisterForDrag("LeftButton")
    setBackdrop(self.miniFrame, COLORS.background)
    self.miniFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    self.miniFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI:SaveMiniLayout()
    end)

    self.miniFrame.title = self.miniFrame:CreateFontString(nil, "OVERLAY")
    self.miniFrame.title:SetPoint("TOPLEFT", self.miniFrame, "TOPLEFT", 14, -12)
    self.miniFrame.title:SetPoint("RIGHT", self.miniFrame, "RIGHT", -14, 0)
    self.miniFrame.title:SetJustifyH("LEFT")
    setTextStyle(self.miniFrame.title, 13, COLORS.gold, "LEFT")

    self.miniCurrent = self.miniFrame:CreateFontString(nil, "OVERLAY")
    self.miniCurrent:SetPoint("TOPLEFT", self.miniFrame, "TOPLEFT", 14, -40)
    self.miniCurrent:SetPoint("BOTTOMRIGHT", self.miniFrame, "BOTTOMRIGHT", -14, 88)
    self.miniCurrent:SetJustifyH("LEFT")
    self.miniCurrent:SetJustifyV("TOP")
    setTextStyle(self.miniCurrent, 12, COLORS.text, "LEFT")
    self.miniCurrent:SetJustifyV("TOP")

    self.miniNext = self.miniFrame:CreateFontString(nil, "OVERLAY")
    setTextStyle(self.miniNext, 11, COLORS.muted, "LEFT")
    self.miniNext:Hide()

    self.miniStatus = self.miniFrame:CreateFontString(nil, "OVERLAY")
    self.miniStatus:SetPoint("BOTTOMLEFT", self.miniFrame, "BOTTOMLEFT", 14, 52)
    self.miniStatus:SetPoint("BOTTOMRIGHT", self.miniFrame, "BOTTOMRIGHT", -14, 52)
    self.miniStatus:SetJustifyH("LEFT")
    setTextStyle(self.miniStatus, 11, COLORS.muted, "LEFT")

    self.miniSummon = CreateFrame("Button", "RavioliCallboardMiniSummonButton", self.miniFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    self.miniSummon:SetWidth(122)
    self.miniSummon:SetHeight(28)
    self.miniSummon:SetPoint("BOTTOMLEFT", self.miniFrame, "BOTTOMLEFT", 14, 14)
    styleButton(self.miniSummon, "Summon Board")
    self.miniSummon:SetAttribute("type", "macro")
    self.miniSummon:SetAttribute("macrotext", "/cast Summon Callboard")
    self.miniSummon:SetScript("PostClick", function()
        Addon:BeginBoardOpenFlow(false)
    end)

    self.miniStop = makeButton(self.miniFrame, "STOP", 90, 28, "danger")
    self.miniStop:SetPoint("LEFT", self.miniSummon, "RIGHT", 8, 0)
    self.miniStop:SetScript("OnClick", function()
        Addon:StopRouteAndReturn()
    end)

    self.miniGroup = makeButton(self.miniFrame, "Group", 88, 28)
    self.miniGroup:SetPoint("LEFT", self.miniStop, "RIGHT", 8, 0)
    self.miniGroup:SetScript("OnClick", function()
        UI:ToggleGroupProgress()
    end)

    self.groupProgressFrame = CreateFrame("Frame", "RavioliCallboardGroupProgressFrame", self.miniFrame)
    self.groupProgressFrame:SetWidth(360)
    self.groupProgressFrame:SetHeight(390)
    self.groupProgressFrame:SetPoint("TOPLEFT", self.miniFrame, "TOPRIGHT", 8, 0)
    self.groupProgressFrame:SetFrameStrata("TOOLTIP")
    self.groupProgressFrame:SetClampedToScreen(true)
    self.groupProgressFrame:EnableMouse(true)
    setBackdrop(self.groupProgressFrame, COLORS.background, COLORS.gold)

    self.groupProgressFrame.title = self.groupProgressFrame:CreateFontString(nil, "OVERLAY")
    self.groupProgressFrame.title:SetPoint("TOPLEFT", self.groupProgressFrame, "TOPLEFT", 14, -13)
    self.groupProgressFrame.title:SetText("Group Progress")
    setTextStyle(self.groupProgressFrame.title, 16, COLORS.gold, "LEFT")

    self.groupProgressFrame.close = makeButton(self.groupProgressFrame, "X", 26, 22)
    self.groupProgressFrame.close:SetPoint("TOPRIGHT", self.groupProgressFrame, "TOPRIGHT", -9, -9)
    self.groupProgressFrame.close:SetScript("OnClick", function()
        UI.groupProgressFrame:Hide()
    end)

    self.groupProgressFrame.subtitle = self.groupProgressFrame:CreateFontString(nil, "OVERLAY")
    self.groupProgressFrame.subtitle:SetPoint("TOPLEFT", self.groupProgressFrame, "TOPLEFT", 14, -42)
    self.groupProgressFrame.subtitle:SetPoint("RIGHT", self.groupProgressFrame, "RIGHT", -14, 0)
    self.groupProgressFrame.subtitle:SetJustifyH("LEFT")
    setTextStyle(self.groupProgressFrame.subtitle, 11, COLORS.muted, "LEFT")

    self.groupProgressScroll = CreateFrame("ScrollFrame", "RavioliCallboardGroupProgressScroll", self.groupProgressFrame, "UIPanelScrollFrameTemplate")
    self.groupProgressScroll:SetPoint("TOPLEFT", self.groupProgressFrame, "TOPLEFT", 12, -68)
    self.groupProgressScroll:SetPoint("BOTTOMRIGHT", self.groupProgressFrame, "BOTTOMRIGHT", -31, 13)

    self.groupProgressChild = CreateFrame("Frame", nil, self.groupProgressScroll)
    self.groupProgressChild:SetWidth(305)
    self.groupProgressChild:SetHeight(250)
    self.groupProgressScroll:SetScrollChild(self.groupProgressChild)

    self.groupProgressText = self.groupProgressChild:CreateFontString(nil, "OVERLAY")
    self.groupProgressText:SetPoint("TOPLEFT", self.groupProgressChild, "TOPLEFT", 3, -3)
    self.groupProgressText:SetPoint("RIGHT", self.groupProgressChild, "RIGHT", -3, 0)
    self.groupProgressText:SetJustifyH("LEFT")
    self.groupProgressText:SetJustifyV("TOP")
    setTextStyle(self.groupProgressText, 12, COLORS.text, "LEFT")
    self.groupProgressText:SetJustifyV("TOP")
    self.groupProgressFrame:Hide()

    self.miniResize = CreateFrame("Button", nil, self.miniFrame)
    self.miniResize:SetWidth(18)
    self.miniResize:SetHeight(18)
    self.miniResize:SetPoint("BOTTOMRIGHT", self.miniFrame, "BOTTOMRIGHT", -2, 2)
    self.miniResize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    self.miniResize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    self.miniResize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    self.miniResize:SetScript("OnMouseDown", function()
        UI.miniFrame:StartSizing("BOTTOMRIGHT")
    end)
    self.miniResize:SetScript("OnMouseUp", function()
        UI.miniFrame:StopMovingOrSizing()
        UI:SaveMiniLayout()
    end)
    self.miniFrame:Hide()
    self.lastSummonCooldownSecond = nil
    self:UpdateSummonCooldown()

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "RavioliCallboardFrame")
    end
    return frame
end

function UI:SetStatus(message)
    if self.status then
        self.status:SetText(message or "")
        local color = statusColor(message)
        self.status:SetTextColor(unpack(color))
    end
end

function UI:Refresh()
    if not self.frame or not Addon.profile or not Addon.db then
        return
    end

    local route = Addon.profile.route
    local routeCount = table.getn(route)
    local activeRouteName = Addon.profile.activeRouteName
    local loopSuffix = Addon.profile.autoLoop and ("  " .. COLOR_CODES.gold .. "[Loop]|r") or ""
    self.routePanel.title:SetText(activeRouteName and ("Quest route — " .. activeRouteName .. loopSuffix) or ("Quest route" .. loopSuffix))
    self.routeOffset = clampOffset(self.routeOffset, routeCount, 13)

    for visibleIndex = 1, 13 do
        local row = self.routeRows[visibleIndex]
        local routeIndex = self.routeOffset + visibleIndex
        local key = route[routeIndex]
        if key then
            local quest = Addon.db.knownQuests[key]
            local title = quest and Core.QuestTitle(quest) or key
            row.routeIndex = routeIndex
            if routeIndex == Addon.profile.currentStep then
                row.number:SetText("> " .. tostring(routeIndex) .. ".")
                row.label:SetText("[Current] " .. title)
                setRowState(row, COLORS.panelLight, COLORS.green)
            elseif routeIndex == self.selectedRouteIndex then
                row.number:SetText(tostring(routeIndex) .. ".")
                row.label:SetText("[Selected] " .. title)
                setRowState(row, COLORS.panelLight, COLORS.gold)
            else
                row.number:SetText(tostring(routeIndex) .. ".")
                row.label:SetText(title)
                setRowState(row, COLORS.panel, COLORS.border)
            end
            row:Show()
        else
            row.routeIndex = nil
            row:Hide()
        end
    end
    self.routePage:SetText(tostring(routeCount) .. " route step(s)")
    if self.routeEmpty then
        if routeCount == 0 then
            self.routeEmpty:Show()
        else
            self.routeEmpty:Hide()
        end
    end

    local zoneCount
    local learnedCount
    self.catalog, zoneCount, learnedCount = Core.BuildGroupedCatalog(
        Addon.db,
        self.searchText,
        Addon.profile.catalogCollapsed
    )
    local catalogCount = table.getn(self.catalog)
    if self.catalogEmpty then
        if catalogCount == 0 then
            self.catalogEmpty:SetText((self.searchText or "") ~= ""
                and "No learned quests match this search."
                or "No quests learned yet. Open the Callboard or import AutoCallboard data.")
            self.catalogEmpty:Show()
        else
            self.catalogEmpty:Hide()
        end
    end
    self.catalogOffset = clampOffset(self.catalogOffset, catalogCount, 12)
    for visibleIndex = 1, 12 do
        local row = self.catalogRows[visibleIndex]
        local catalogIndex = self.catalogOffset + visibleIndex
        local entry = self.catalog[catalogIndex]
        if entry then
            if entry.kind == "header" then
                row.groupId = entry.groupId
                row.add.questKey = nil
                row.info.questKey = nil
                row.add:Hide()
                row.info:Hide()
                row.label:ClearAllPoints()
                row.label:SetPoint("LEFT", row, "LEFT", 10, 0)
                row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                row.label:SetText((entry.collapsed and (COLOR_CODES.gold .. "[+]|r ") or (COLOR_CODES.gold .. "[-]|r "))
                    .. entry.label .. "  " .. COLOR_CODES.muted .. "(" .. tostring(entry.count) .. ")|r")
                setRowState(row, COLORS.panelLight, COLORS.gold)
            else
                local quest = entry.quest
                local inRoute = Core.RouteContains(route, quest.key)
                row.groupId = nil
                row.add.questKey = quest.key
                row.info.questKey = quest.key
                row.add:SetText(inRoute and "=" or "+")
                row.add:Show()
                row.info:Show()
                if inRoute then
                    row.add:SetButtonEnabled(false)
                else
                    row.add:SetButtonEnabled(true)
                end
                row.label:ClearAllPoints()
                row.label:SetPoint("LEFT", row.add, "RIGHT", 7, 0)
                row.label:SetPoint("RIGHT", row.info, "LEFT", -5, 0)
                local idSuffix = quest.questId and ("  " .. COLOR_CODES.muted .. "#" .. tostring(quest.questId) .. "|r") or ""
                row.label:SetText(Core.QuestTitle(quest) .. idSuffix)
                setRowState(row, COLORS.panel, COLORS.border)
            end
            row:Show()
        else
            row.groupId = nil
            row.add.questKey = nil
            row.info.questKey = nil
            row:Hide()
        end
    end
    self.catalogPage:SetText(tostring(learnedCount or 0) .. " learned quest(s) in " .. tostring(zoneCount or 0) .. " zone group(s)")

    self.start:SetText("Start Route")
    self:SetStatus(Addon.statusMessage or "Ready.")
    self:RefreshMini()
end

function UI:Toggle()
    self:Create()
    if self.miniFrame and self.miniFrame:IsShown() then
        self:ShowMain()
        return
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:Refresh()
    end
end
