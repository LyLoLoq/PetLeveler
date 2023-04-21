---@type Unlocker, Awful
local Unlocker, awful, pets = ...

---@type C_PetBattles
local C_PetBattles = _G.C_PetBattles
---@type C_PetJournal
local C_PetJournal = _G.C_PetJournal
---@type Enum
local Enum = _G.Enum
local CastSpellByID = awful.unlock("CastSpellByID")
--


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

pets.settings = settings

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
        -- pets.settings.on = not pets.settings.on
        awful.print(pets.settings.enabled and "Pet leveling enabled" or "Pet leveling disabled")
    end,
    size = 35,
})

-- EVENTS
local actionSelected = false

awful.onEvent(function(_, _, localRoundNumber)
    settings.roundNumber = localRoundNumber
    actionSelected = false
end, "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")

awful.onEvent(function(_, _)
    actionSelected = true
end, "PET_BATTLE_ACTION_SELECTED")

-- VARS
local player = awful.player
local nextPetBattle = nil
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


local function GetPetHealthByIndex(index)
    if not C_PetBattles.IsInBattle() then
        local petID, ability1ID, ability2ID, ability3ID, locked = C_PetJournal.GetPetLoadOutInfo(index);
        local health, maxHealth, attack, speed, rarity = C_PetJournal.GetPetStats(petID);
        return health
    else
        return C_PetBattles.GetHealth(1, index)
    end
end

local function GetPetMaxHealthByIndex(index)
    local petID, ability1ID, ability2ID, ability3ID, locked = C_PetJournal.GetPetLoadOutInfo(index);
    local health, maxHealth, attack, speed, rarity = C_PetJournal.GetPetStats(petID);
    return maxHealth
end

local function SetBattleTeam()
    C_PetJournal.SetPetLoadOutInfo(2, 'BattlePet-0-0000213CAFCB')
    C_PetJournal.SetPetLoadOutInfo(3, 'BattlePet-0-0000213CAFCA')
    local _, ownedPets = C_PetJournal.GetNumPets()
    for index = 1, ownedPets do
        local petID, _, _, _, level = C_PetJournal.GetPetInfoByIndex(index)
        local health = C_PetJournal.GetPetStats(petID);
        local canBattle = health > 0

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

local function IsAbilityUsable(index)
    local isUsable = C_PetBattles.GetAbilityState(Enum.BattlePetOwner.Ally,
        C_PetBattles.GetActivePet(Enum.BattlePetOwner.Ally), index);
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

local function NavigateRoute()
end

local function NavigateToNextBattle()
    if GetPetHealthByIndex(2) == 0 and GetPetHealthByIndex(3) == 0 then
        awful.alert("Team is dead, wait heal spell")
        return
    end

    local dist = awful.distance(nextPetBattle)
    if nextPetBattle == nil then
        local pets = awful.critters.filter(function(unit)
            return not unit.dead and awful.call('UnitIsBattlePet', unit.unit) and
                not awful.call('UnitIsBattlePetCompanion', unit.unit)
        end)
        if #pets == 0 then
            awful.alert("No battle pets found")
        else
            pets.sort(function(a, b)
                return a and b and a.distance < b.distance
            end)
            nextPetBattle = pets[1]
            awful.alert("Found next battle")
        end
    elseif dist <= 10 then
        local px, py, pz = player.position()
        pz = awful.GroundZ(px, py, pz)
        MoveTo(px, py, pz)
        Dismount()
        nextPetBattle:interact()
    elseif player.mounted then
        -- if not player.flying then
        --     JumpOrAscendStart()
        --     awful.alert("Flying")
        --     C_Timer.After(0.5, function()
        --         awful.StopMoving()
        --     end)
        -- else
            local x, y, z = nextPetBattle.position()
            if type(x) == "number" then
                MoveTo(x, y, z)
            end

            return
        -- end
    else
        C_MountJournal.SummonByID(0)
    end
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

local firstAttackLevelingPET = false

local time, delayTime = 0, awful.delay(0, 3)
awful.addUpdateCallback(function()
    if not pets.settings.enabled then
        if awful.AntiAFK.enabled then
            awful.AntiAFK:Disable()
        end
        
        return
    end
    if not awful.AntiAFK.enabled then
        awful.AntiAFK:Enable()
    end
    local px, py, pz = player.position()
    local gx, gy, gz = awful.GroundZ(px, py, pz)
    local distanceToGround = awful.distance(px, py, pz, gx, gy, gz)
    local distanceToBattle = awful.distance(nextPetBattle)
    if distanceToGround >= 10 then
        -- awful.alert("Too high")
        AscendStop()
    elseif player.mounted and distanceToGround < 8 and distanceToBattle > 10 then
        JumpOrAscendStart()
    end
    if awful.time < time then
        return
    end
    time = awful.time + delayTime.now
    if not C_PetBattles.IsInBattle() then
        UseHeal()

        if IsCurrentPetDeadOrLevelMAX() then
            SetBattleTeam()
            return
        end

        if settings.roundNumber > 0 then
            nextPetBattle = nil
        end
        firstAttackLevelingPET = false
        settings.roundNumber = 0
        NavigateToNextBattle()
    else
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
            if GetPetHealthByIndex(3) == 0 and GetPetHealthByIndex(2) == 0 then
                awful.call("C_PetBattles.ForfeitGame")
            end
            if GetPetHealthByIndex(2) == 0 then
                awful.call("C_PetBattles.ChangePet", 3)
            end
            if GetPetHealthByIndex(3) == 0 then
                awful.call("C_PetBattles.ChangePet", 2)
            end
        end
    end
end)

