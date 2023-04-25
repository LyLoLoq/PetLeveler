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

local ExpertRiding = awful.NewSpell(34090)

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

local General = ui:Tab("Pets")

General:Text({ text = "How to use" })
General:Text({ text = "Have at least 2 Zandalari pets with level 25" })
General:Text({ text = "Go to Pandaria" })
General:Text({ text = "Go to 26, 44 (/way 26, 44)" })
General:Text({ text = "Make sure to have a favorite pet as a flying mount" })
General:Text({ text = "PS: Works with non flying mount too" })
-- General:Checkbox({
--     text = "",
--     var = "general_draw_player_circle",
--     tooltip = "Will draw the combat reach circle of the player"
-- })

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

local function IsZandalariPetFromPetJournal(index)
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

-- local timeTeam, delayTimeTeam = 0, awful.delay(1, 2)
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

local points = { { x = -9.064600944519043, y = 1775.9498291015625, z = 241.838623046875 },
    { x = 14.844382286071777,  y = 1750.138916015625,  z = 239.5835723876953 },
    { x = 31.6319522857666,    y = 1722.4278564453125, z = 235.72335815429688 },
    { x = 37.309627532958984,  y = 1697.52880859375,   z = 235.55502319335938 },
    { x = 32.51483917236328,   y = 1669.8353271484375, z = 235.4310302734375 },
    { x = 21.58924102783203,   y = 1646.4429931640625, z = 235.5524444580078 },
    { x = 5.141036033630371,   y = 1630.0035400390625, z = 235.71583557128906 },
    { x = -14.736727714538574, y = 1624.0140380859375, z = 235.96070861816406 },
    { x = -33.19443130493164,  y = 1624.43798828125,   z = 236.83615112304688 },
    { x = -51.64878463745117,  y = 1620.0142822265625, z = 235.8026885986328 },
    { x = -69.21536254882813,  y = 1612.4444580078125, z = 236.17063903808594 },
    { x = -83.26188659667969,  y = 1607.7333984375,    z = 235.90151977539063 },
    { x = -99.76460266113281,  y = 1613.592041015625,  z = 235.50950622558594 },
    { x = -116.88923645019531, y = 1614.15380859375,   z = 235.56930541992188 },
    { x = -142.53524780273438, y = 1608.3370361328125, z = 235.90016174316406 },
    { x = -157.7343292236328,  y = 1610.5953369140625, z = 236.98574829101563 },
    { x = -173.0363311767578,  y = 1608.39599609375,   z = 236.4962615966797 },
    { x = -186.53749084472656, y = 1609.385009765625,  z = 236.49671936035156 },
    { x = -187.8578643798828,  y = 1623.2618408203125, z = 236.49671936035156 },
    { x = -182.020263671875,   y = 1637.521728515625,  z = 237.25076293945313 },
    { x = -177.22793579101563, y = 1653.1051025390625, z = 243.66490173339844 },
    { x = -173.6791534423828,  y = 1667.6181640625,    z = 243.9967498779297 },
    { x = -168.58010864257813, y = 1678.7198486328125, z = 241.9978485107422 },
    { x = -146.25790405273438, y = 1680.9102783203125, z = 240.53463745117188 },
    { x = -143.01829528808594, y = 1702.6085205078125, z = 244.5131072998047 },
    { x = -135.18206787109375, y = 1723.5579833984375, z = 243.6057586669922 },
    { x = -122.34901428222656, y = 1743.697265625,     z = 239.97637939453125 },
    { x = -102.9196548461914,  y = 1759.7666015625,    z = 242.19711303710938 },
    { x = -72.31763458251953,  y = 1777.629150390625,  z = 241.7701873779297 },
    { x = -44.56441879272461,  y = 1780.0518798828125, z = 242.7589569091797 },
    { x = -15.549094200134277, y = 1774.9156494140625, z = 241.61068725585938 },
    { x = 8.439135551452637,   y = 1760.690185546875,  z = 239.4760284423828 },
    { x = 27.72260284423828,   y = 1738.2987060546875, z = 237.8439483642578 },
    { x = 38.44088363647461,   y = 1716.5491943359375, z = 235.7870330810547 },
    { x = 41.492000579833984,  y = 1694.905029296875,  z = 235.66941833496094 },
    { x = 39.577396392822266,  y = 1678.6116943359375, z = 236.07533264160156 },
    { x = 34.9979248046875,    y = 1657.685546875,     z = 235.49148559570313 },
    { x = 25.84428596496582,   y = 1641.7100830078125, z = 235.83956909179688 },
    { x = 12.68175983428955,   y = 1629.005859375,     z = 235.62081909179688 },
    { x = -2.136003017425537,  y = 1624.3277587890625, z = 235.95445251464844 },
    { x = -21.14913558959961,  y = 1623.1536865234375, z = 236.21707153320313 },
    { x = -40.42232131958008,  y = 1622.59423828125,   z = 236.1230926513672 },
    { x = -55.992156982421875, y = 1617.3988037109375, z = 236.11705017089844 },
    { x = -70.16481018066406,  y = 1611.758544921875,  z = 236.17062377929688 },
    { x = -82.27399444580078,  y = 1609.6085205078125, z = 235.98171997070313 },
    { x = -97.78848266601563,  y = 1614.0284423828125, z = 235.51133728027344 },
    { x = -110.78910064697266, y = 1621.232421875,     z = 235.51133728027344 },
    { x = -122.18473815917969, y = 1632.6727294921875, z = 236.15232849121094 },
    { x = -133.36117553710938, y = 1646.2099609375,    z = 235.63084411621094 },
    { x= -79.77179718017578, y= 1694.59765625, z= 235.51535034179688 },
    { x= -53.63924789428711, y= 1721.18310546875, z= 235.424072265625 },
    { x= -30.32332992553711, y= 1700.79833984375, z= 236.16441345214844 }
}

