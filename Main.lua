local ADDON_NAME, Addon = ...
local Core = Addon.Core
local PE = Addon.PE
local UI = Addon.UI
local Group = Addon.Group

local PREFIX = "|cffb58cffRavioliCallboard:|r "
local eventFrame = CreateFrame("Frame")

Addon.db = nil
Addon.profile = nil
Addon.profileKey = nil
Addon.running = false
Addon.statusMessage = "Ready."
Addon.rerollCount = 0
Addon.sessionCost = 0
Addon.pendingReroll = nil
Addon.pendingAccept = nil
Addon.waitingKey = nil
Addon.waitingSeenInLog = false
Addon.waitingSeenActiveObjective = false
Addon.waitingWasComplete = false
Addon.closeBoardAt = nil
Addon.nextActionAt = nil
Addon.nextObjectiveRequestAt = nil
Addon.lastBoardVisible = false
Addon.pendingBoardOpen = nil
Addon.lastSummonCooldownRemaining = nil
Addon.initialized = false

local function Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(message or ""))
    end
end

local function now()
    return GetTime and GetTime() or 0
end

local function routeCount()
    return Addon.profile and table.getn(Addon.profile.route or {}) or 0
end

local function currentKey()
    if not Addon.profile then
        return nil
    end
    return Addon.profile.route[Addon.profile.currentStep]
end

local function questForKey(key)
    return key and Addon.db and Addon.db.knownQuests[key] or nil
end

local function questLabel(key)
    local quest = questForKey(key)
    if not quest then
        return tostring(key or "unknown quest")
    end
    return Core.QuestTitle(quest) ~= "" and Core.QuestTitle(quest) or tostring(key)
end

local function coinText(copper)
    if not copper or copper <= 0 then
        return nil
    end
    if GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    return tostring(copper) .. " copper"
end

function Addon:SetStatus(message, announce)
    message = tostring(message or "")
    if self.statusMessage ~= message then
        self.statusMessage = message
        if announce then
            Print(message)
        end
        if UI and UI.Refresh then
            UI:Refresh()
        end
    end
end

local function resetRuntime()
    Addon.pendingReroll = nil
    Addon.pendingAccept = nil
    Addon.waitingKey = nil
    Addon.waitingSeenInLog = false
    Addon.waitingSeenActiveObjective = false
    Addon.waitingWasComplete = false
    Addon.closeBoardAt = nil
    Addon.nextActionAt = nil
    Addon.rerollCount = 0
    Addon.sessionCost = 0
end

