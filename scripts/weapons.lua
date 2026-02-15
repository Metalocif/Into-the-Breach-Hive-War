
local logging = false

-- returns a string with suffixes "_A", "_B", "_AB" removed
local function GetBaseWeapon(weapon)
	assert(type(weapon) == 'string')
	
	if modApi:stringEndsWith(weapon, "_AB") then
		return string.sub(weapon, 1, -4)
	elseif
		modApi:stringEndsWith(weapon, "_A") or
		modApi:stringEndsWith(weapon, "_B")
	then
		return string.sub(weapon, 1, -3)
	end
	
	return weapon
end

-- returns an array of size 2 with upgrade booleans
local function GetWeaponUpgrades(weapon)
	assert(type(weapon) == 'string')
	
	if modApi:stringEndsWith(weapon, "_AB") then
		return {true, true}
	elseif modApi:stringEndsWith(weapon, "_A") then
		return {true, false}
	elseif modApi:stringEndsWith(weapon, "_B") then
		return {false, true}
	end
	
	return {false, false}
end

-- taken from Lemonymous's RF1995 and modified to add the third parameter
function Wolf_HasPoweredWeapon(pawn, weapon, upgraded)
	assert(type(weapon) == 'string')
	if upgraded then
		if _G[weapon].Upgrades == 2 then weapon = weapon.."_AB" end
		if _G[weapon].Upgrades == 1 then weapon = weapon.."_A" end
	end
	return pawn:GetPoweredWeapons()[1] == weapon or pawn:GetPoweredWeapons()[2] == weapon
end

local function EvoCheck(evo)
	if GAME.HW_Evolutions ~= nil then
		for _,v in pairs(GAME.HW_Evolutions) do
			if v == evo then return true end
		end
	end
	return false
end

------------------------------------------------------
--                  HIVE WEAPONRY                   --
------------------------------------------------------

--Reave
Wolf_Reave = {
	Name = "Talons and Biocannon",
	Description = "Press W to view the Hive Warrior's current stats.",
	GetDamage = function() return GAME.HW_ReaveDmg or 1 end,
	PathSize = 1,
	Icon = "weapons/enemy_scorpion1.png",	
	PreDamage = 0,
	Class = "Enemy",
	LaunchSound = "",
	SoundBase = "/enemy/scorpion_soldier_1",
	TipImage = {
		Unit = Point(2,2),
		Enemy = Point(2,1),
		Target = Point(2,1),
		CustomPawn = "HiveWarrior"
	}
}
Wolf_Reave = Skill:new(Wolf_Reave) 

function Wolf_Reave:GetTargetArea(p1)
	local ret = PointList()
	local island = GetSector()
	
	if EvoCheck("R") then 
		ret:push_back(p1)
	else
		for dir = DIR_START, DIR_END do
			ret:push_back(p1+DIR_VECTORS[dir])
		end
	end
	return ret
end

function Wolf_Reave:GetTargetScore(p1,p2)
	local effect = SkillEffect()
	local island = GetSector()
	
	--can only self-target if has the Reflex evolution, which makes the Warrior retarget constantly.
	--therefore, he will go to the spot where one of the four adjacent tiles is best.
	if p1 == p2 then 
		return math.max(self:GetTargetScore(p1, p1 + DIR_VECTORS[0]),
						self:GetTargetScore(p1, p1 + DIR_VECTORS[1]),
						self:GetTargetScore(p1, p1 + DIR_VECTORS[2]),
						self:GetTargetScore(p1, p1 + DIR_VECTORS[3]))
	end
	-- GOTTA GET THOSE TIME TRAVELLERS' TREASURES
	if Board:IsPod(p2) then return 50 end
	local pawn = Board:GetPawn(p2)
	if GAME.HW_PodHolder and pawn and pawn:GetId() == GAME.HW_PodHolder then return 100 end
	
	-- don't flame units without repair
	if EvoCheck("F") and pawn and not pawn:IsMech() then return -100 end
	
	if pawn and pawn:GetTeam() == TEAM_PLAYER and not pawn:IsDead() then
		if EvoCheck("F") and not pawn:IsFire() and not pawn:IsIgnoreFire() and not (Board:GetTerrain(p2) == TERRAIN_WATER and not pawn:IsFlying()) then 
			if pawn:GetHealth() == 1 then return 40 end
			return 20
		end
		if EvoCheck("W") and not pawn:IsIgnoreWeb() then return 20 end
		return 5
	end
	if Board:GetTerrain(p2) == TERRAIN_BUILDING then return 10 end
	if pawn and pawn:GetTeam() == TEAM_ENEMY then return -10 end
	return 0
	-- return self:ScoreList(self:GetSkillEffect(p1,p2).q_effect, true)
