local Unlocker, awful, pets = ...

-----------------
local C_Timer = _G.C_Timer
local Enum = _G.Enum
local C_PetJournal = _G.C_PetJournal
local C_PetBattles = _G.C_PetBattles
local C_MountJournal = _G.C_MountJournal
local ERR_PETBATTLE_NOT_HERE_OBSTRUCTED = _G.ERR_PETBATTLE_NOT_HERE_OBSTRUCTED
local CreateFrame = _G.CreateFrame
local MoveTo = MoveTo
local date = date
local Dismount = Dismount
local AscendStop = AscendStop
local JumpOrAscendStart = JumpOrAscendStart
-----------------

-- Welcome messages and stuff
C_Timer.After(3, function()
    awful.print("PetLeveler loaded, something is not working? Join discord and let me know")
    awful.print("/pets to open menu")
end)

-- UI
local ui, settings, cmd = awful.UI:New("pets", {
    show = false,
    title = { "Pet Leveler" },
    colors = {
        title = { { 255, 242, 254 }, { 160, 160, 255 } },
        primary = { 160, 160, 255 },
        accent = { 160, 160, 255 },
        background = { 12, 12, 12, 0.6 },
        tertiary = { 161, 161, 161, 0.15 }
    },
    sidebar = false,
    width = 340,
    height = 225,
    scale = 0.9
})

local General = ui:Tab("Pets")

General:Text({ text = "How to use" })
General:Text({ text = "Have at least 2 Zandalari pets with level 25" })
General:Text({ text = "Go to Pandaria" })
General:Text({ text = "Go to 26, 44 (/way 26, 44)" })
General:Text({ text = "Make sure to have a favorite pet as a flying mount" })
General:Text({ text = "PS: Works with non flying mount too" })


local statusFrame = ui:StatusFrame({
    colors = {
        background = { 0, 0, 0, 0 },
        enabled = { 200, 200, 255, 1 },
    },
    maxWidth = 450
})
statusFrame:Button({
    spellId = 214556,
    var = "enabled",
    onClick = function()
        if settings.enabled then
            awful.print("Pet leveling enabled at: " .. date())
        else
            awful.print("Pet leveling Disabled at: " .. date())
        end
    end,
    size = 35,
})
local debugFrame = ui:StatusFrame({
    colors = {
        background = { 0, 0, 0, 0 },
    },
    maxWidth = 450
})
debugFrame:String({
    text = "Round",
    var = "roundNumber"
})
debugFrame:String({
    text = "Time stuck",
    var = "timeStuck"
})
if settings.debugPets then
    debugFrame:Show()
else
    debugFrame:Hide()
end


-- Commands
-- local newPoints = Unlocker.Util.JSON:Decode(Unlocker.Util.File:Read("scripts/awful/routines/PetLeveler/paths.json"))
-- awful.immerseOL(newPoints)
-- cmd:New(function(msg)
--     if string.lower(msg) == "add" then
--         local x, y, z = awful.player.position()
--         -- local obj = { x, y, z }
--         table.insert(newPoints, { x = x, y = y, z = z, radius = 5 })
--         Unlocker.Util.File:Write("scripts/awful/routines/PetLeveler/paths.json", Unlocker.Util.JSON:Encode(newPoints), false)
--     elseif string.lower(msg) == "pegadinha" then
--         settings.debugPets = not settings.debugPets
--         if settings.debugPets then
--             debugFrame:Show()
--         else
--             debugFrame:Hide()
--         end
--     end
-- end)


local ExpertRiding = awful.NewSpell(34090)

local points = pets.flyingPoints
if not ExpertRiding.known then
    awful.alert("It seems you can't fly, will use only ground path")
    points = pets.groundPoint
else
    awful.alert("We can fly, will use flying path")
end

awful.Draw(function(draw)
    -- newPoints:draw()
    if settings.debugPets then
        for index, value in ipairs(points) do
            draw:Circle(value.x, value.y, value.z, 2)
            local font = awful.createFont(10)
            draw:Text(index, font, value.x, value.y, value.z + 5)
        end
    end
    -- for index, value in ipairs(newPoints) do
    --     draw:Circle(value.x, value.y, value.z, 2)
    --     local font = awful.createFont(10)
    --     draw:Text(index, font, value.x, value.y, value.z + 5)
    -- end
end)