if ExpertRiding.known then
    points = {
        { x = -131.83180236816406, y = 1709.742919921875,  z = 244.20372009277344 },
        { x = -105.58808898925781, y = 1730.44970703125,   z = 243.38377380371094 },
        { x = -84.12421417236328,  y = 1751.8062744140625, z = 242.63296508789063 },
        { x = -61.09368896484375,  y = 1789.068603515625,  z = 249.875244140625 },
        { x = -38.833614349365234, y = 1821.541259765625,  z = 232.93324279785156 },
        { x = -18.85279083251953,  y = 1845.2017822265625, z = 210.05130004882813 },
        { x = 14.687411308288574,  y = 1849.7840576171875, z = 200.9446563720703 },
        { x = 44.32094192504883,   y = 1869.5216064453125, z = 194.69338989257813 },
        { x = 71.85079956054688,   y = 1891.697998046875,  z = 187.00192260742188 },
        { x = 103.81781005859375,  y = 1901.179443359375,  z = 182.77947998046875 },
        { x = 144.64561462402344,  y = 1916.552490234375,  z = 179.31605529785156 },
        { x = 174.89675903320313,  y = 1908.00048828125,   z = 179.3667755126953 },
        { x = 182.14007568359375,  y = 1901.8721923828125, z = 180.49862670898438 },
        { x = 204.79151916503906,  y = 1874.003662109375,  z = 190.1284942626953 },
        { x = 215.92247009277344,  y = 1844.039306640625,  z = 204.65841674804688 },
        { x = 209.7032012939453,   y = 1811.9986572265625, z = 226.9759521484375 },
        { x = 191.923828125,       y = 1779.0247802734375, z = 252.53919982910156 },
        { x = 169.21295166015625,  y = 1739.51708984375,   z = 283.1856384277344 },
        { x = 145.34228515625,     y = 1718.0765380859375, z = 296.0733337402344 },
        { x = 113.3151626586914,   y = 1693.1688232421875, z = 295.9013671875 },
        { x = 98.02359008789063,   y = 1666.2523193359375, z = 309.29937744140625 },
        { x = 69.28254699707031,   y = 1644.1048583984375, z = 307.0331115722656 },
        { x = 41.571319580078125,  y = 1655.591064453125,  z = 282.9177551269531 },
        { x = 20.771446228027344,  y = 1652.60888671875,   z = 259.2049865722656 },
        { x = -9.63976001739502,   y = 1640.9931640625,    z = 249.6459503173828 },
        { x = -44.9519157409668,   y = 1633.427490234375,  z = 244.21897888183594 },
        { x = -79.47981262207031,  y = 1622.1195068359375, z = 240.6708984375 },
        { x = -112.89861297607422, y = 1627.370849609375,  z = 240.15138244628906 },
        { x = -135.98072814941406, y = 1652.295166015625,  z = 241.37893676757813 },
        { x = -145.1597442626953,  y = 1684.672119140625,  z = 245.57489013671875 },
        { x = -179.07127380371094, y = 1681.230712890625,  z = 247.3962860107422 },
        { x = -209.78404235839844, y = 1665.573486328125,  z = 241.38134765625 },
        { x = -254.4716796875,     y = 1661.2730712890625, z = 228.6956024169922 },
        { x = -284.6179504394531,  y = 1668.5107421875,    z = 216.39256286621094 },
        { x = -313.7078857421875,  y = 1683.2705078125,    z = 201.94937133789063 },
        { x = -336.6141052246094,  y = 1708.903076171875,  z = 189.90333557128906 },
        { x = -345.056884765625,   y = 1736.9754638671875, z = 180.0364227294922 },
        { x = -333.71685791015625, y = 1770.6763916015625, z = 171.20401000976563 },
        { x = -302.83441162109375, y = 1795.5184326171875, z = 167.4652099609375 },
        { x = -267.3081970214844,  y = 1805.0294189453125, z = 171.35923767089844 },
        { x = -240.84024047851563, y = 1790.2418212890625, z = 185.58900451660156 },
        { x = -216.577880859375,   y = 1770.0179443359375, z = 204.9113006591797 },
        { x = -189.99209594726563, y = 1758.7496337890625, z = 219.65126037597656 },
        { x = -159.24037170410156, y = 1759.740234375,     z = 233.7253875732422 },
        { x = -132.66796875,       y = 1746.8443603515625, z = 244.9572296142578 },
        { x = -126.61276245117188, y = 1720.268798828125,  z = 246.43975830078125 }
    }
