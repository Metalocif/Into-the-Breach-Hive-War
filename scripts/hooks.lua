-- Where all the magic happens

local Wolf_MineTiles = {}

-- Enable this for log messages
local logging = false

-- master table from which HW statistics are copied, make any balance changes you want here
local MasterStatsHW = {
	Sector1 = {
		Move = 3,
		Health = 5,
		ReaveDmg = 2,
		BioDmg = 1,
		BioRange = 1,
	},
	Sector2 = {
		Move = 3,
		Health = 6,
		ReaveDmg = 2,
		BioDmg = 1,
		BioRange = 2,
	},
	Sector3 = {
		Move = 4,
		Health = 6,
		ReaveDmg = 3,
		BioDmg = 2,
		BioRange = 2,
	},
	Sector4 = {
		Move = 4,
		Health = 7,
		ReaveDmg = 3,
		BioDmg = 2,
		BioRange = 3,
	},
}
		
local function onLoad()
	if Game then
		GAME.HW_WarriorStats = copy_table(MasterStatsHW)
		Wolf_UpdateHiveWarriorSprite()
	end
end

local function EvoCheck(evo)
	if GAME.HW_Evolutions ~= nil then
		for _,v in pairs(GAME.HW_Evolutions) do
			if v == evo then
				return true
			end
		end
	end
	return false
end

function Wolf_UpdateHiveWarriorSprite()
	if not Game then return end

	local result = "HiveWarrior"
	local evo1 = GAME.HW_Evolutions[1]
	local evo2 = GAME.HW_Evolutions[2]
	local evo3 = GAME.HW_Evolutions[3]
	
	if evo1 == "A" or evo1 == "D" then
		result = result..evo1
	elseif evo2 == "A" or evo2 == "D" then
		result = result..evo2
	elseif evo3 == "A" or evo3 == "D" then
		result = result..evo3
	end
	
	if evo1 == "C" or evo1 == "M" then
		result = result..evo1
	elseif evo2 == "C" or evo2 == "M" then
		result = result..evo2
	elseif evo3 == "C" or evo3 == "M" then
		result = result..evo3
	end
	
	if evo1 == "F" or evo1 == "W" then
		result = result..evo1
	elseif evo2 == "F" or evo2 == "W" then
		result = result..evo2
	elseif evo3 == "F" or evo3 == "W" then
		result = result..evo3
	end
	
	if evo1 == "V" or evo1 == "R" then
		result = result..evo1
	elseif evo2 == "V" or evo2 == "R" then
		result = result..evo2
	elseif evo3 == "V" or evo3 == "R" then
		result = result..evo3
	end
	
	HiveWarrior.Image = result
	HiveWarriorFinal.Image = result.."Final"
end
--[[
local function UpdateWarriorWeapons()
	if EvoCheck("R") then
		for _, pawn in pairs(_G) do
			if type(pawn) == "table" and pawn == HiveWarrior then
				pawn.SkillList = { "Wolf_ReflexReave", "Wolf_Biocannon" }
				if logging then LOG(save_table(pawn.SkillList)) end
			end
			if type(pawn) == "table" and pawn == HiveWarriorFinal then
				pawn.SkillList = { "Wolf_ReflexReave", "Wolf_Biocannon" }
			end
		end
	else
		for _, pawn in pairs(_G) do
			if type(pawn) == "table" and pawn == HiveWarrior then
				pawn.SkillList = { "Wolf_Reave", "Wolf_Biocannon" }
				if logging then LOG(save_table(pawn.SkillList)) end
			end
			if type(pawn) == "table" and pawn == HiveWarriorFinal then
				pawn.SkillList = { "Wolf_Reave", "Wolf_Biocannon" }
			end
		end
	end
end
--]]

local trait = require(mod_loader.mods[modApi.currentMod].scriptPath..'trait')