-- Global vars
local nextPetBattle = nil
local shouldNavigateToReset = false
local actionSelected = false
local firstAttackLevelingPET = false
local player = awful.player
local states = {
    [1] = 'LE_PET_BATTLE_STATE_CREATED',
    [2] = 'LE_PET_BATTLE_STATE_WAITING_PRE_BATTLE',
    [3] = 'LE_PET_BATTLE_STATE_ROUND_IN_PROGRESS',
    [4] = 'LE_PET_BATTLE_STATE_WAITING_FOR_ROUND_PLAYBACK',
    [5] = 'LE_PET_BATTLE_STATE_WAITING_FOR_FRONT_PETS',
    [6] = 'LE_PET_BATTLE_STATE_CREATED_FAILED',
    [7] = 'LE_PET_BATTLE_STATE_FINAL_ROUND',
    [8] = 'LE_PET_BATTLE_STATE_FINISHED'
}
local statesEnum = {
    LE_PET_BATTLE_STATE_CREATED = 1,
    LE_PET_BATTLE_STATE_WAITING_PRE_BATTLE = 2,
    LE_PET_BATTLE_STATE_ROUND_IN_PROGRESS = 3,
    LE_PET_BATTLE_STATE_WAITING_FOR_ROUND_PLAYBACK = 4,
    LE_PET_BATTLE_STATE_WAITING_FOR_FRONT_PETS = 5,
    LE_PET_BATTLE_STATE_CREATED_FAILED = 6,
    LE_PET_BATTLE_STATE_FINAL_ROUND = 7,
    LE_PET_BATTLE_STATE_FINISHED = 8
}

-- Events
local function OnEvent(self, _, _, message)
    if message == ERR_PETBATTLE_NOT_HERE_OBSTRUCTED then
        local x, y, z = nextPetBattle.position()
        MoveTo(x, y, z)
        nextPetBattle:interact()
        -- error("figure out what to do")
        awful.alert("Obstructed path to pet, moving towards the pet")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("UI_ERROR_MESSAGE")
f:SetScript("OnEvent", OnEvent)

awful.onEvent(function(_, _, localRoundNumber)
    settings.roundNumber = localRoundNumber
    actionSelected = false
end, "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")

awful.onEvent(function(_, _)
    actionSelected = true
end, "PET_BATTLE_ACTION_SELECTED")

-- Functions
local ox, oy, oz = awful.player.position()
local lastMovement = awful.time
local function playerTimeStandingStill()
    local px, py, pz = player.position()
    local distance = awful.distance(ox, oy, oz, px, py, pz)
    if distance <= 2 then
        return awful.time - lastMovement
    else
        lastMovement = awful.time
        ox, oy, oz = player.position()
        return awful.time - lastMovement
    end
end
local function IsAbilityUsable(index)
    if type(index) ~= "number" then
        error("Number expected but received: " .. type(index))
    end

    local isUsable = C_PetBattles.GetAbilityState(Enum.BattlePetOwner.Ally, C_PetBattles.GetActivePet(Enum.BattlePetOwner.Ally), index);
    return isUsable
end

local function IsAllActionsDisabled()
    local isUsable1 = IsAbilityUsable(1);
    local isUsable2 = IsAbilityUsable(2);
    local isUsable3 = IsAbilityUsable(3);
    if not isUsable1 and not isUsable2 and not isUsable3 then
        return true
    end
end

local function GetPetHealthByIndex(index)
    if type(index) ~= "number" then
        error("Number expected but received: " .. type(index))
    end
    if not C_PetBattles.IsInBattle() then
        local petID, ability1ID, ability2ID, ability3ID, locked = C_PetJournal.GetPetLoadOutInfo(index);
        local health, maxHealth, attack, speed, rarity = C_PetJournal.GetPetStats(petID);
        return health
    else
        return C_PetBattles.GetHealth(1, index)
    end
end

local function GetPetMaxHealthByIndex(index)
    if type(index) ~= "number" then
        error("Number expected but received: " .. type(index))
    end
    local petID, ability1ID, ability2ID, ability3ID, locked = C_PetJournal.GetPetLoadOutInfo(index);
    local health, maxHealth, attack, speed, rarity = C_PetJournal.GetPetStats(petID);
    return maxHealth
end

local function IsZandalariPetFromPetJournal(index)
    if type(index) ~= "number" then
        error("Number expected but received: " .. type(index))
    end
    local petID, speciesID, _, _, level, _, _, name = C_PetJournal.GetPetInfoByIndex(index)
    -- 1180: Zandalari Kneebiter
    -- 1211: Zandalari Anklerender
    -- 1212: Zandalari Footslasher
    -- 1213: Zandalari Toenibbler
    if speciesID == 1180 or speciesID == 1211 or speciesID == 1212 or speciesID == 1213 then
        return true
    end
    return false