end


awful.immerseOL(points)


local lastPoint = points[1]

local function NavigateRoute()
    if nextPetBattle ~= nil then return end
    if not player.mounted then
        awful.alert("Summon mount, no battle available")
        C_MountJournal.SummonByID(0)
        return
    end
    if player.moving or not player.mounted then
        return false
    end
    points.draw()
    for index, value in ipairs(points) do
        if value.passed ~= true then
            local x, y, z = value.x, value.y, value.z
            if awful.player.distanceTo(x, y, z) > 0.1 then
                MoveTo(x, y, z)
            end

            value.passed = true
            lastPoint = value
            break
        end
        if index == #points then
            for index, value in ipairs(points) do
                value.passed = false
            end
        end
    end
end
-- local safePosition = { x = -52.60315704345703, y = 1693.9749755859375, z = 235.41983032226563 }
-- awful.Draw(function(draw)
--     if not ExpertRiding.known then
--         local x1, y1, z1 = player.position()
--         draw:Line(x1, y1, z1, safePosition.x, safePosition.y, safePosition.z)
--         draw:Circle(safePosition.x, safePosition.y, safePosition.z, 100)
--     end
-- end)

awful.onTick(function()
    if not pets.settings.enabled then
        return
    end
    NavigateRoute()
end)

local function distanceToClosestPoint(critter)
    local result = false
    for index, value in ipairs(points) do
        if critter.distanceTo(value.x, value.y, value.z) <= 50 then
            result = true
            break
        end
    end
    return result
end