local function OnEvent(self, event, errorType, message)
    if message == ERR_OUT_OF_RANGE then
        print(message)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("UI_ERROR_MESSAGE")
f:SetScript("OnEvent", OnEvent)


-- if not IsMounted() then
--     C_MountJournal.SummonByID(0)
-- end
-- if not awful.player.moving then
--     local px, py, pz = awful.player.position()
--     if not IsFlying() then
--         local path = awful.path(awful.player, px, py, pz + 10)
--         path = path.simplify(1, 1)
--         path.follow()
--         return
--     end


--     if nextPetBattle == nil then
--         nextPetBattle = awful.critters.find(function(unit)
--             return awful.call('UnitIsBattlePet', unit.unit) and not awful.call('UnitIsBattlePetCompanion', unit.unit)
--         end)
--     end
--     if nextPetBattle and not nextPetBattle.exists then
--         print('not exists', nextPetBattle.exists)
--         nextPetBattle = nil
--     end
--     if IsFlying() and nextPetBattle then
--         local tx, ty, tz = nextPetBattle.position()
--         print(awful.distance(px,py,pz, tx, ty, tz))
--         if awful.distance(px,py,pz, tx, ty, tz)<= 4.5 then
--             awful.protected.RunMacroText("/dismount")
--         else
--             local path = awful.path(awful.player, nextPetBattle)
--             path = path.simplify()
--             path.follow()
--             return
--         end
--     end
-- end

-- -------------------

-- Bite: 110
-- Leap: 364
-- Devour: 538
-- Bloodfang: 917




-- FLIGHT

-- local points = {}
-- awful.Draw(function(draw)
--     draw:SetColor(255, 198, 74, 90)
--     for index, point in ipairs(points) do
--         draw:Circle(point.x, point.y, point.z, 5)
--         if points[index + 1] ~= nil then
--             draw:Line(point.x, point.y, point.z, points[index + 1].x, points[index + 1].y, points[index + 1].z, 20)
--         end
--     end
-- end)



-- local lastIndex = -1

-- -- Function to move character to a point and wait for arrival
-- local function moveToAndWait(point, index)
--     local x, y, z = point.x,point.y,point.z
--     MoveTo(x, y, z)

--     while true do
--         local px, py, pz = awful.player.position()
--         local distance = sqrt((x - px)^2 + (y - py)^2 + (z - pz)^2)
--         if distance < 2.0 then -- 2 yards tolerance for arrival
--             if index == #points then
--                 print('resseting')
--                 lastIndex = -1
--             end
--             break
--         end
--         coroutine.yield()
--     end
-- end

-- -- Move character to each point in the set
-- local co = coroutine.create(function ()
--     for index, point in ipairs(points) do
--         moveToAndWait(point, index)
--         coroutine.yield() -- wait for a short delay between each move
--     end
-- end)

-- local delay = 0 -- delay in seconds between each move
-- local timer = 0

-- -- Update function to resume coroutine after delay
-- local function onUpdate(self, elapsed)
--     if lastIndex < 0 then
--         return
--     end
--     timer = timer + elapsed
--     if timer > delay then
--         timer = timer - delay
--         coroutine.resume(co)
--     end
-- end

-- -- Register update function to run every frame
-- local frame = CreateFrame("Frame")
-- frame:SetScript("OnUpdate", onUpdate)

-- cmd:New(function(msg)
--     if string.lower(msg) == "add" then
--         local x, y, z = awful.player.position()
--         table.insert(points, { x = x, y = y, z = z })
--     elseif string.lower(msg) == "follow" then
--         print('starting')
--         lastIndex = 0
--         -- frame:SetScript("OnUpdate", nil)
--     end
-- end)




local function writeEnumToFile()
    Tinkr.Util.File:Write("scripts/awful/routines/Teste/types/wow/Enum.lua", "---@meta\n---@class Enum", false)
    for key, value in pairs(Enum) do
        for key2, value2 in pairs(value) do
            Tinkr.Util.File:Write("scripts/awful/routines/Teste/types/wow/Enum.lua",
                "\n---@field " .. key .. "." .. key2 .. " unknown", true)
        end
    end
end