local HW_AdaptiveTrait = function(trait,pawn)
	--Adaptive if Hive Warrior with the right evo, or if passive equipped, or if upgraded passive on any mech.
	if not pawn then return false end
	if (pawn:GetType() == "HiveWarrior" or pawn:GetType() == "HiveWarriorFinal") and EvoCheck("D") then return true end
	if Wolf_HasPoweredWeapon(pawn, "Passive_Adaptation", false) then return true end
	for i = 0, 2 do
		if pawn:IsMech() and Board:GetPawn(i) and not Board:GetPawn(i):IsDead() and Wolf_HasPoweredWeapon(Board:GetPawn(i), "Passive_Adaptation", true) then
			return true
		end
	end
	return false
end
modApi:appendAsset("img/effects/icon_adapt.png", mod_loader.mods[modApi.currentMod].resourcePath.."resources/effects/icon_adapt.png")
modApi:appendAsset("img/effects/icon_adapt_glow.png", mod_loader.mods[modApi.currentMod].resourcePath.."resources/effects/icon_adapt_glow.png")
Location["img/effects/icon_adapt.png"] = Point(-3,24)
Location["img/effects/icon_adapt_glow.png"] = Point(-3,24)
trait:add{
	func = HW_AdaptiveTrait,
	icon = "img/effects/icon_adapt.png",
	icon_glow = "img/effects/icon_adapt_glow.png",
	-- icon_offset = Point(-3,24),
	desc_title = "Adaptive",
	desc_text = "Will clear all negative status at the start of every turn.",
}

local function pawnPositionChangedHook(mission, pawn, oldPosition)
	if pawn and _G[pawn:GetType()].Name == "Hive Warrior" then GAME.HW_WarriorLoc = pawn:GetSpace() end
	trait:update(pawn:GetSpace())
end


local function BreachWarrior(pod)
	-- scan spaces adjacent to pod for valid placement
	-- spawn the Hive Warrior pawn
	
	if pod == nil then return end
	
	local island = GetSector()
	local list = {1, 2, 3, 4, 5, 6, 7, 8}
	
	for i, v in ipairs(list) do
		for dir = DIR_START, DIR_END do
			tick = v
			target = pod
			while tick > 0 do
				target = target + DIR_VECTORS[dir]
				tick = tick - 1
			end
			if not Board:IsBlocked(target, PATH_GROUND)
			and not Board:IsFire(target)
			and not Board:IsAcid(target)
			and not Board:IsSmoke(target)
			and not Board:IsDangerous(target)
			and not Board:IsEnvironmentDanger(target)
			and not Board:IsDangerousItem(target)
			and Board:GetTerrain(target) ~= TERRAIN_LAVA
			and Board:IsValid(target) then
				
				local damage = SpaceDamage(target)
				damage.sPawn = "HiveWarrior"
				Board:DamageSpace(damage)
				GAME.HW_WarriorLoc = target
				
				if island == 1 then
					Game:AddTutorial("Tut_Breach", GAME.HW_WarriorLoc)
				else
					Game:AddTutorial("Tut_Evolve", GAME.HW_WarriorLoc)
				end
				
				return
			end
		end
	end
	-- If we still can't find any space, try with less parameters
	for i, v in ipairs(list) do
		for dir = DIR_START, DIR_END do
			tick = v
			target = pod
			while tick > 0 do
				target = target + DIR_VECTORS[dir]
				tick = tick - 1
			end
			if not Board:IsBlocked(target, PATH_GROUND)
			and not Board:IsDangerous(target)
			and not Board:IsEnvironmentDanger(target)
			and not Board:IsDangerousItem(target)
			and Board:IsValid(target) then
			
				local damage = SpaceDamage(target, 0)
				damage.sPawn = "HiveWarrior"
				Board:DamageSpace(damage)
				GAME.HW_WarriorLoc = target
				
				if island == 1 then
					Game:AddTutorial("Tut_Breach", GAME.HW_WarriorLoc)
				else
					Game:AddTutorial("Tut_Evolve", GAME.HW_WarriorLoc)
				end
				
				return
			end
		end
	end
	if logging then LOG("HIVE WARRIOR SPAWNING FAILED! NO VALID TILES!") end