local function cleanRouteName(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function getQuestLogEntry(index)
    if not GetQuestLogTitle then
        return nil
    end

    local title, _, _, fourth, fifth, sixth, seventh, eighth, ninth = GetQuestLogTitle(index)
    if not title then
        return nil
    end

    local wrathQuestID = tonumber(ninth)
    if wrathQuestID and wrathQuestID > 0 then
        return {
            title = title,
            isHeader = fifth,
            isComplete = seventh,
            questID = wrathQuestID,
        }
    end

    return {
        title = title,
        isHeader = fourth,
        isComplete = sixth,
        questID = tonumber(eighth),
    }
end

local function questMatchesKey(questID, title, key)
    local wanted = questForKey(key)
    if not wanted then
        return false
    end

    local wantedID = Core.QuestID(wanted)
    questID = tonumber(questID)
    if wantedID and questID and questID > 0 then
        return wantedID == questID
    end

    local wantedTitle = Core.NormalizeTitle(Core.QuestTitle(wanted))
    local actualTitle = Core.NormalizeTitle(title)
    return wantedTitle ~= "" and wantedTitle == actualTitle
end

local function findQuestInLog(key)
    if not GetNumQuestLogEntries then
        return nil
    end

    for index = 1, GetNumQuestLogEntries() do
        local entry = getQuestLogEntry(index)
        if entry and not entry.isHeader and questMatchesKey(entry.questID, entry.title, key) then
            return index, entry
        end
    end
    return nil
end

local function activeObjectiveMatches(key)
    local active = PE.GetActiveObjective()
    return active and Core.QuestKey(active) == key
end

local function questIsFlaggedCompleted(key)
    if not IsQuestFlaggedCompleted then
        return false
    end
    local quest = questForKey(key)
    local questID = quest and Core.QuestID(quest)
    if not questID then
        return false
    end
    local ok, completed = pcall(IsQuestFlaggedCompleted, questID)
    return ok and (completed == true or tonumber(completed) == 1)
end

local function detailQuestIdentity()
    local questID
    if GetQuestID then
        local ok, value = pcall(GetQuestID)
        if ok then
            questID = tonumber(value)
        end
    end

    local title
    if GetTitleText then
        local ok, value = pcall(GetTitleText)
        if ok and type(value) == "string" then
            title = value
        end
    end
    return questID, title
end

local function learnCurrentObjectives()
    if not Addon.db then
        return 0, {}
    end

    local objectives = PE.GetObjectives()
    local added = 0
    for i = 1, table.getn(objectives) do
        if Core.LearnQuest(Addon.db, objectives[i]) then
            added = added + 1
        end
    end
    if added > 0 and UI and UI.Refresh then
        UI:Refresh()
    end
    return added, objectives
end

local function initializeProfile()
    Addon.profileKey = Core.ProfileKey()
    Addon.db.profiles[Addon.profileKey] = Core.MergeProfile(Addon.db.profiles[Addon.profileKey])
    Addon.profile = Addon.db.profiles[Addon.profileKey]
end

local function automationConflict()
    if not IsAddOnLoaded or not IsAddOnLoaded("AutoCallboard") then
        return false
    end
    return type(AutoCallboardDB) ~= "table" or AutoCallboardDB.addonEnabled ~= false
end

local function repeatRuleMessage(key)
    local questText = key and (questLabel(key) .. " is too close to its previous occurrence. ") or ""
    return questText .. "The Callboard requires three different completed quests between repeats; use at least four different quests for a loop."
end

local function currentQuestIsRepeatLocked()
    local key = currentKey()
    return key and Core.IsQuestRepeatLocked(Addon.profile and Addon.profile.recentCompletedQuests, key), key
end

local function validateRouteStart(requireBoard)
    if Addon.running then
        Addon:SetStatus("The route is already running. Use the mini window to stop it.", true)
        if UI and UI.ShowMini then
            UI:ShowMini()
        end
        return false
    end
    if not Addon.profile or routeCount() == 0 then
        Addon:SetStatus("Build a route before starting.", true)
        return false
    end
    if Addon.profile.currentStep > routeCount() then
        Addon:SetStatus("Route complete. Reset it to run again.", true)
        return false
    end
    local validRepeatSpacing, repeatKey = Core.ValidateRouteRepeatSpacing(Addon.profile.route, Addon.profile.autoLoop)
    if not validRepeatSpacing then
        Addon:SetStatus(repeatRuleMessage(repeatKey), true)
        return false
    end
    local repeatLocked, lockedKey = currentQuestIsRepeatLocked()
    if repeatLocked then
        Addon:SetStatus(questLabel(lockedKey) .. " is still repeat-locked. Complete three different Callboard quests before rolling for it again.", true)
        return false
    end
    if requireBoard and not PE.IsBoardVisible() then
        Addon:SetStatus("Open the Callboard window before starting the route.", true)
        return false
    end
    if automationConflict() then
        Addon:SetStatus("AutoCallboard is still enabled. Use /acb toggle or disable it before starting RavioliCallboard.", true)
        return false
    end
    return true
end

function Addon:GetCurrentRouteQuest()
    return questForKey(currentKey())
end

function Addon:AddRouteQuest(key)
    if not self.profile or not questForKey(key) then
        return false
    end
    if Core.RouteContains(self.profile.route, key) then
        self:SetStatus("That quest is already in the route.")
        return false
    end
    table.insert(self.profile.route, key)
    if self.profile.currentStep > table.getn(self.profile.route) then
        self.profile.currentStep = table.getn(self.profile.route)
    end
    self:SetStatus("Added: " .. questLabel(key))
    UI:Refresh()
    return true
end

function Addon:RemoveRouteStep(index)
    local count = routeCount()
    if not self.profile or not index or index < 1 or index > count then
        return
    end

    self:PauseRoute(nil)
    table.remove(self.profile.route, index)
    if index < self.profile.currentStep then
        self.profile.currentStep = self.profile.currentStep - 1
    end
    self.profile.currentStep = math.max(1, math.min(self.profile.currentStep, routeCount() + 1))
    resetRuntime()
    self:SetStatus("Route step removed.")
    UI:Refresh()
end

function Addon:MoveRouteStep(fromIndex, toIndex)
    local count = routeCount()
    if not self.profile or not fromIndex or not toIndex or fromIndex < 1 or fromIndex > count or toIndex < 1 or toIndex > count or fromIndex == toIndex then
        return
    end

    self:PauseRoute(nil)
    local key = table.remove(self.profile.route, fromIndex)
    table.insert(self.profile.route, toIndex, key)

    local current = self.profile.currentStep
    if current == fromIndex then
        current = toIndex
    elseif fromIndex < current and current <= toIndex then
        current = current - 1
    elseif toIndex <= current and current < fromIndex then
        current = current + 1
    end
    self.profile.currentStep = current
    resetRuntime()
    self:SetStatus("Route reordered.")
    UI:Refresh()
end

function Addon:SetCurrentStep(index)
    if not self.profile or not index or index < 1 or index > routeCount() then
        return
    end
    self:PauseRoute(nil)
    resetRuntime()
    self.profile.currentStep = index
    self:SetStatus("Current step set to " .. tostring(index) .. ": " .. questLabel(currentKey()))
    UI:Refresh()
end

function Addon:ClearRoute()
    self:PauseRoute(nil)
    self.profile.route = {}
    self.profile.currentStep = 1
    self.profile.activeRouteName = nil
    resetRuntime()
    self:SetStatus("Route cleared.")
    UI:Refresh()
end

function Addon:ResetRoute()
    self:PauseRoute(nil)
    self.profile.currentStep = 1
    resetRuntime()
    self:SetStatus("Route reset to step 1.")
    UI:Refresh()
end

function Addon:SaveCurrentRoute(name)
    name = cleanRouteName(name)
    if name == "" then
        self:SetStatus("Enter a name before saving the route.", true)
        return false
    end
    if routeCount() == 0 then
        self:SetStatus("Add quests before saving a route.", true)
        return false
    end

    self.profile.savedRoutes = self.profile.savedRoutes or {}
    self.profile.savedRoutes[name] = {
        route = Core.CopyRoute(self.profile.route),
        autoLoop = self.profile.autoLoop == true,
    }
    self.profile.activeRouteName = name
    self:SetStatus("Saved route: " .. name .. ".", true)
    if UI and UI.RefreshRouteManager then
        UI:RefreshRouteManager()
    end
    UI:Refresh()
    return true
end

function Addon:ShareCurrentRoute(target, name)
    if not self.profile or not Group or not Group.QueueRouteShare then
        self:SetStatus("Route sharing is unavailable.", true)
        return false
    end
    name = cleanRouteName(name)
    if name == "" then
        name = self.profile.activeRouteName or "Shared Route"
    end
    local ok, reason = Group:QueueRouteShare(
        target,
        name,
        Core.CopyRoute(self.profile.route),
        self.profile.autoLoop == true
    )
    if not ok then
        self:SetStatus(reason or "Could not share the route.", true)
        return false
    end
    self:SetStatus("Sending route " .. name .. " privately to " .. tostring(target) .. "...", true)
    return true
end

function Addon:ShareSavedRoute(name, target)
    name = cleanRouteName(name)
    local saved = self.profile and self.profile.savedRoutes and self.profile.savedRoutes[name]
    if not saved then
        self:SetStatus("Saved route not found: " .. name .. ".", true)
        return false
    end
    if not Group or not Group.QueueRouteShare then
        self:SetStatus("Route sharing is unavailable.", true)
        return false
    end
    local ok, reason = Group:QueueRouteShare(
        target,
        name,
        Core.CopyRoute(saved.route),
        saved.autoLoop == true
    )
    if not ok then
        self:SetStatus(reason or "Could not share the route.", true)
        return false
    end
    self:SetStatus("Sending saved route " .. name .. " privately to " .. tostring(target) .. "...", true)
    return true
end

function Addon:LoadSavedRoute(name)
    name = cleanRouteName(name)
    local saved = self.profile and self.profile.savedRoutes and self.profile.savedRoutes[name]
    if not saved then
        self:SetStatus("Saved route not found: " .. name .. ".", true)
        return false
    end

    self:PauseRoute(nil)
    resetRuntime()
    self.profile.route = Core.CopyRoute(saved.route)
    self.profile.currentStep = 1
    self.profile.autoLoop = saved.autoLoop == true
    self.profile.activeRouteName = name
    self:SetStatus("Loaded route: " .. name .. (self.profile.autoLoop and " (auto-loop on)." or "."), true)
    UI.selectedRouteIndex = nil
    UI.routeOffset = 0
    UI:Refresh()
    if UI and UI.RefreshSettings then
        UI:RefreshSettings()
    end
    return true
end

function Addon:DeleteSavedRoute(name)
    name = cleanRouteName(name)
    if not self.profile or not self.profile.savedRoutes or not self.profile.savedRoutes[name] then
        return false
    end
    self.profile.savedRoutes[name] = nil
    if self.profile.activeRouteName == name then
        self.profile.activeRouteName = nil
    end
    self:SetStatus("Deleted saved route: " .. name .. ".", true)
    if UI and UI.RefreshRouteManager then
        UI:RefreshRouteManager()
    end
    UI:Refresh()
    return true
end

function Addon:ApplySettings(autoLoop, autoAccept, maxRerolls, rerollDelay, miniQuestCount, autoShare, showGroupProgress)
    if not self.profile then
        return
    end
    local requestedAutoLoop = autoLoop and true or false
    local validRepeatSpacing, repeatKey = Core.ValidateRouteRepeatSpacing(self.profile.route, requestedAutoLoop)
    self.profile.autoLoop = requestedAutoLoop and validRepeatSpacing
    self.profile.autoAccept = autoAccept and true or false
    self.profile.autoShare = autoShare and true or false
    self.profile.showGroupProgress = showGroupProgress and true or false
    self.profile.maxRerolls = math.max(1, math.min(500, math.floor(tonumber(maxRerolls) or self.profile.maxRerolls)))
    self.profile.rerollDelay = math.max(0.5, math.min(10, tonumber(rerollDelay) or self.profile.rerollDelay))
    self.profile.miniQuestCount = math.max(1, math.min(20, math.floor(tonumber(miniQuestCount) or self.profile.miniQuestCount or 5)))
    if requestedAutoLoop and not validRepeatSpacing then
        self:SetStatus("Settings saved, but auto-loop was left off. " .. repeatRuleMessage(repeatKey), true)
    else
        self:SetStatus("Settings saved" .. (self.profile.autoLoop and "; route will loop." or "."), true)
    end
    if UI and UI.RefreshSettings then
        UI:RefreshSettings()
    end
    UI:Refresh()
end

function Addon:PauseRoute(message)
    self.running = false
    self.pendingReroll = nil
    self.nextActionAt = nil
    if message then
        self:SetStatus(message, true)
    end
    if UI and UI.Refresh then
        UI:Refresh()
    end
end

function Addon:StartRoute()
    if not validateRouteStart(true) then
        return false
    end

    self.running = true
    self.rerollCount = 0
    self.sessionCost = 0
    self.pendingReroll = nil
    self.nextActionAt = now()

    local key = currentKey()
    if Group and Group.SetTrackedQuest then
        Group:SetTrackedQuest(key)
    end
    local _, entry = findQuestInLog(key)
    if entry or activeObjectiveMatches(key) then
        self.waitingKey = key
        self.waitingSeenInLog = entry ~= nil
        self.waitingSeenActiveObjective = activeObjectiveMatches(key) and true or false
        self.waitingWasComplete = entry and (entry.isComplete == true or tonumber(entry.isComplete) == 1) or false
        self:SetStatus("Step " .. tostring(self.profile.currentStep) .. " is active: " .. questLabel(key) .. ". Complete it to continue.", true)
    else
        self.waitingKey = nil
        self.waitingSeenInLog = false
        self.waitingSeenActiveObjective = false
        self.waitingWasComplete = false
        self:SetStatus("Running step " .. tostring(self.profile.currentStep) .. ": " .. questLabel(key) .. ". Open the Callboard.", true)
    end
    if UI and UI.ShowMini then
        UI:ShowMini()
    end
    UI:Refresh()
    return true
end

local function tryInteractWithCallboard()
    if PE.TryInteractWithCallboard then
        return PE.TryInteractWithCallboard()
    end
    return false
end

function Addon:BeginBoardOpenFlow(startRouteAfterOpen)
    if startRouteAfterOpen and not validateRouteStart(false) then
        return false
    end

    if startRouteAfterOpen and UI and UI.ShowMini then
        UI:ShowMini()
    end

    if PE.IsBoardVisible() then
        if startRouteAfterOpen then
            return self:StartRoute()
        end
        self:SetStatus("Callboard is already open.")
        return true
    end

    local nearbyBoard = PE.IsCallboardNearby and PE.IsCallboardNearby(true) or false
    local canSummon = PE.IsSummonSpellKnown and PE.IsSummonSpellKnown() or true
    local summonCooldown = PE.GetSummonCooldownRemaining and PE.GetSummonCooldownRemaining() or 0
    self.pendingBoardOpen = {
        startRoute = startRouteAfterOpen == true,
        expiresAt = now() + 12,
        nextInteractAt = now(),
        canSummon = canSummon,
        summonOnCooldown = summonCooldown > 0,
    }
    if nearbyBoard then
        self:SetStatus("Opening the nearby Callboard...", true)
    elseif summonCooldown > 0 then
        self:SetStatus("Callboard is on cooldown. Looking for the existing board...", true)
    elseif canSummon then
        self:SetStatus(startRouteAfterOpen
            and "Summoning and opening the Callboard..."
            or "Waiting for the Callboard to appear...", true)
    else
        self:SetStatus("Summon Callboard is not learned. Move close to a city Callboard and try again.", true)
    end
    tryInteractWithCallboard()
    return true
end

function Addon:BeginStartFlow()
    return self:BeginBoardOpenFlow(true)
end

function Addon:StopRouteAndReturn()
    self.pendingBoardOpen = nil
    self:PauseRoute("Route stopped.")
    if UI and UI.ShowMain then
        UI:ShowMain()
    end
end

function Addon:AdvanceRoute(reason)
    if not self.profile or routeCount() == 0 then
        return
    end

    local completedKey = currentKey()
    local completedTitle = questLabel(completedKey)
    if Group and Group.MarkTrackedComplete then
        Group:MarkTrackedComplete(completedKey)
    end
    self.profile.recentCompletedQuests = Core.RecordCompletedQuest(self.profile.recentCompletedQuests, completedKey)
    self.profile.currentStep = self.profile.currentStep + 1
    self.pendingReroll = nil
    self.pendingAccept = nil
    self.waitingKey = nil
    self.waitingSeenInLog = false
    self.waitingSeenActiveObjective = false
    self.waitingWasComplete = false
    self.rerollCount = 0
    self.nextActionAt = now()

    if self.profile.currentStep > routeCount() and self.running and self.profile.autoLoop then
        self.profile.currentStep = 1
        self.rerollCount = 0
        self.nextActionAt = now()
        self:SetStatus("Finished " .. completedTitle .. ". Looping to step 1: " .. questLabel(currentKey()) .. ".", true)
    elseif self.profile.currentStep > routeCount() then
        self.running = false
        self:SetStatus("Route complete. Finished: " .. completedTitle .. ".", true)
    else
        self:SetStatus("Completed " .. completedTitle .. ". Next: " .. questLabel(currentKey()) .. ".", true)
        if self.running and not PE.IsBoardVisible() then
            self:SetStatus("Next step " .. tostring(self.profile.currentStep) .. ": " .. questLabel(currentKey()) .. ". Open the Callboard.")
        end
    end
    UI:Refresh()
end

function Addon:ImportAutoCallboard()
    if not self.db then
        return 0
    end

    local source = type(AutoCallboardDB) == "table" and AutoCallboardDB.knownQuests or nil
    if type(source) ~= "table" then
        self:SetStatus("AutoCallboard's learned catalogue is not loaded. Enable it once, reload, then import.", true)
        return 0
    end

    local added = Core.ImportQuestList(self.db, source)
    self:SetStatus("Imported " .. tostring(added) .. " new quest(s) from AutoCallboard; " .. tostring(table.getn(Core.BuildCatalog(self.db, ""))) .. " known total.", true)
    UI:Refresh()
    return added
end

local function beginWaitingForQuest(key)
    local quest = questForKey(key)
    if Group and Group.SetTrackedQuest then
        Group:SetTrackedQuest(key)
    end
    Addon.waitingKey = key
    Addon.waitingSeenInLog = false
    Addon.waitingSeenActiveObjective = false
    Addon.waitingWasComplete = false
    Addon.pendingAccept = {
        key = key,
        questID = quest and Core.QuestID(quest),
        title = quest and Core.QuestTitle(quest) or "",
        expiresAt = now() + 12,
    }
    Addon.closeBoardAt = now() + 1
    Addon:SetStatus("Selected step " .. tostring(Addon.profile.currentStep) .. ": " .. questLabel(key) .. ". Waiting for acceptance.", true)
end

local function processBoard()
    local key = currentKey()
    if not key then
        Addon.running = false
        Addon:SetStatus("Route complete.", true)
        return
    end

    if Core.IsQuestRepeatLocked(Addon.profile.recentCompletedQuests, key) then
        Addon:PauseRoute("Stopped before rerolling: " .. questLabel(key) .. " is still repeat-locked. Complete three different Callboard quests first.")
        return
    end

    local _, objectives = learnCurrentObjectives()
    if table.getn(objectives) == 0 then
        if not Addon.nextObjectiveRequestAt or now() >= Addon.nextObjectiveRequestAt then
            Addon.nextObjectiveRequestAt = now() + 1
            PE.RequestObjectives()
        end
        Addon:SetStatus("Callboard is open; waiting for quest offers.")
        return
    end

    local signature = Core.ObjectiveSignature(objectives)
    if Addon.pendingReroll then
        -- The confirmation popup can appear a frame after the reroll request.
        -- Keep checking only while this specific request is pending.
        PE.ConfirmReroll()
        if signature == Addon.pendingReroll.signature then
            if now() < Addon.pendingReroll.expiresAt then
                return
            end
        else
            -- The offers have already refreshed. Discard the old response
            -- timeout so the new list is searched on the next fast update.
            Addon.nextActionAt = now() + 0.10
        end
        Addon.pendingReroll = nil
    end

    local index = Core.FindObjective(objectives, key)
    if index then
        if PE.SelectObjective(index) then
            beginWaitingForQuest(key)
        else
            Addon:SetStatus("Found " .. questLabel(key) .. " but could not select it.", true)
            Addon.nextActionAt = now() + 0.75
        end
        return
    end

    if Addon.nextActionAt and now() < Addon.nextActionAt then
        return
    end
    if Addon.rerollCount >= Addon.profile.maxRerolls then
        Addon:PauseRoute("Stopped after " .. tostring(Addon.rerollCount) .. " rerolls without finding " .. questLabel(key) .. ".")
        return
    end

    local ok, reason = PE.RequestReroll()
    if not ok then
        if reason == "no_gold" then
            Addon:PauseRoute("Not enough gold to continue rerolling.")
        elseif reason == "board_closed" then
            Addon:PauseRoute("The Callboard window closed. Reopen it before restarting the route.")
        else
            Addon:PauseRoute("Could not reroll. Check that the Callboard is open.")
        end
        return
    end

    Addon.rerollCount = Addon.rerollCount + 1
    Addon.sessionCost = Addon.sessionCost + PE.GetRerollCost()
    Addon.pendingReroll = {
        signature = signature,
        expiresAt = now() + Addon.profile.rerollDelay,
    }
    Addon.nextActionAt = Addon.pendingReroll.expiresAt
    local cost = coinText(Addon.sessionCost)
    Addon:SetStatus("Reroll " .. tostring(Addon.rerollCount) .. "/" .. tostring(Addon.profile.maxRerolls) .. " for " .. questLabel(key) .. (cost and " | Spent: " .. cost or ""))
end

local function updateWaitingState()
    if not Addon.waitingKey then
        return false
    end

    local waitingKey = Addon.waitingKey
    local activeObjective = PE.GetActiveObjective()
    local activeMatches = activeObjective and Core.QuestKey(activeObjective) == waitingKey
    if activeMatches then
        Addon.waitingSeenActiveObjective = true
    end

    local _, entry = findQuestInLog(waitingKey)
    if entry then
        Addon.waitingSeenInLog = true
        if entry.isComplete == true or tonumber(entry.isComplete) == 1 then
            Addon.waitingWasComplete = true
            Addon:AdvanceRoute("Quest log marked complete")
            return false
        end
    end

    if questIsFlaggedCompleted(waitingKey) then
        Addon.waitingWasComplete = true
        Addon:AdvanceRoute("Quest completion flag detected")
        return false
    end

    -- Project Ebonhold may clear its active objective without first exposing a
    -- completed quest-log entry. Once this exact route quest has been observed
    -- as active, its removal or replacement confirms that the step has ended.
    if Addon.waitingSeenActiveObjective and not activeMatches then
        Addon:AdvanceRoute("Active Callboard quest cleared")
        return false
    end

    -- Some Ebonhold objectives leave the normal quest log immediately on
    -- completion. Seeing the exact quest in the log and then losing it is the
    -- same completion transition used by AutoCallboard.
    if Addon.waitingSeenInLog and not entry then
        Addon:AdvanceRoute("Callboard quest left the log")
        return false
    end

    if entry or activeMatches then
        Addon:SetStatus("Active step " .. tostring(Addon.profile.currentStep) .. ": " .. questLabel(waitingKey) .. ".")
        return true
    end

    if Addon.pendingAccept and now() > Addon.pendingAccept.expiresAt then
        if activeObjectiveMatches(Addon.waitingKey) then
            Addon.pendingAccept = nil
            Addon:SetStatus("Active step " .. tostring(Addon.profile.currentStep) .. ": " .. questLabel(Addon.waitingKey) .. ".")
            return true
        end

        Addon.pendingAccept = nil
        Addon.waitingKey = nil
        Addon.waitingSeenActiveObjective = false
        Addon:SetStatus("Quest acceptance was not confirmed; retrying current route step.", true)
        Addon.nextActionAt = now()
        return false
    end
    return true
end

local function processPendingBoardOpen()
    local pending = Addon.pendingBoardOpen
    if not pending then
        return
    end

    if PE.IsBoardVisible() then
        Addon.pendingBoardOpen = nil
        if pending.startRoute then
            Addon:StartRoute()
        else
            Addon:SetStatus("Callboard opened.")
        end
        return
    end

    if now() > pending.expiresAt then
        Addon.pendingBoardOpen = nil
        if pending.summonOnCooldown then
            Addon:SetStatus("The existing Callboard could not be reached. Move closer to it and press Start Route again; the cooldown will not be recast.", true)
        elseif not pending.canSummon then
            Addon:SetStatus("No nearby city Callboard was found, and Summon Callboard is not learned. Move closer to a city board and try again.", true)
        else
            Addon:SetStatus(pending.startRoute
                and "Could not open the Callboard automatically. Interact with it, then press Start Route again."
                or "Could not find an interactable Callboard. Move closer and try again.", true)
        end
        return
    end

    if now() >= pending.nextInteractAt then
        pending.nextInteractAt = now() + 0.4
        tryInteractWithCallboard()
    end
end

local function summonSpellMatches(spellName, arg3, arg4, arg5)
    local spellID = tonumber(arg5) or tonumber(arg4) or tonumber(arg3)
    return spellID == PE.SUMMON_SPELL_ID or spellName == PE.SUMMON_SPELL_NAME
end

local function beginDetectedSummon()
    if routeCount() == 0 then
        return
    end

    if Addon.pendingBoardOpen then
        Addon.pendingBoardOpen.expiresAt = now() + 12
        Addon.pendingBoardOpen.nextInteractAt = now()
        return
    end

    if Addon.running then
        Addon:BeginBoardOpenFlow(false)
        Addon:SetStatus("Manual Callboard summon detected. Opening it for the current route step...", true)
        return
    end

    if Addon:BeginBoardOpenFlow(true) then
        Addon:SetStatus("Manual Callboard summon detected. Opening it and starting the route...", true)
    end
end

local function handleSummonSpellSucceeded(unit, spellName, arg3, arg4, arg5)
    if unit ~= "player" or not summonSpellMatches(spellName, arg3, arg4, arg5) then
        return
    end
    beginDetectedSummon()
end

local function processSummonCooldownTransition()
    if not PE.GetSummonCooldownRemaining then
        return
    end
    local remaining = PE.GetSummonCooldownRemaining()
    local previous = Addon.lastSummonCooldownRemaining
    Addon.lastSummonCooldownRemaining = remaining
    if previous ~= nil and previous <= 0 and remaining > 1 then
        beginDetectedSummon()
    end
end

local function tick()
    if not Addon.initialized then
        return
    end

    processSummonCooldownTransition()
    if UI and UI.UpdateSummonCooldown then
        UI:UpdateSummonCooldown()
    end
    if UI and UI.UpdateStartAction then
        UI:UpdateStartAction()
    end
    if Group and Group.Tick then
        Group:Tick()
    end

    processPendingBoardOpen()

    local boardVisible = PE.IsBoardVisible()
    local boardAccessible = PE.HasBoardAccess and PE.HasBoardAccess() or boardVisible
    if boardVisible and not Addon.lastBoardVisible then
        PE.RequestObjectives()
        Addon.nextObjectiveRequestAt = now() + 1
    end
    Addon.lastBoardVisible = boardVisible

    if Addon.closeBoardAt and now() >= Addon.closeBoardAt then
        Addon.closeBoardAt = nil
        PE.CloseBoard()
    end

    if boardAccessible then
        learnCurrentObjectives()
    end

    if not Addon.running then
        return
    end

    if Addon.waitingKey and updateWaitingState() then
        return
    end

    local key = currentKey()
    if not key then
        Addon.running = false
        Addon:SetStatus("Route complete.", true)
        return
    end

    local _, entry = findQuestInLog(key)
    local activeObjective = PE.GetActiveObjective()
    local activeKey = activeObjective and Core.QuestKey(activeObjective) or nil
    if entry or activeKey == key then
        Addon.waitingKey = key
        Addon.waitingSeenInLog = entry ~= nil
        Addon.waitingSeenActiveObjective = activeKey == key
        Addon.waitingWasComplete = entry and (entry.isComplete == true or tonumber(entry.isComplete) == 1) or false
        updateWaitingState()
        return
    end


    if activeObjective and activeKey and activeKey ~= key then
        Addon:SetStatus("Waiting for the previous active Callboard quest to clear: " .. Core.QuestTitle(activeObjective) .. ".")
        return
    end

    if not boardAccessible then
        Addon:SetStatus("Running step " .. tostring(Addon.profile.currentStep) .. ": " .. questLabel(key) .. ". Open or summon the Callboard.")
        if not Addon.nextRunningBoardInteractAt or now() >= Addon.nextRunningBoardInteractAt then
            Addon.nextRunningBoardInteractAt = now() + 0.4
            if PE.IsCallboardNearby and PE.IsCallboardNearby() then
                tryInteractWithCallboard()
            end
        end
        return
    end
    Addon.nextRunningBoardInteractAt = nil
    processBoard()
end

local function handleQuestDetail()
    local pending = Addon.pendingAccept
    if not pending or now() > pending.expiresAt or not Addon.profile.autoAccept then
        return
    end

    local questID, title = detailQuestIdentity()
    if not questMatchesKey(questID, title, pending.key) then
        return
    end

    if AcceptQuest then
        AcceptQuest()
        Addon:SetStatus("Accepted route quest: " .. questLabel(pending.key) .. ".")
    end
end

local function acceptedQuestID(arg1, arg2)
    local first = tonumber(arg1)
    local second = tonumber(arg2)
    if second and second > 0 then
        return second
    end
    if first and first > 0 then
        local entry = getQuestLogEntry(first)
        if entry and entry.questID then
            return entry.questID
        end
        return first
    end
    return nil
end

local function handleQuestAccepted(arg1, arg2)
    local key = Addon.waitingKey or currentKey()
    if not key then
        return
    end

    local questID = acceptedQuestID(arg1, arg2)
    local questLogIndex, entry = findQuestInLog(key)
    local title = entry and entry.title or nil
    if questMatchesKey(questID, title, key) then
        Addon.waitingKey = key
        Addon.waitingSeenInLog = true
        Addon.waitingSeenActiveObjective = activeObjectiveMatches(key) and true or false
        Addon.pendingAccept = nil
        if Group and Group.QueueAutoShare then
            local quest = questForKey(key)
            Group:QueueAutoShare(
                key,
                questID or (entry and entry.questID) or (quest and Core.QuestID(quest)),
                title or (quest and Core.QuestTitle(quest)) or "",
                questLogIndex
            )
        end
        Addon:SetStatus("Active step " .. tostring(Addon.profile.currentStep) .. ": " .. questLabel(key) .. ".", true)
    end
end

local function handleQuestTurnedIn(questID)
    local key = Addon.waitingKey or currentKey()
    if key and questMatchesKey(questID, nil, key) then
        Addon:AdvanceRoute("QUEST_TURNED_IN")
    end
end

local function handleQuestComplete()
    if not Addon.waitingKey then
        return
    end
    local questID, title = detailQuestIdentity()
    if questMatchesKey(questID, title, Addon.waitingKey) then
        Addon.waitingWasComplete = true
        Addon:AdvanceRoute("QUEST_COMPLETE")
    end
end

local function showHelp()
    Print("/rcb - toggle route builder")
    Print("/rcb start | pause | next | reset | group | share NAME | accept | decline | import | status | help")
end

local function handleSlash(input)
    input = Core.NormalizeTitle(input)
    if input == "" or input == "show" or input == "toggle" then
        UI:Toggle()
    elseif input == "start" then
        Addon:BeginStartFlow()
    elseif input == "pause" or input == "stop" then
        Addon:PauseRoute("Paused by user.")
    elseif input == "next" or input == "advance" then
        Addon:AdvanceRoute("Slash command")
    elseif input == "reset" then
        Addon:ResetRoute()
    elseif input == "group" then
        if UI and UI.ToggleGroupProgress then
            UI:ToggleGroupProgress()
        end
    elseif string.sub(input, 1, 6) == "share " then
        Addon:ShareCurrentRoute(string.sub(input, 7))
    elseif input == "accept" then
        if not Group or not Group.AcceptLatestIncomingRoute or not Group:AcceptLatestIncomingRoute() then
            Addon:SetStatus("No shared route is waiting for acceptance.", true)
        end
    elseif input == "decline" then
        if not Group or not Group.DeclineLatestIncomingRoute or not Group:DeclineLatestIncomingRoute() then
            Addon:SetStatus("No shared route is waiting for a response.", true)
        end
    elseif input == "import" then
        Addon:ImportAutoCallboard()
    elseif input == "status" then
        Print(Addon.statusMessage)
    elseif input == "help" then
        showHelp()
    else
        Print("Unknown command: " .. input)
        showHelp()
    end
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        Addon.db = Core.MergeDatabase(RavioliCallboardDB)
        RavioliCallboardDB = Addon.db

        SLASH_RAVIOLICALLBOARD1 = "/rcb"
        SLASH_RAVIOLICALLBOARD2 = "/raviolicallboard"
        SlashCmdList.RAVIOLICALLBOARD = handleSlash
    elseif event == "PLAYER_LOGIN" then
        initializeProfile()
        local uiReady, uiError = pcall(UI.Create, UI)
        if not uiReady then
            Addon.uiInitError = tostring(uiError or "Unknown UI error")
            if UI and UI.frame then
                UI.frame:Hide()
            end
            Print("UI failed to initialize: " .. Addon.uiInitError)
            return
        end
        Addon.uiInitError = nil
        Addon.initialized = true
        Addon:SetStatus("Ready. Build a route, press Start, then open the Callboard.")
        Print("Ready. Type /rcb to build your quest route.")
        if automationConflict() then
            Print("AutoCallboard is loaded. Import its catalogue, then use /acb toggle before starting a RavioliCallboard route.")
        end
    elseif not Addon.initialized then
        return
    elseif event == "GOSSIP_SHOW" then
        if PE.IsBoardVisible() then
            if PE.MarkBoardAccess then
                PE.MarkBoardAccess(30)
            end
            PE.RequestObjectives()
            Addon.nextObjectiveRequestAt = now() + 1
            if Addon.running then
                Addon.nextActionAt = now() + 0.10
            end
        end
    elseif event == "QUEST_DETAIL" then
        handleQuestDetail()
    elseif event == "QUEST_ACCEPTED" then
        handleQuestAccepted(arg1, arg2)
    elseif event == "QUEST_TURNED_IN" then
        handleQuestTurnedIn(tonumber(arg1))
    elseif event == "QUEST_COMPLETE" then
        handleQuestComplete()
    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_FINISHED" then
        updateWaitingState()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        handleSummonSpellSucceeded(arg1, arg2, arg3, arg4, arg5)
    elseif event == "PLAYER_ENTERING_WORLD" then
        Addon.lastBoardVisible = false
    end
end)

local elapsedSinceTick = 0
eventFrame:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceTick = elapsedSinceTick + (elapsed or 0)
    if elapsedSinceTick < 0.10 then
        return
    end
    elapsedSinceTick = 0
    tick()
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("QUEST_DETAIL")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("QUEST_ACCEPTED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_COMPLETE")
eventFrame:RegisterEvent("QUEST_FINISHED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(eventFrame.RegisterEvent, eventFrame, "QUEST_TURNED_IN")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_SPELLCAST_SUCCEEDED")