end

function Wolf_Reave:GetSkillEffect(p1, p2)
	local ret = SkillEffect()
	local target = p2
	if p1 == p2 then
		local bestTarget = Point(-1, -1)
		local bestScore = -100
		for dir = DIR_START, DIR_END do
			local score = self:GetTargetScore(p1, p1 + DIR_VECTORS[dir])
			if score > bestScore then
				bestScore = score
				bestTarget = p1 + DIR_VECTORS[dir]
			end
		end
		target = bestTarget
	end
	
	local direction = GetDirection(target - p1)
	local damage = SpaceDamage(target, self.GetDamage())
	
	if EvoCheck("W") then
		local predam = SpaceDamage(target)
		ret:AddDamage(predam)
		ret:AddDelay(0.2)
		ret:AddDamage(SoundEffect(target,self.SoundBase.."/attack_web"))
		ret:AddGrapple(p1,target,"hold")
		ret:AddDelay(0.2)
	end
	if EvoCheck("F") then
		local predam = SpaceDamage(target)
		if not Board:IsPod(target) then predam.iFire = 1 end
		predam.sAnimation = "flamethrower1_"..direction
		predam.sSound = "/weapons/flamethrower"
		ret:AddDamage(predam)
		ret:AddDelay(0.2)
	end

	GAME.HW_LastReave = direction
	damage = SpaceDamage(target, self.GetDamage())
	damage.sAnimation = "SwipeClaw2"
	damage.sSound = "/enemy/beetle_2/attack_impact"
	ret:AddQueuedMelee(p1,damage)
	
	return ret
end	

-------------------------------------------------------
--Biocannon
Wolf_Biocannon = {
	Name = "Hidden Weapon",
	Description = "You shouldn't be seeing this weapon description, please file a bug report.",
	GetDamage = function() return GAME.HW_BioDmg or 2 end,
	PathSize = 1,
	Class = "Enemy",
	Icon = "weapons/ranged_rainingvolley.png",
	Explosion = "ExploBiocannon",
	ImpactSound = "/impact/dynamic/enemy_projectile",
	Projectile = "effects/shot_biocannon",
	Cost = "high",
	TipImage = {
		Unit = Point(2,3),
		Enemy = Point(2,1),
		Building = Point(2,0),
		Target = Point(2,2),
		CustomPawn = "HiveWarrior"
	}
}	
Wolf_Biocannon = Skill:new(Wolf_Biocannon)