end

local function IsZandalariPetFromPetTeam(index)
    if type(index) ~= "number" then
        error("Number expected but received: " .. type(index))
    end
    local petGUID = C_PetJournal.GetPetLoadOutInfo(index);
    local speciesID = select(1, C_PetJournal.GetPetInfoByPetID(petGUID))
    -- 1180: Zandalari Kneebiter
    -- 1211: Zandalari Anklerender
    -- 1212: Zandalari Footslasher
    -- 1213: Zandalari Toenibbler
    if speciesID == 1180 or speciesID == 1211 or speciesID == 1212 or speciesID == 1213 then
        return true
    end
    return false
end

local function IsCurrentPetDeadOrLevelMAX()
    local petGUID = C_PetJournal.GetPetLoadOutInfo(1)
    local _, _, level = C_PetJournal.GetPetInfoByPetID(petGUID)
    if level == 25 then
        awful.alert("Changing team, level 25")
        return true
    end
    if GetPetHealthByIndex(1) == 0 then
        awful.alert("Changing team, cant battle")
        return true
    end
end

local function SetBattleTeam()
    local _, ownedPets = C_PetJournal.GetNumPets()
    for index = 1, ownedPets do
        local petID, _, _, _, level, _, _, name = C_PetJournal.GetPetInfoByIndex(index)
        local health = C_PetJournal.GetPetStats(petID);
        local canBattle = health > 0

        if IsZandalariPetFromPetJournal(index) then
            if not IsZandalariPetFromPetTeam(2) and level == 25 then
                awful.alert('Setting new team Zandalari 2')
                C_PetJournal.SetPetLoadOutInfo(2, petID)
            elseif not IsZandalariPetFromPetTeam(3) and level == 25 then
                awful.alert('Setting new team Zandalari 3')
                C_PetJournal.SetPetLoadOutInfo(3, petID)
            end
        elseif IsCurrentPetDeadOrLevelMAX() then
            if canBattle and level < 25 then
                awful.alert('Setting new team')
                C_PetJournal.SetPetLoadOutInfo(1, petID)
                return
            end
            if index == ownedPets then
                awful.alert('No pets that can battle and are under level 25 found')
                return
            end
        end
    end
end

local function Travel(path)
    if type(path) ~= "table" then
        error("Table expected but received: " .. type(path))
    end
    if #path < 1 then
        return
    end
    path.loop(function(p, i)
        local x, y, z = p.x, p.y, p.z
        if i == #path then
            if player.distanceTo(x, y, z) <= 0.5 then
                awful.StopMoving()
            end
        end
        if x and y and z and player.distanceTo(x, y, z) > 0.5 then
            if not pets.lastMoveTime then
                pets.lastMoveTime = awful.time
            elseif awful.time - pets.lastMoveTime < 0.075 then
                return true
            else
                pets.lastMoveTime = awful.time
            end
            MoveTo(x, y, z)
            return true
        end
    end)
end

local function Navigate(x, y, z)
    if type(x) ~= "number" then
        error("Number expected but received: " .. type(x))
    end
    if type(y) ~= "number" then
        error("Number expected but received: " .. type(y))
    end
    if type(z) ~= "number" then
        error("Number expected but received: " .. type(z))
    end
    local px, py, pz = player.position()
    local gx, gy, gz = awful.GroundZ(px, py, pz)
    local distanceToGround = awful.distance(px, py, pz, gx, gy, gz)
    local path = awful.path(player, x, y, z)
    if player.distanceToLiteral(x, y, z) > 15 then
        if not player.mounted then
            C_MountJournal.SummonByID(0)
        elseif ExpertRiding.known and not player.flying then
            if distanceToGround >= 20 then
                AscendStop()
            else
                JumpOrAscendStart()
            end
            Travel(path)
        else
            Travel(path)
        end
    else
        Travel(path)
    end
end

local function ResetPath()
    for index, value in ipairs(points) do
        value.passed = false
    end
end