end

local function TrackMines()
	Wolf_MineTiles = Wolf_MineTiles or {}
	for x = 0, 7 do
		for y = 0, 7 do
			if Board:IsDangerousItem(Point(x,y)) then
				table.insert(Wolf_MineTiles, Point(x,y))
			end
		end
	end
end

local function SmiteMines()
	local index = table.getn(Wolf_MineTiles)
	local ret = SkillEffect()
	ret:AddDelay(0.5)
	for i = 1, index do
		if logging then LOG(Wolf_MineTiles[i].x..","..Wolf_MineTiles[i].y) end
		local damage = SpaceDamage(Wolf_MineTiles[i], 1)
		damage.sAnimation = "Explo_Fire1"
		damage.bHide = true
		ret:AddDamage(damage)
		ret:AddDelay(0.2)
	end
	Board:AddEffect(ret)
end

function Wolf_OnTimeBreachWarningDone()
    GAME.HW_WarriorOnBoard = true
	GAME.HW_Encounter = true
	
    BreachWarrior(GAME.HW_PodTile)
    --if GetSector() == 4 then
        GAME.HW_ObjStatus = OBJ_STANDARD
    --end
	
	TrackMines()
	SmiteMines()
	
	HW_Intimidate("Wolf_HW_Spawn", false, 0)
end

local function Wolf_OnTimeBreachWarningStart()
	-- Pilot reaction and delay
	HW_Intimidate("Wolf_HW_Breach", false, 1)
    local fx = SkillEffect()
    fx:AddDelay(Wolf_BreachWarnTimeInSeconds - 1)
    Board:AddEffect(fx)
	
	-- ui element init
    Wolf_HWBreach:create()

    -- pretty effects to make it more noticeable
    Game:TriggerSound("/ui/map/region_lost")
    Board:StartShake(Wolf_BreachWarnTimeInSeconds)
    
    -- Delay vek burrowing out
    fx = SkillEffect()
    fx:AddDelay(Wolf_BreachWarnTimeInSeconds + 1)
    Board:AddEffect(fx)
end

local function skillStartHook(mission, pawn, weaponId, p1, p2)
	if GAME then
		GAME.HW_WasRalph = (pawn:GetPersonality() == "Original")
		GAME.HW_Dodged = (weaponId == "Biocannon")
	end
end