local timeInteract, delayTimeInteract = 0, awful.delay(1, 3)
local function NavigateToNextBattle()
    if GetPetHealthByIndex(2) == 0 and GetPetHealthByIndex(3) == 0 then
        awful.alert("Team is dead, wait heal spell")
        return
    end

    -- if nextPetBattle == nil then
    local critters = awful.critters.filter(function(critter)
        local count, _, _ = awful.units.around(critter, 25, function(unit)
            return (not unit.friend) and (not unit.dead) and (unit.reaction == 2)
        end)
        if ExpertRiding.known then
            return count == 0 and not critter.dead and awful.call('UnitIsBattlePet', critter.unit) and
                not awful.call('UnitIsBattlePetCompanion', critter.unit)
        else
            return count == 0 and not critter.dead and awful.call('UnitIsBattlePet', critter.unit) and
                not awful.call('UnitIsBattlePetCompanion', critter.unit) and distanceToClosestPoint(critter)
        end
    end)
    if #critters == 0 then
        awful.alert("No battle pets found")
    else
        critters.sort(function(a, b)
            return a and b and a.distance < b.distance
        end)
        nextPetBattle = critters[1]
        awful.alert("Found next battle")
    end

    if nextPetBattle then
        local dist = awful.distance(nextPetBattle)
        if nextPetBattle.dead then
            nextPetBattle = nil
        elseif dist <= 10 then
            awful.StopMoving()
            local x, y, z = nextPetBattle.position()
            MoveTo(x, y, z)
            Dismount()
            if awful.time < timeInteract then
                return
            end
            timeInteract = awful.time + delayTimeInteract.now
            nextPetBattle:interact()
        elseif dist <= 25 then
            local px, py, pz = player.position()
            pz = awful.GroundZ(px, py, pz)
            -- MoveTo(px, py, pz)
            local path = awful.path(player, nextPetBattle)
            path.draw()
            path.follow()
        elseif player.mounted then
            local x, y, z = nextPetBattle.position()
            if type(x) == "number" then
                -- MoveTo(x, y, z)
                local path = awful.path(player, nextPetBattle)
                -- path = path.simplify(1, 1)
                path.draw()
                path.follow()
            end
            return
            -- end
        elseif not player.mounted then
            C_MountJournal.SummonByID(0)
        end
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
    if distanceToGround >= 20 then
        -- awful.alert("Too high")
        AscendStop()
    elseif nextPetBattle == nil and not player.flying and player.mounted and ExpertRiding.known then
        awful.alert("Flying up")
        JumpOrAscendStart()
    elseif nextPetBattle and player.mounted and distanceToGround < 15 and distanceToBattle > 10 and ExpertRiding.known then
        awful.alert("Flying up to pet")
        JumpOrAscendStart()
    end
    if not C_PetBattles.IsInBattle() then
        UseHeal()

        -- if IsCurrentPetDeadOrLevelMAX() then
        SetBattleTeam()
        --     return
        -- end

        if settings.roundNumber ~= nil and settings.roundNumber > 0 then
            nextPetBattle = nil
        end
        firstAttackLevelingPET = false
        settings.roundNumber = 0
        NavigateToNextBattle()
    else
        if awful.time < time then
            return
        end
        time = awful.time + delayTime.now
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
            if settings.roundNumber <= 1 and GetPetHealthByIndex(1) == 0 then
                awful.alert("Pet is dead at round 1, forfeit")
                awful.call("C_PetBattles.ForfeitGame")
            end

            if GetPetHealthByIndex(3) == 0 and GetPetHealthByIndex(2) == 0 then
                awful.alert("Team is dead, forfeit")
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
    if message == ERR_PETBATTLE_NOT_HERE_OBSTRUCTED then
        -- NavigateToNextBattle()
        -- awful.call("StartAttack")
        local x, y, z = nextPetBattle.position()
        MoveTo(x, y, z)
        nextPetBattle:interact()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("UI_ERROR_MESSAGE")
f:SetScript("OnEvent", OnEvent)


C_Timer.After(3, function()
    awful.print("PetLeveler loaded")
    awful.print("/pets to open menu")
    if ExpertRiding.known then
        awful.print("We can fly!")
    else
        awful.print("We can't fly!")
    end
end)

-- awful.Draw(function(draw)
--     if not ExpertRiding.known then
--         points.draw()
--         for index, value in ipairs(points) do
--             -- draw:Line(x1, y1, z1, safePosition.x, safePosition.y, safePosition.z)
--             draw:FilledCircle(value.x, value.y, value.z, 50)
--         end
--     end
-- end)



-- local newPoints = {}
-- cmd:New(function(msg)
--     if string.lower(msg) == "add" then
--         local x, y, z = awful.player.position()
--         -- local obj = { x, y, z }
--         table.insert(newPoints, { x = x, y = y, z = z })
--         Unlocker.Util.File:Write("scripts/awful/routines/PetLeveler/paths.json", Unlocker.Util.JSON:Encode(newPoints), false)
--     end
-- end)