local ResetPoint = { { x = -39.34432601928711, y = 1679.0621337890625, z = 235.57008361816406 } }
awful.immerseOL(ResetPoint)
local function Unstuck()
    -- Check for stuck
    settings.timeStuck = playerTimeStandingStill()
    if not shouldNavigateToReset and settings.timeStuck >= 10 then
        shouldNavigateToReset = true
    end
    if shouldNavigateToReset then
        ResetPoint.draw()
        ResetPoint.follow()
        ox, oy, oz = ResetPoint[1].x, ResetPoint[1].y, ResetPoint[1].z
        local px, py, pz = player.position()
        local distance = awful.distance(ox, oy, oz, px, py, pz)
        if distance <= 2 then
            shouldNavigateToReset = false
        end
    end
end

local function NavigateRoute()
    if player.moving and not player.flying then
        return false
    end
    for index, value in ipairs(points) do
        if not value.passed then
            local x, y, z = value.x, value.y, value.z
            if awful.player.distanceTo(x, y, z) > 0.1 then
                -- MoveTo(x, y, z)
                Navigate(x, y, z)
            end
            value.passed = true
            break
        end
        if index == #points then
            ResetPath()
        end
    end
end


-- Winding number algorithm
local function isCritterInsidePolygon(critter)
    local x, y = critter.position()

    local wn = 0
    for i = 1, #points do
        local p1 = points[i]
        local p2 = points[(i % #points) + 1]
        if p1.y <= y then
            if p2.y > y and (p2.x - p1.x) * (y - p1.y) > (x - p1.x) * (p2.y - p1.y) then
                wn = wn + 1
            end
        else
            if p2.y <= y and (p2.x - p1.x) * (y - p1.y) < (x - p1.x) * (p2.y - p1.y) then
                wn = wn - 1
            end
        end
    end
    return wn ~= 0
end

local function UseHeal()
    local maxHealth1 = GetPetMaxHealthByIndex(1)
    local maxHealth2 = GetPetMaxHealthByIndex(2)
    local maxHealth3 = GetPetMaxHealthByIndex(3)
    local health1 = GetPetHealthByIndex(1)
    local health2 = GetPetHealthByIndex(2)
    local health3 = GetPetHealthByIndex(3)
    if (health1 + health2 + health3) / (maxHealth1 + maxHealth2 + maxHealth3) <= 0.5 then
        awful.alert("Using heal")
        CastSpellByID(125439)
    end
end

local function SetNextBattle()
    nextPetBattle = nil
    local critters = awful.critters.filter(function(critter)
        local count, _, _ = awful.units.around(critter, 25, function(unit)
            return (not unit.friend) and (not unit.dead) and (unit.reaction == 2)
        end)
        if ExpertRiding.known then
            return count == 0 and not critter.dead and awful.call('UnitIsBattlePet', critter.unit) and
                not awful.call('UnitIsBattlePetCompanion', critter.unit)
        else
            return count == 0 and not critter.dead and awful.call('UnitIsBattlePet', critter.unit) and
                not awful.call('UnitIsBattlePetCompanion', critter.unit) and isCritterInsidePolygon(critter)
        end
    end)
    if #critters == 0 then
        awful.alert("No battle pets found")
    else
        critters.sort(function(a, b)
            return a and b and a.distance < b.distance
        end)
        nextPetBattle = critters[1]
        nextPetBattle.setTarget()
        awful.alert("Found next battle")
    end
end

local timeInteract, delayTimeInteract = 0, awful.delay(1, 3)
local function NavigateToNextBattle()
    if nextPetBattle then
        local x, y, z = nextPetBattle.position()
        Navigate(x, y, z)
        local dist = awful.distance(nextPetBattle)
        if dist <= 10 then
            awful.StopMoving()
            Dismount()
            if awful.time < timeInteract then
                return
            end
            timeInteract = awful.time + delayTimeInteract.now
            nextPetBattle:interact()
        end
    end
end

local function ChangePet()
    if GetPetHealthByIndex(2) == 0 then
        awful.call("C_PetBattles.ChangePet", 3)
    end
    if GetPetHealthByIndex(3) == 0 then
        awful.call("C_PetBattles.ChangePet", 2)
    end
end

local function Battle()
    local battleState = C_PetBattles.GetBattleState()
    settings.battleState = states[battleState]
    if battleState == statesEnum.LE_PET_BATTLE_STATE_ROUND_IN_PROGRESS then
        if IsAllActionsDisabled() and not actionSelected then
            awful.alert("All abilities disabled, skiping turn")
            awful.call("C_PetBattles.SkipTurn")
        elseif settings.roundNumber == 0 then
            awful.alert("Round number 0: Using first attack")
            firstAttackLevelingPET = true
            awful.call("C_PetBattles.UseAbility", 1)
        elseif settings.roundNumber >= 1 then
            awful.alert("Round number " .. settings.roundNumber)
            local index = C_PetBattles.GetActivePet(Enum.BattlePetOwner.Ally)

            if GetPetHealthByIndex(index) == 0 then
                if GetPetHealthByIndex(1) == 0 and GetPetHealthByIndex(2) == 0 then
                    awful.alert("DEAD Changin to pet 3")
                    awful.call("C_PetBattles.ChangePet", 3)
                elseif GetPetHealthByIndex(1) == 0 and GetPetHealthByIndex(3) == 0 then
                    awful.alert("DEAD Changin to pet 2")
                    awful.call("C_PetBattles.ChangePet", 2)
                elseif GetPetHealthByIndex(2) == 0 and GetPetHealthByIndex(3) == 0 then
                    awful.alert("DEAD Changin to pet 1")
                    awful.call("C_PetBattles.ChangePet", 1)
                end
            elseif firstAttackLevelingPET and index == 1 and (GetPetHealthByIndex(2) > 0 or GetPetHealthByIndex(3) > 0) then
                -- BUG from blizz
                if C_PetBattles.GetActivePet(Enum.BattlePetOwner.Ally) == 1 and settings.roundNumber >= 2 then
                    awful.alert("HMM")
                    awful.call("C_PetBattles.ForfeitGame")
                end
                if GetPetHealthByIndex(2) > 0 then
                    awful.alert("FIRST ATTACK DONE Changin to pet 2")
                    awful.call("C_PetBattles.ChangePet", 2)
                elseif GetPetHealthByIndex(3) > 0 then
                    awful.alert("FIRST ATTACK DONE Changin to pet 3")
                    awful.call("C_PetBattles.ChangePet", 3)
                end
            else
                local activeEnemyPetIndex = C_PetBattles.GetActivePet(2)
                local enemyHealth = C_PetBattles.GetHealth(2, activeEnemyPetIndex)
                if enemyHealth <= 500 then
                    if IsAbilityUsable(3) then
                        awful.alert("Using ability 3 (KILL)")
                        awful.call("C_PetBattles.UseAbility", 3)
                    end
                end
                if IsAbilityUsable(1) and not actionSelected then
                    awful.alert("Using ability 1")
                    awful.call("C_PetBattles.UseAbility", 1)
                end
            end
        end
    elseif battleState == statesEnum.LE_PET_BATTLE_STATE_WAITING_FOR_ROUND_PLAYBACK then
        if settings.roundNumber <= 1 and GetPetHealthByIndex(1) == 0 then
            awful.alert("Pet is dead at round 1, forfeit")
            awful.call("C_PetBattles.ForfeitGame")
        end

        if GetPetHealthByIndex(3) == 0 and GetPetHealthByIndex(2) == 0 then
            awful.alert("Team is dead, forfeit")
            awful.call("C_PetBattles.ForfeitGame")
        end
        ChangePet()

        if GetPetHealthByIndex(1) == 0 and settings.roundNumber > 1 then
            ChangePet()
        end
    end
    shouldNavigateToReset = false
    lastMovement = awful.time
    ox, oy, oz = player.position()
end



local time, delayTime = 0, awful.delay(0, 3)
awful.onTick(function()
    if not settings.enabled or player.channeling or player.casting then
        return
    end
    if C_PetBattles.IsInBattle() then
        if awful.time < time then
            return
        end
        time = awful.time + delayTime.now
        Battle()
    else
        SetNextBattle()
        firstAttackLevelingPET = false
        settings.roundNumber = 0
        UseHeal()
        SetBattleTeam()
        if GetPetHealthByIndex(2) == 0 and GetPetHealthByIndex(3) == 0 then
            awful.alert("Team is dead, wait heal spell")
            return
        end
        Unstuck()
        if not shouldNavigateToReset then
            NavigateToNextBattle()
            NavigateRoute()
        end
    end
end)



-- AntiAFK
local time, delay = 0, awful.delay(30, 60)
awful.onTick(function()
    if awful.time > time then
        time = awful.time + delay.now
        if ResetAfk then
            ResetAfk()
        elseif SetLastHardwareActionTime then
            SetLastHardwareActionTime(awful.time*1000)
        elseif LastHardwareAction then
            LastHardwareAction(awful.time * 1000)
        end
    end
end)