local function pawnKilledHook(mission, pawn)
	if (pawn:GetType() == "HiveWarrior" or pawn:GetType() == "HiveWarriorFinal") and GAME.HW_DeadWarrior == false then
		GAME.HW_WarriorLoc = pawn:GetSpace()
		
		if pawn:GetType() == "HiveWarrior" then
			GAME.HW_ObjStatus = OBJ_COMPLETE
			pawn:SetFire(false, true)
			pawn:SetAcid(false, true)
			HW_Intimidate("Wolf_HW_Retreat", true, 2)
			math.randomseed(Game and Game:GetTurnCount() or 0)
			local rewardWeapon = random_removal(GAME.HW_RewardWeapons)
			Board:AddAlert(GAME.HW_WarriorLoc, "Found a weapon: ".._G[rewardWeapon].Name)
			Game:AddWeapon(rewardWeapon)
		end
		
		--Game:AddTutorial("Tut_RetreatWin", GAME.HW_WarriorLoc)
		if logging then LOG("Warrior Killed") end
		GAME.HW_DeadWarrior = true
		GAME.HW_MaxPower = GAME.HW_MaxPower + 1
		GAME.HW_PowerUps = GAME.HW_PowerUps + 1
		GAME.HW_Encounters[#GAME.HW_Encounters+1] = "win"
		
		if GAME.HW_Overwatched == false then
			modApi.achievements:trigger("Wolf_HiveWar", "HW_SilentKill")
		end
		
		if pawn:GetType() == "HiveWarriorFinal" then
			--HW_Intimidate("Wolf_HW_Death", true, 2)
			
			modApi.achievements:trigger("Wolf_HiveWar", "HW_FinalKill")
			
			local idx = 0
			while idx < #GAME.HW_Encounters do
				if GAME.HW_Encounters[idx+1] ~= "win" and GAME.HW_Encounters[idx+1] ~= nil then
					idx = 999
				end
				idx = idx + 1
			end
			if idx == 5 then
				modApi.achievements:trigger("Wolf_HiveWar", "HW_PentaKill")
			end
			
			if GAME.HW_WasRalph then
				modApi.achievements:trigger("Wolf_HiveWar", "HW_RalphKill")
			end
		end
	end
	
	if pawn:GetTeam() == TEAM_ENEMY and GAME.HW_Dodged == true then
		modApi.achievements:trigger("Wolf_HiveWar", "HW_FriendlyFire")
	end
end

local function DoAdaptation(pawn)
	if not (pawn and not pawn:IsDead()) then return end
	local point = pawn:GetSpace()
	local id = pawn:GetId()
	local damage = SpaceDamage(point)
	damage.bHide = true
	damage.iFire = EFFECT_REMOVE
	damage.iAcid = EFFECT_REMOVE
	damage.iFrozen = EFFECT_REMOVE
	if Status then
		local badStatus = { "Blind", "Bloodthirsty", "Bonded", "Chill", "Confusion", "Doomed", "Dry", "Hemorrhage", "Infested", "Leech Seed", "Necrosis", "Powder", "Rooted", "Shocked", "Sleep", "Targeted", "Toxin", "Weaken", "Wet"}
		for _, status in pairs(badStatus) do
			Status.RemoveStatus(id, status)
		end
	end
	Board:DamageSpace(damage)
	Board:AddAlert(point, "Adaptation!")
end

local function newTurnHook(mission)
    local turn = Board:GetTurn()
    -- Setup the Hive Warrior spawning
    if Game:GetTeamTurn() == TEAM_ENEMY and not GAME.HW_WarriorOnBoard then
        turn = Board:GetTurn()
        if turn == GAME.HW_PodTimer and not GAME.HW_DeadWarrior and GAME.HW_TimePodExists then
			Wolf_OnTimeBreachWarningStart()
        end
    end
	if Game:GetTeamTurn() == TEAM_PLAYER then
		-- Increase the mission timer by 1
		if GAME.HW_TimePodExists and turn == 1 then
			if logging then LOG("HIVE WARRIOR INBOUND! Increasing the Turn limit by 1!") end
			mission.TurnLimit = mission.TurnLimit + 1
		end
		-- Heal all status effects at the beginning of the player's turn
		if GAME.HW_WarriorOnBoard and not GAME.HW_DeadWarrior and GAME.HW_WarriorLoc and Board:IsPawnSpace(GAME.HW_WarriorLoc) then
			TrackMines()
			SmiteMines()
			if EvoCheck("D") then DoAdaptation(Board:GetPawn(GAME.HW_WarriorLoc)) end
		end
		
		for i = 0,2 do
			local mech = Board:GetPawn(i)
			if Wolf_HasPoweredWeapon(mech, "Passive_Adaptation", true) then
				for j = 0,2 do
					DoAdaptation(Board:GetPawn(j))
				end
			elseif Wolf_HasPoweredWeapon(mech, "Passive_Adaptation", false) then
				DoAdaptation(mech)
			end
		end
	end
end


local function missionStartHook(mission)
	-- reset the variables
	GAME.HW_WarriorOnBoard = false
	GAME.HW_DeadWarrior = false
	GAME.HW_TimePodExists = false
	GAME.HW_PodTile = nil
	GAME.HW_WarriorLoc = nil
	GAME.HW_PodHolder = nil
	GAME.HW_ObjStatus = nil
	GAME.HW_Overwatched = false
	GAME.HW_Dodged = false
	
	if logging then LOG("ALL HW VARS RESET") end
	
	Wolf_UpdateHiveWarriorSprite()
end

local function islandChangeHook(island)
	if GAME.HW_PowerUps and GAME.HW_PowerUps > 0 then
		GridImprovement(GAME.HW_PowerUps)
	end
	--TESTING ONLY
	GAME.HW_PowerUps = 0
	-- table.insert(GAME.HW_Evolutions, "V")
	
	-- if GetSector() > 2 then
	if GetSector() > 1 then
		local SelectedEvo = math.random(1, #GAME.HW_Evolist/2)
		if math.random(1, 2) == 1 then
			if logging then LOG("Adding evolution: "..GAME.HW_Evolist[SelectedEvo*2]) end
			table.insert(GAME.HW_Evolutions, GAME.HW_Evolist[SelectedEvo*2])
			table.remove(GAME.HW_Evolist, SelectedEvo*2)
			table.remove(GAME.HW_Evolist, (SelectedEvo*2)-1)
		else
			if logging then LOG("Adding evolution: "..GAME.HW_Evolist[(SelectedEvo*2)-1]) end
			table.insert(GAME.HW_Evolutions, GAME.HW_Evolist[(SelectedEvo*2)-1])
			table.remove(GAME.HW_Evolist, SelectedEvo*2)
			table.remove(GAME.HW_Evolist, (SelectedEvo*2)-1)
		end
		
		Wolf_UpdateHiveWarriorSprite()
	end
	GAME.HW_Encounter = nil
end

local function preMissionAvailableHook(mission)
	-- for index, boss in ipairs(Mission_Final_Cave.BossList) do
		-- table.remove(Mission_Final_Cave.BossList, index)
	-- end
	-- table.insert(Mission_Final_Cave.BossList, "HiveWarriorFinal")
	
	-- reset the variables
	GAME.HW_WarriorOnBoard = false
	GAME.HW_DeadWarrior = false
	GAME.HW_TimePodExists = false
	GAME.HW_PodTile = nil
	GAME.HW_WarriorLoc = nil
	GAME.HW_PodHolder = nil
	GAME.HW_ObjStatus = nil
	GAME.HW_Overwatch = {}
	GAME.HW_OverwatchUndo = {}
	if logging then LOG("ALL HW VARS RESET") end
	
	-- check for warrior upgrades
	local island = GetSector()
	
	if island >= 1 and island <= 4 then
		GAME.HW_Move = GAME.HW_WarriorStats["Sector"..island].Move
		GAME.HW_Health = GAME.HW_WarriorStats["Sector"..island].Health
		GAME.HW_ReaveDmg = GAME.HW_WarriorStats["Sector"..island].ReaveDmg
		GAME.HW_BioDmg = GAME.HW_WarriorStats["Sector"..island].BioDmg
		GAME.HW_BioRange = GAME.HW_WarriorStats["Sector"..island].BioRange
	elseif logging then 
		LOG("COULD NOT GET ISLAND NUMBER!")
	end
	if EvoCheck("M") then GAME.HW_BioAmmo = 2 end
	
	-- check for island change
	-- if island ~= GAME.HW_OldIsland then
		-- islandChangeHook(island)
	-- end
	GAME.HW_OldIsland = GetSector()
end

local function missionEndHook(mission)
	if GAME.HW_WarriorOnBoard == true and GAME.HW_DeadWarrior == false then
		HW_Intimidate("Wolf_HW_Draw", true, 2)
		GAME.HW_Encounters[#GAME.HW_Encounters+1] = "draw"
	end
	GAME.HW_WarriorOnBoard = false
	GAME.HW_DeadWarrior = false
	GAME.HW_TimePodExists = false
	GAME.HW_PodTile = nil
	GAME.HW_WarriorLoc = nil
	GAME.HW_PodHolder = nil
	GAME.HW_ObjStatus = nil
end

local function podDetectedHook()
	-- If island 3 or 4
	if GetSector() == 3 or GetSector() == 4 then
		GAME.HW_TimePodExists = not GAME.HW_Encounter
	else
		GAME.HW_TimePodExists = true
	end
	
	if GAME.HW_TimePodExists then
		local turn = Board:GetTurn()
		if turn == 0 then
			GAME.HW_PodTimer = turn + 2
		else
			GAME.HW_PodTimer = turn + 1
		end
		if logging then LOG("Time till breach: "..GAME.HW_PodTimer) end
	end
end

local function podLandedHook(point)
	if logging then LOG("Pod Landed!") end
	GAME.HW_PodTile = point
end

local function podDestroyedHook(pawn)
	if logging then LOG("Pod Destroyed!") end
	GAME.HW_TimePodExists = false
	if GAME.HW_WarriorLoc ~= nil then
		HW_Intimidate("Wolf_HW_Escape", false, 0)
		local pawn = Board:GetPawn(GAME.HW_WarriorLoc)
		pawn:Retreat()
		GAME.HW_WarriorOnBoard = false
		GAME.HW_DeadWarrior = true
		--Game:AddTutorial("Tut_RetreatLoss", GAME.HW_WarriorLoc)
		--if GAME.HW_ObjStatus ~= nil and GetSector() == 4 then
			GAME.HW_ObjStatus = OBJ_FAILED
		--end
		GAME.HW_Encounters[#GAME.HW_Encounters+1] = "loss"
	else
		if GetSector() == 3 or GetSector() == 4 then
			-- guarantee a breach on the next pod this island
			if GAME.HW_Encounter == nil then
				GAME.HW_Encounter = false
				return
			end
			
			-- there will not be another encounter this island so mark it as a loss
			if GAME.HW_Encounter == false then
				GAME.HW_Encounters[#GAME.HW_Encounters+1] = "loss"
			end
		else
			GAME.HW_Encounters[#GAME.HW_Encounters+1] = "loss"
		end
	end
end

local function podTrampledHook(pawn)
	podDestroyedHook(pawn)
end

local function podCollectedHook(pawn)
	if logging then LOG("Pod Collected!") end
	GAME.HW_PodHolder = pawn:GetId()
	--Game:AddTutorial("Tut_Bearer", GAME.HW_PodTile)
	--if GAME.HW_WarriorOnBoard == true and GAME.HW_DeadWarrior == false then
	--	GAME.HW_ObjStatus = OBJ_STANDARD
	--end
end

local function postStartGameHook()
	GAME.HW_MaxPower = 0
	GAME.HW_PowerUps = 0
	GAME.HW_OldIsland = 5
	GAME.HW_Evolist = {
		--[[
		"BCAcid",
		"BCAmmo",
		"RVFire",
		"RVWeb",
		"HWArmor",
		"HWAdapt",
		"HWVines",
		"HWAggro"
		--]]
		"A",
		"D",
		"C",
		"M",
		"F",
		"W",
		"V",
		"R"
	}
	GAME.HW_Evolutions = {}
	GAME.HW_BioAmmo = 1
	-- Initialize the HW's stats
	GAME.HW_WarriorStats = copy_table(MasterStatsHW)
	GAME.HW_Encounters = {}
	
	
	
	--Added by Metalocif to replace bonus objectives
	GAME.HW_RewardWeapons = { "Passive_Adaptation", "Any_GridOverload", "Passive_ServoEvade", "Science_ChronoBoost", "HW_HunterRifle", "HW_BroodLauncher" }
end

local function HWVelocityDodge(skillEffect)
	--Metalocif's addition. A lot of this is adapted from Lemon's old Leaper Boss.
	GAME.HW_LastVelocityTurn = GAME.HW_LastVelocityTurn or -1
	for _, fx in ipairs(extract_table(skillEffect.effect)) do
		local target = Board:GetPawn(fx.loc)
		local canDodge = target and (target:GetMechName() == "Hive Warrior" or target:GetMechName() == "HiveWarriorFinal") and EvoCheck("V") and GAME.HW_LastVelocityTurn < Game:GetTurnCount()
		if canDodge then
			local PawnBackup = Pawn; Pawn = target
			local weapon = _G[_G[target:GetType()].SkillList[1]]

			local actions = {}
			local reachable = extract_table(Board:GetReachable(fx.loc, 1, target:GetPathProf()))
			
			-- create a list of all possible moves.
			for _, loc in ipairs(reachable) do
				local moveScore = ScorePositioning(loc, target)
				
				targets = extract_table(weapon:GetTargetArea(loc))
				for _, target in ipairs(targets) do
					if Board:IsValid(target) then
						-- attack score
						local attackScore = weapon:GetTargetScore(loc, target)
						table.insert(
							actions,
							{
								loc = loc,
								target = target,
								score = moveScore + attackScore
							}
						)
					end
				end
			end
			Pawn = PawnBackup
			local bestAction
			if #actions > 0 then
				-- sort scores from high to low.
				table.sort(actions, function(a,b) return a.score > b.score end)
				-- count #indices with same top score.
				local i = 1
				while(actions[i+1] and actions[i+1].score == actions[1].score) do
					i = i + 1
				end
				-- pick one top score at random.
				bestAction = actions[math.random(1, i)]
			end
			
			--Save old effect
			local oldEffect = skillEffect.effect or DamageList()
			local oldQEffect = skillEffect.q_effect or DamageList()
			local oldEffectCopy = DamageList()
			local oldQEffectCopy = DamageList()
			--Make a copy
			if oldEffect then 
				for i = 1, oldEffect:size() do
					local oldDamage = oldEffect:index(i);
					oldEffectCopy:push_back(oldDamage)
				end
			end
			if oldQEffect then 
				for i = 1, oldQEffect:size() do
					local oldDamage = oldQEffect:index(i);
					oldQEffectCopy:push_back(oldDamage)
				end
			end
			--Reset
			skillEffect.effect = DamageList()
			--Insert
			
			if bestAction then 
				-- teleport away from danger
				skillEffect:AddTeleport(fx.loc, bestAction.loc, NO_DELAY)
			end
			--Add in old effects
			for i = 1, oldEffectCopy:size() do
				local oldDamage = oldEffectCopy:index(i);
				skillEffect.effect:push_back(oldDamage)
			end
			for i = 1, oldQEffectCopy:size() do
				local oldDamage = oldQEffectCopy:index(i);
				skillEffect.q_effect:push_back(oldDamage)
			end
			if bestAction then
				-- fire the pawn's weapon in the chosen direction
				skillEffect:AddScript(string.format("Board:GetPawn(%s):FireWeapon(%s, 1)", target:GetId(), bestAction.target:GetString()))
				-- keep track that we teleported this turn
				skillEffect:AddScript("GAME.HW_LastVelocityTurn = "..Game:GetTurnCount())
			end
			return
		end
	end
end

local function missionNextPhaseCreatedHook(prevMission, nextMission)
	modApi:conditionalHook(function()
		return true and Game ~= nil and GAME ~= nil and GetCurrentMission() ~= nil and Board ~= nil  
	end, 
	function()
		if GameData.network >= 10 then
			modApi.achievements:trigger("Wolf_HiveWar", "HW_TenPower")
		end
		for _, id in ipairs(extract_table(Board:GetPawns(TEAM_ENEMY))) do
			if Board:GetPawn(id) and _G[Board:GetPawn(id):GetType()].Tier == TIER_BOSS then
				local curr = Board:GetPawn(id):GetSpace()
				Board:RemovePawn(Board:GetPawn(id))
				Board:AddPawn("HiveWarriorFinal", curr)
				return
			end
		end
		--if we didn't find a boss to replace, spawn the final Hive Warrior anyway
		Board:AddPawn("HiveWarriorFinal")
		--check whether mechs don't deploy on top? Otherwise, could make him replace a non-boss
	end)
end

function GridImprovement(ExtraPower)
	if GetSector() == 4 and GAME.HW_MaxPower > 0 then
		sdlext.showInfoDialog("Power Grid Improvement Halted","Unfortunately, strategists have determined that there is not enough time before the Final Assault to improve the Grid any further. Instead, any extra biological components will be salvaged directly into electricity for the Grid.")
	elseif ExtraPower and ExtraPower > 0 then
		sdlext.showInfoDialog("Power Grid Improved","By studying the defeated Hive Warrior's organic technology, our allies have managed to improve the Grid's maximum capacity by "..ExtraPower.." unit"..(ExtraPower > 1 and "s." or "."))
		Location.undo_turn = Location.undo_turn + Point(GAME.HW_MaxPower * 20, 0)
	end
end

function HW_Intimidate(dialogue, proxy, target)
	if logging then LOG("INTIMIDATE CALLED!") end
	
	local roll = nil
	if target == 0 then roll = math.random(0,4) end -- anyone
	if target == 1 then roll = math.random(0,2) end -- squad
	if target == 2 then roll = 5 end -- hive warrior
	
	if logging then LOG("CAST ROLL: "..roll) end
	
	if roll < 3 then
		if Board:GetPawn(roll):GetPersonality() == "Artificial" then
			if logging then LOG("Pilot is AI! Not happening!") end
			if target ~= 1 then roll = 5 end
		end
	end
	
	if roll > 2 then
		if proxy then
			if logging then LOG("PROXYING INTIMIDATE!") end
			local pawnSpawner = SpaceDamage(GAME.HW_WarriorLoc)
			pawnSpawner.sPawn = "HiveWarriorProxy"
			pawnSpawner.bHide = true
			Board:DamageSpace(pawnSpawner)
			Board:GetPawn(GAME.HW_WarriorLoc):SetFire(false, true)
			Board:GetPawn(GAME.HW_WarriorLoc):SetAcid(false, true)
			-- Board:AddPawn("HiveWarriorProxy", GAME.HW_WarriorLoc)
		end
		
		local pawn = Board:GetPawn(GAME.HW_WarriorLoc)
		local cast = { }
		cast.main = pawn:GetId()
		modapiext.dialog:triggerRuledDialog(dialogue, cast)
		
		if proxy then
			-- Board:RemovePawn(pawn)
			local damage = SpaceDamage(GAME.HW_WarriorLoc, DAMAGE_DEATH)
			damage.bHide = true
			Board:DamageSpace(damage)
		end
	else
		local cast = { }
		cast.main = roll
		modapiext.dialog:triggerRuledDialog(dialogue, cast)
	end
end

local function EVENT_onModsLoaded()
	modApi:addNextTurnHook(newTurnHook)
	modApi:addMissionStartHook(missionStartHook)
	modApi:addPreMissionAvailableHook(preMissionAvailableHook)
	modApi:addPostIslandSelectionHook(islandChangeHook)
	modApi:addMissionEndHook(missionEndHook)
	modApi:addPostStartGameHook(postStartGameHook)
	modApi:addMissionNextPhaseCreatedHook(missionNextPhaseCreatedHook)
	modapiext:addPodDetectedHook(podDetectedHook)
	modapiext:addPodLandedHook(podLandedHook)
	modapiext:addPodTrampledHook(podTrampledHook)
	modapiext:addPodDestroyedHook(podDestroyedHook)
	modapiext:addPodCollectedHook(podCollectedHook)
	modapiext:addPawnPositionChangedHook(pawnPositionChangedHook)
	modapiext:addSkillStartHook(skillStartHook)
	modapiext:addPawnKilledHook(pawnKilledHook)
	modapiext:addSkillBuildHook(function(mission, pawn, weaponId, p1, p2, skillEffect)
		HWVelocityDodge(skillEffect)
	end)
	modapiext:addFinalEffectBuildHook(function(mission, pawn, weaponId, p1, p2, p3, skillEffect)
		HWVelocityDodge(skillEffect)
	end)
	modApi:addPostLoadGameHook(onLoad)
end

modApi.events.onModsLoaded:subscribe(EVENT_onModsLoaded)