function Wolf_Biocannon:GetTargetArea(point)
	local ret = PointList()
	for dir = DIR_START, DIR_END do
		local this_path = {}
		
		local target = point + DIR_VECTORS[dir]

		while not Board:IsBlocked(target, PATH_PROJECTILE) do
			this_path[#this_path+1] = target
			target = target + DIR_VECTORS[dir]
		end
		this_path[#this_path+1] = target
		
		for i,v in ipairs(this_path) do 
			ret:push_back(v)
		end
		
	end
	
	return ret
end

function Wolf_Biocannon:GetSkillEffect(p1,p2)
	local ret = SkillEffect()
	local dir = GetDirection(p2 - p1)
	local target = GetProjectileEnd(p1, p2)
	
	local pawn = Board:GetPawn(p2)
	if pawn ~= nil then
		local pilot = pawn:GetPersonality()
		
		if (pilot == "Original" or Wolf_HasPoweredWeapon(pawn, "Passive_ServoEvade", false)) and Board:IsValid(p2 + DIR_VECTORS[dir]) then
			target = GetProjectileEnd(p2, p2 + DIR_VECTORS[dir])
			HW_Intimidate("Wolf_HW_Evade", false, 0)
		end
	end
	
	local damage = SpaceDamage(target, self.GetDamage())
	
	if Board:IsBuilding(target) then damage.iDamage = 0 end
	
	if EvoCheck("A") then damage.iAcid = 1 end
	
	--LOG("Shooting: "..target.x..","..target.y)
	
	ret:AddProjectile(damage, self.Projectile)
	
	return ret
end

Wolf_ReflexReave = SelfTarget:new{
	Name = "Reave",
	GetDamage = function() return GAME.HW_ReaveDmg or 1 end,
	PathSize = 1,
	Icon = "weapons/enemy_scorpion1.png",	
	PreDamage = 0,
	Class = "Enemy",
	LaunchSound = "",
	SoundBase = "/enemy/scorpion_soldier_2",
	CustomTipImage = "Wolf_ReflexReave_Tip",
	TipImage = {
		Unit = Point(3,2),
		Enemy = Point(1,1),
		Building = Point(1,2),
		Target = Point(3,2),
		Second_Origin = Point(3,2),
		Second_Target = Point(0,0), -- we just need to be able to identify the second attack.
		Length = 1.5,
		CustomPawn = "HiveWarrior"
	}
}

local isTargetScore
function Wolf_ReflexReave:GetTargetScore(p1, p2)
	isTargetScore = true
	local ret = Skill.GetTargetScore(self, p1, p2)
	isTargetScore = false
	
	return 10
end

function Wolf_ReflexReave:GetTargetArea(point)
	local ret = PointList()
	
	ret:push_back(point)
	
	return ret
end

function Wolf_ReflexReave:GetSkillEffect(p1, p2, parentSkill, isTipImage)
	local ret = SkillEffect()
	local mission = GetCurrentMission()
	local targets = {}
	local shooter = Board:GetPawn(p1)
	local damage = SpaceDamage(p1)
	
	if not shooter then
		ret:AddQueuedMelee(damage)
		return ret
	end
	
	for dir = DIR_START, DIR_END do
		local target = p1 + DIR_VECTORS[dir]
		
		if Board:IsValid(target) then
			local pawn = Board:GetPawn(target)
			
			local isEnemy = false
			if pawn and pawn:GetTeam() == TEAM_PLAYER and not pawn:IsDead() then isEnemy = true end
			
			local isBuilding = false
			if Board:IsBuilding(target) and Board:IsPowered(target) then isBuilding = true end
			
			table.insert(targets, {
				id = p2idx(target),
				loc = target,
				dir = dir,
				isEnemy = isEnemy,
				isBuilding = isBuilding,
			})
		end
	end
	
	local hasEnemy = false
	
	-- filter out directions without a target.
	for i = #targets, 1, -1 do
		if not targets[i].isEnemy then--and not targets[i].isBuilding then
			if logging then LOG("Removing target: "..tostring(targets[i].isEnemy).." / "..tostring(targets[i].isBuilding)) end
			table.remove(targets, i)
		elseif targets[i].isEnemy then
			hasEnemy = true
		end
	end
	
	if logging then LOG("Targets remaining: "..#targets) end
	
	-- if enemy in range, filter out building tiles
	if hasEnemy then
		for i = #targets, 1, -1 do
			if not targets[i].isEnemy then
				if logging then LOG("Removing target: "..tostring(targets[i].isEnemy).." / "..tostring(targets[i].isBuilding)) end
				table.remove(targets, i)
			end
		end
	end
	
	local finalTarget = Point(-1, -1)
	if #targets > 0 then
		local result = targets[1]
		
		finalTarget = result.loc
		GAME.HW_LastReave = result.dir
	elseif GAME.HW_LastReave ~= nil then
		finalTarget = p1 + DIR_VECTORS[GAME.HW_LastReave]
	else
		damage.bHide = true
		ret:AddQueuedScript(string.format("Board:AddAlert(%s, 'NO TARGET')", p1:GetString()))
		return ret
	end
	
	damage = SpaceDamage(finalTarget, self.GetDamage())
	damage.sAnimation = "SwipeClaw2"
	damage.sSound = "/enemy/beetle_2/attack_impact"
	ret:AddQueuedMelee(p1,damage)
	
	return ret
end

Wolf_ReflexReave_Tip = Wolf_ReflexReave:new{}

function Wolf_ReflexReave_Tip:GetTargetArea(p)
	local ret = PointList()
	ret:push_back(self.TipImage.Target)
	ret:push_back(self.TipImage.Second_Target)
	return ret
end

function Wolf_ReflexReave_Tip:GetSkillEffect(p1, p2)
	-- hardcode tipimage
	local ret = SkillEffect()
	local unit = self.TipImage.Unit
	local enemy = self.TipImage.Enemy
	local dest = Point(unit.x, enemy.y)
	local building = self.TipImage.Building
	
	if p2 == unit then
		
		local damage = SpaceDamage(building, self.GetDamage())
		local repair = SpaceDamage(building)
		damage.sScript = "Board:ClearSpace(".. building:GetString() ..")"
		repair.sScript = "Board:SetTerrain(".. building:GetString() ..", TERRAIN_BUILDING)"
		
		-- move taunter into place.
		ret:AddDelay(0.67)
		ret:AddScript(string.format("Board:GetPawn(%s):Move(%s)", enemy:GetString(), dest:GetString()))
		ret:AddDelay(0.08)
		
		-- increase speed so fake projectile hits instantly.
		worldConstants.QueuedSetSpeed(ret, 1000)
		ret:AddQueuedMelee(damage, NO_DELAY)
		ret:AddQueuedMelee(repair, NO_DELAY)
		worldConstants.QueuedResetSpeed(ret)
	else
		-- second attack on taunting enemy.
		local d = SpaceDamage(dest, self.Damage)
		d.sAnimation = self.Anim_Impact
		ret:AddDamage(d)
	end
	
	return ret
end

------------------------------------------------------
--                 PLAYER WEAPONRY                  --
------------------------------------------------------

--Added weapons by Metalocif, based on NotSoLoneWolf's ideas

HW_HunterRifle = Skill:new{
	Name = "Hunter's Rifle",
	Class = "Brute",
	Icon = "weapons/HW_HunterRifle.png",
	Description = "Fires a pushing projectile in a straight line.",
	Damage = 2,
	Acid = 0,
	Tracker = false,
	PathSize = 8,
	PowerCost = 1, --AE Change
	Upgrades = 2,
	UpgradeCost = { 1, 2 },
	UpgradeList = { "A.C.I.D.", "Tracker" },
	TipImage = {
		Unit = Point(2,3),
		Target = Point(2,1),
		Enemy1 = Point(1,1),
		Enemy2 = Point(2,1),
		Enemy3 = Point(3,2),
	}
}
HW_HunterRifle_A = HW_HunterRifle:new{UpgradeDescription = "This weapon's attacks apply A.C.I.D..",Acid = 1,}
HW_HunterRifle_B = HW_HunterRifle:new{UpgradeDescription = "Damaging enemies tracks them. After attacking, queues artillery shots against all tracked enemies.",MinDamage = 1, Tracker = true,}
HW_HunterRifle_AB = HW_HunterRifle:new{Acid = 1,MinDamage = 1,Tracker = true,}

function HW_HunterRifle:GetSkillEffect(p1, p2)
	local ret = SkillEffect()
	local direction = GetDirection(p2-p1)
	local target = GetProjectileEnd(p1,p2)
	local pawn = Board:GetPawn(target)
	local mission = GetCurrentMission()
	if mission then mission.HunterRifleTracked = mission.HunterRifleTracked or {} end
	local damage = SpaceDamage(target, self.Damage, direction)
	damage.sAnimation = "ExploBiocannon"
	damage.sSound = "/impact/dynamic/enemy_projectile"
	damage.iAcid = self.Acid
	
	ret:AddProjectile(p1, damage, "effects/shot_biocannon", PROJ_DELAY)
	if mission and pawn and self.Tracker and pawn:GetTeam() == TEAM_ENEMY and Board:GetSize() ~= Point(6, 6) then 
		if not (pawn:IsShield() or pawn:IsFrozen() or Board:GetCustomTile(pawn:GetSpace()) == "tosx_rocks_0.png") then 
			ret:AddScript(string.format("GetCurrentMission().HunterRifleTracked[%s] = true", pawn:GetId()))			
		end
	end
	if mission and self.Tracker then
		if Board:GetSize() == Point(6, 6) then 
			ret:AddQueuedArtillery(SpaceDamage(Point(1, 1), 1), "effects/shotup_biocannon.png", NO_DELAY)
			ret:AddQueuedArtillery(SpaceDamage(Point(3, 2), 1), "effects/shotup_biocannon.png", NO_DELAY)
			ret:AddQueuedDelay(3)
		else
			local foundSomething
			for id, _ in pairs(mission.HunterRifleTracked) do
				if Board:GetPawn(id) and Board:GetPawn(id):GetSpace() ~= Point(-1, -1) and not Board:GetPawn(id):IsDead() then
					foundSomething = true
					local artilleryDamage = SpaceDamage(Board:GetPawn(id):GetSpace(), self.MinDamage)
					artilleryDamage.sAnimation = "ExploBiocannon"
					artilleryDamage.sSound = "/impact/dynamic/enemy_projectile"
					artilleryDamage.iAcid = self.Acid
					ret:AddQueuedArtillery(artilleryDamage, "effects/shotup_biocannon.png", NO_DELAY)
				end
			end
			if not foundSomething then 
				local suppressWeirdQueuedProjectile = SpaceDamage(p1)
				suppressWeirdQueuedProjectile.bHide = true
				ret:AddQueuedDamage(suppressWeirdQueuedProjectile)
			end
		end
	end
	return ret
end

HW_BroodLauncher = Skill:new{
	Name = "Brood Launcher",
	Class = "Ranged",
	Icon = "weapons/HW_BroodLauncher.png",
	Description = "Fires a spore diagonally. The spore then fires two pushing projectiles orthogonally.",
	Damage = 2,
	SelfDamage = 1,
	PathSize = 8,
	PowerCost = 1, --AE Change
	Upgrades = 2,
	UpgradeCost = { 1, 2 },
	UpgradeList = { "+1 Damage", "No self-damage" },
	TipImage = {
		Unit = Point(1,1),
		Target = Point(2,2),
		Enemy1 = Point(3,2),
		Enemy2 = Point(2,3),
		Building = Point(3,3),
		Water = Point(1,2)
	}
}
HW_BroodLauncher_A = HW_BroodLauncher:new{UpgradeDescription = "Deals 1 more damage.",Damage = 3,}
HW_BroodLauncher_B = HW_BroodLauncher:new{UpgradeDescription = "Incurs no self-damage.",MinDamage = 0,}
HW_BroodLauncher_AB = HW_BroodLauncher:new{Damage = 3,MinDamage = 0}

function HW_BroodLauncher:GetTargetArea(point)
	local ret = PointList()
	for i = DIR_START, DIR_END do
		for j = 1, 7 do
			local curr = point + DIR_VECTORS[i] * j + DIR_VECTORS[(i+1)%4] * j
			if not (Board:IsBlocked(curr, PATH_GROUND) 
			or (curr.x == 0 and curr.y == 0) or (curr.x == 0 and curr.y == 7) or (curr.x == 7 and curr.y == 0) or (curr.x == 7 and curr.y == 7)) then 
			--since we "deploy" a unit, it has to be an empty, walkable space
			--don't shoot into corners; resulting projectiles would do nothing
				ret:push_back(curr)
			end
		end
	end
	return ret
end

function HW_BroodLauncher:GetSkillEffect(p1, p2)
	local ret = SkillEffect()
	if self.SelfDamage == 1 then ret:AddDamage(SpaceDamage(p1, 1)) end
	ret:AddArtillery(p1, SpaceDamage(p2), "effects/shotup_totem2.png", PROJ_DELAY)
	local dir1, dir2
	if p2.x < p1.x and p2.y < p1.y then dir1 = DIR_UP dir2 = DIR_LEFT end
	if p2.x < p1.x and p2.y > p1.y then dir1 = DIR_LEFT dir2 = DIR_DOWN end
	if p2.x > p1.x and p2.y > p1.y then dir1 = DIR_DOWN dir2 = DIR_RIGHT end
	if p2.x > p1.x and p2.y < p1.y then dir1 = DIR_RIGHT dir2 = DIR_UP end
	local target1 = GetProjectileEnd(p2, p2 + DIR_VECTORS[dir1])
	local target2 = GetProjectileEnd(p2, p2 + DIR_VECTORS[dir2])
	local damage1 = SpaceDamage(target1, self.Damage, dir1)
	local damage2 = SpaceDamage(target2, self.Damage, dir2)
	damage1.sAnimation = "ExploBiocannon"
	damage2.sAnimation = "ExploBiocannon"
	damage1.sSound = "/impact/dynamic/enemy_projectile"
	damage2.sSound = "/impact/dynamic/enemy_projectile"
	ret:AddProjectile(p2, damage1, "effects/shot_biocannon", NO_DELAY)
	ret:AddProjectile(p2, damage2, "effects/shot_biocannon", NO_DELAY)
	return ret
end

HW_RendingClaws=Skill:new{
	Class = "Prime",
	Icon = "weapons/HW_RendingClaws.png",	
	Rarity = 3,
	Name = "Rending Claws",
	Description = "Deal damage and pull two targets.",
	Push = 1,--TOOLTIP HELPER
	Damage = 2,
	PathSize = 1,	--automatically makes a target area?
	-- TwoClick = true,
	PowerCost = 1, --AE Change
	Upgrades = 2,
	UpgradeList = { "+1 Damage", "Teleport" },
	UpgradeCost = { 2, 1 },
	LaunchSound = "/weapons/charge",
	ImpactSound = "/weapons/charge_impact",
	ZoneTargeting = ZONE_DIR,
	TipImage = {
		Unit = Point(2,4),
		Target = Point(2,3),
		Enemy1 = Point(2,2),
		Enemy2 = Point(2,3),
		Enemy3 = Point(3,2),
	}
}
HW_RendingClaws_A=HW_RendingClaws:new{ UpgradeDescription = "Deals 1 more damage.", Damage = 3 }
HW_RendingClaws_B=HW_RendingClaws:new{ UpgradeDescription = "Before attacking, can teleport to any tile in a 3 tile radius.", TwoClick = true }
HW_RendingClaws_AB=HW_RendingClaws:new{ Damage = 3, TwoClick = true }

function HW_RendingClaws:GetTargetArea(p1)
	local ret = PointList()
	if self.TwoClick then
		local targets = extract_table(general_DiamondTarget(p1, 3))
		for k = 1, #targets do
			if Board:GetPawn(p1) and targets[k] and (targets[k] == p1 or not Board:IsBlocked(targets[k], Board:GetPawn(p1):GetPathProf())) then 
				ret:push_back(targets[k]) 
			end
		end
	else
		for dir = DIR_START, DIR_END do
			ret:push_back(p1+DIR_VECTORS[dir])
		end
	end
	return ret
end

function HW_RendingClaws:GetSecondTargetArea(p1, p2)
	local ret = PointList()
	for dir = DIR_START, DIR_END do
		ret:push_back(p2+DIR_VECTORS[dir])
	end
	return ret	
end

function HW_RendingClaws:GetSkillEffect(p1, p2)
	local ret = SkillEffect()
	if self.TwoClick and Board:GetSize() ~= Point(6, 6) then
		ret:AddTeleport(p1, p2, FULL_DELAY)
	else	
		local direction = GetDirection(p2-p1)
		local damage1 = SpaceDamage(p2 + DIR_VECTORS[(direction + 1)%4], self.Damage, (direction + 2)%4)
		local damage2 = SpaceDamage(p2 + DIR_VECTORS[(direction - 1)%4], self.Damage, (direction + 2)%4)
		damage1.sAnimation = "Swipe2Claw1"
		damage2.sAnimation = "Swipe2Claw1"
		ret:AddMelee(p1, SpaceDamage(p2))
		ret:AddDamage(damage1)
		ret:AddDamage(damage2)
	end
	return ret
end

function HW_RendingClaws:GetFinalEffect(p1, p2, p3, remainingShots)
	local ret = SkillEffect()
	local direction = GetDirection(p3-p2)
	ret:AddTeleport(p1, p2, FULL_DELAY)
	local damage1 = SpaceDamage(p3 + DIR_VECTORS[(direction + 1)%4], self.Damage, (direction + 2)%4)
	local damage2 = SpaceDamage(p3 + DIR_VECTORS[(direction - 1)%4], self.Damage, (direction + 2)%4)
	damage1.sAnimation = "Swipe2Claw1"
	damage2.sAnimation = "Swipe2Claw1"
	ret:AddMelee(p1, SpaceDamage(p2))
	ret:AddDamage(damage1)
	ret:AddDamage(damage2)
	return ret
end




--Original weapons by NotSoLoneWolf

Passive_Adaptation = PassiveSkill:new{
	Name = "Adaptation",
	Description = "Removes all negative status effects from the mech at the start of the player's turn.",
	PowerCost = 0,
	Icon = "weapons/passives/passive_adaptation.png",
	Passive = "adapt",
	Upgrades = 1,
	UpgradeCost = {2},
	UpgradeList = { "Mass Adapt" },
	Rarity = 1,
	TipImage = {
		Unit = Point(2,3)
	}
}

Passive_Adaptation_A = Passive_Adaptation:new{
	Passive = "adapt_aoe",
	UpgradeDescription = "The entire mech squad benefits from Adaptation.",
	TipImage = {
		Unit = Point(2,3),
		Friendly = Point(2,1),
		Friendly2 = Point(3,2),
	}
}

-------------------------------------------------------

Any_GridOverload = Skill:new{
	GetDamage = function()
		if not GameData then return 2 end
		local grid = GameData.network
		
		if grid == nil then
			return 2
		else
			return math.floor(grid/2)
		end
	end,
	Name = "Grid Overload",
	Description = "Route the might of the Grid through your mech. Deals damage equal to the current Grid Power divided by 2.",
	PathSize = 1,
	SelfDamage = 3,
	PowerCost = 1,
	Icon = "weapons/prime_overload.png",
	Upgrades = 1,
	UpgradeCost = {2, 3},
	UpgradeList = { "Safe Operation", "Grid Channeling" },
	Rarity = 1,
	TipDamage = 5,
	MinDamage = 1,
	Buildings = false,
	TipImage = {
		Unit = Point(3,2),
		Building = Point(2,2),
		Friendly = Point(2,1),
		Enemy = Point(4,2),
		Enemy2 = Point(2,3),
		Enemy3 = Point(1,1),
		Target = Point(3,2)
	}
}

Any_GridOverload_A = Any_GridOverload:new{
	SelfDamage = 2,
	Description = "Deals 1 less self-damage."
}

Any_GridOverload_B = Any_GridOverload:new{
	Buildings = true,
	Description = "Damage can harmlessly chain through buildings and friendly units.",
}

Any_GridOverload_AB = Any_GridOverload:new{
	Buildings = true,
	SelfDamage = 2
}

function Any_GridOverload:GetTargetArea(point)
	local ret = PointList()
	ret:push_back(point)
	return ret
end

function Any_GridOverload:GetSkillEffect(p1, p2)
	local ret = SkillEffect()
	local hash = function(point) return point.x + point.y*10 end
	local explored = {[hash(p1)] = true}
	
	ret:AddAnimation(p1,"Lightning_Hit")
	ret:AddDamage(SpaceDamage(p1, self.SelfDamage))
	
	for dir = DIR_START, DIR_END do
		local tile = p1 + DIR_VECTORS[dir]
		local damage = SpaceDamage(tile, self.GetDamage())
		local todo = {tile}
		local origin = { [hash(tile)] = p1 }
		
		while #todo ~= 0 do
			local current = pop_back(todo)
			
			if not explored[hash(current)] then
				explored[hash(current)] = true
				
				if self.Buildings and (Board:IsBuilding(current) or Board:IsPawnTeam(current, TEAM_PLAYER)) then
					local direction = GetDirection(current - origin[hash(current)])
					damage.sAnimation = "Lightning_Attack_"..direction
					damage.loc = current
					damage.iDamage = DAMAGE_ZERO
					
					ret:AddDamage(damage)
					ret:AddAnimation(current,"Lightning_Hit")
					
					for i = DIR_START, DIR_END do
						local neighbor = current + DIR_VECTORS[i]
						if not explored[hash(neighbor)] then
							todo[#todo + 1] = neighbor
							origin[hash(neighbor)] = current
						end
					end
				else
					local direction = GetDirection(current - origin[hash(current)])
					damage.sAnimation = "Lightning_Attack_"..direction
					damage.loc = current
					damage.iDamage = self.GetDamage()
					
					ret:AddDamage(damage)
				end
			end
		end
	end

	return ret
end

-------------------------------------------------------

Passive_ServoEvade = PassiveSkill:new{
	Name = "Reactive Servos",
	Description = "Reflex shots directed at this unit will be safely evaded.",
	PowerCost = 1,
	Icon = "weapons/passives/passive_servoevade.png",
	Passive = "evade",
	Upgrades = 0,
	Rarity = 1,
	TipImage = {
		Unit = Point(2,3)
	}
}

-------------------------------------------------------

modApi:appendAsset("img/combat/icons/moretimemark.png", mod_loader.mods[modApi.currentMod].resourcePath.."resources/combat/icons/moretimemark.png")
modApi:appendAsset("img/combat/icons/lesstimemark.png", mod_loader.mods[modApi.currentMod].resourcePath.."resources/combat/icons/lesstimemark.png")
Location["combat/icons/moretimemark.png"] = Point(-25,5)
Location["combat/icons/lesstimemark.png"] = Point(-25,5)

Science_ChronoBoost = Skill:new{
	Name = "Temporal Regulator",
	Description = "Move the turn timer forward or backward by one turn. Select the rightmost target for less time, or the leftmost target for more time.",
	PowerCost = 2,
	Icon = "weapons/science_timeskip.png",
	Upgrades = 0,
	Limited = 1,
	Rarity = 1,
	LaunchSound = "/weapons/swap",
	TipImage = {
		Unit = Point(2,2),
		Target = Point(2,2)
	}
}

function Science_ChronoBoost:GetTargetArea(p1)
	local ret = PointList()
	ret:push_back(Point(7, 0))
	ret:push_back(Point(6, 0))
	ret:push_back(Point(7, 1))
	
	ret:push_back(Point(0, 7))
	ret:push_back(Point(1, 7))
	ret:push_back(Point(0, 6))
	return ret
end

function Science_ChronoBoost:GetSkillEffect(p1, p2)
	local ret = SkillEffect()
	local preview = SpaceDamage(p2)
	if Board:GetSize() ~= Point(6,6) then
		if p2==Point(0, 7) or p2==Point(1, 7) or p2==Point(0, 6) then
			if GetCurrentMission() then ret:AddScript("GetCurrentMission().TurnLimit = GetCurrentMission().TurnLimit + 1") end
			preview.sImageMark = "combat/icons/moretimemark.png"
		else
			if GetCurrentMission() then ret:AddScript("GetCurrentMission().TurnLimit = GetCurrentMission().TurnLimit - 1") end
			preview.sImageMark = "combat/icons/lesstimemark.png"
		end
	end
	ret:AddDamage(preview)
	return ret
end

-------------------------------------------------------
