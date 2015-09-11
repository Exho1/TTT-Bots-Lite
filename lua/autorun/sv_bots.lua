if CLIENT then return end

local entmeta = FindMetaTable("Entity")

function entmeta:isDoor()
	if not IsValid( self ) or self:IsPlayer() then return false end
	
	local class = self:GetClass()
	if class == "prop_door_rotating" or class == "func_door" or class == "func_door_rotating" then
		return true
	end
	return false
end

tttBot = tttBot or {}
tttBot.speed = 220

-- Keys = player count. Values = number of bots
tttBot.playerToBotCount = {
	[1] = 7,
	[2] = 7,
	[3] = 6,
	[4] = 6,
	[5] = 5,
	[6] = 4,
	[7] = 3,
	[8] = 2,
	[9] = 1,
}
	
tttBot.spawnedBots = false
tttBot.shouldSpawnBots = true

--// TTTPrepareRound hook to balance the amount of bots in the game
hook.Add("TTTPrepareRound", "tttBots", function()
	local roundsLeft = math.max(0, GetGlobalInt("ttt_rounds_left", 6))
	local maxRounds = GetConVar("ttt_round_limit"):GetInt()
	
	if tttBot.shouldSpawnBots and roundsLeft < maxRounds then 
		local maxPlayers = game.MaxPlayers()
		local curPlayers = #player.GetHumans()
		local curBots = #player.GetBots()
		local botsToHave = tttBot.playerToBotCount[curPlayers] or 0
		
		if curBots < botsToHave then
			-- Create bots
			for i = 1, botsToHave - curBots do
				RunConsoleCommand("bot")
			end
			
			for _, bot in pairs( player.GetBots() ) do
				bot:SetUserGroup( "bot" )
			end
		elseif curBots > botsToHave then
			-- Kick bots
			for i = 1, curBots - botsToHave do
				local unluckyBot = table.Random( player.GetBots() )
			
				unluckyBot:Kick("Lowering bot count")
			end
		end
	else
		-- Remove any existing bots, they shouldn't be in the game anyways
		if #player.GetBots() > 0 then
			for _, v in pairs( player.GetBots() ) do
				v:Kick("Not wanted here")
			end
		end
	end	
	
	-- Reset all the living bots
	for _, ply in pairs( player.GetAll() ) do
		if ply:IsBot() then
			ply:setTarget( nil )
			ply:setNewPos( nil )
			ply.tttBot_endGunSearchTime = -1
		end
	end
end)

--// TTTBeginRound hook to reset the bots, again
hook.Add("TTTBeginRound", "tttBots", function()
	-- Reset all the living bots
	for _, ply in pairs( player.GetAll() ) do
		if ply:IsBot() then
			ply:setTarget( nil )
			ply:setNewPos( nil )
			ply.tttBot_endGunSearchTime = -1
		end
	end
end)

--// Think hook that checks if the last Traitors are bots and slays them to not hold up the round
local nextWinCheck = 0
hook.Add("Think", "tttBotsWin", function()
	if CurTime() > nextWinCheck then
		local aliveBots = 0
		local aliveHumans = 0
		for _, v in pairs( GetTraitors() ) do
			if v:Alive() then
				if v:IsBot() then
					aliveBots = aliveBots + 1
				else
					aliveHumans = aliveHumans + 1
				end	
			end
		end

		if aliveHumans == 0 and aliveBots > 0 then 
			PrintMessage( HUD_PRINTTALK, "The last Traitor(s) are bots and have been slain")
			
			for _, v in pairs( GetTraitors() ) do
				if v:Alive() and v:IsBot() then
					v:Kill()
				end
			end
			
			--[[local convertedInnocents = 0
			for _, v in RandomPairs( player.GetHumans() ) do
				if convertedInnocents < aliveBots then
					if v:Alive() and v:GetRole() == ROLE_INNOCENT then
						v:ChatPrint( "You have been converted to Traitor" )
						v:SetRole( ROLE_TRAITOR )
						v:AddCredits( 1 )
						convertedInnocents = convertedInnocents + 1
					end
				else
					break
				end
			end]]
		end
		
		nextWinCheck = CurTime() + 1
	end
end)

--// StartCommand hook that serves as the backbone to run the bots
hook.Add("StartCommand", "tttBots", function( ply, cmd )
	if ply:IsBot() and IsValid( ply ) then
		ply.cmd = cmd
		
		if ply:Alive() then
			ply:lerpAngles()
			
			--[[ply:setTarget( findExho() )
			
			ply:setNewAngles( Angle( 0, 270, 0 ) )
			
			local clearLOS = ply:clearLOS( ply:getTarget() )
			local vectorVisible = ply:isVectorVisible( ply:getTarget():GetPos() )
			
			findExho():ChatPrint(tostring(clearLOS).." "..tostring(vectorVisible))
			
			ply:idle()]]
			
			if GetRoundState() == ROUND_ACTIVE then
			
				--// INNOCENT BOT LOGIC
				if ply:GetRole() == ROLE_INNOCENT then
					if IsValid( ply:getTarget() ) then
						ply:huntTarget()
					elseif not ply:hasGuns() then
						--ply:findWeapon() -- Finding weapons seems to be broken
						ply:wander()
						ply:selectCrowbar()
					else
						ply:wander()
					end
				end
				
				--// DETECTIVE BOT LOGIC
				if ply:GetRole() == ROLE_DETECTIVE then
					local vsrc = ply:GetShootPos()
					local vang = ply:GetAimVector()
					local vvel = ply:GetVelocity()
      
					local vthrow = vvel + vang * 200
	  
					-- Drop a health station to help out the innocents
					local health = ents.Create("ttt_health_station")
					if IsValid(health) then
						health:SetPos(vsrc + vang * 10)
						health:Spawn()

						health:SetPlacer(ply)

						health:PhysWake()
						local phys = health:GetPhysicsObject()
						if IsValid(phys) then
							phys:SetVelocity(vthrow)
						end
					end
					
					-- Remove a credit because of the health station and kill the bot
					ply:AddCredits( -1 )
					ply:Kill()
					ply:AddFrags( -1 )
					
					-- ID their body
					ply:SetNWBool("body_found", true)
					local dti = CORPSE.dti
					ply.server_ragdoll:SetDTBool(dti.BOOL_FOUND, true)
				end
				
				--// TRAITOR BOT LOGIC
				if ply:GetRole() == ROLE_TRAITOR then
					ply.tttBot_endGunSearchTime = ply.tttBot_endGunSearchTime or 0
					
					-- Set a period of time that the bot will search for weapons before trying to kill players
					if ply.tttBot_endGunSearchTime == -1 then
						ply.tttBot_endGunSearchTime = CurTime() + math.random(15, 45)
					end
					
					-- Its time!
					if CurTime() > ply.tttBot_endGunSearchTime then
						-- Get a target and hunt them down
						if not IsValid( ply:getTarget() ) or not ply:getTarget():Alive() then
							print("New target - StartCommand")
							ply:setTarget( ply:findNewTarget( true ) )
						end

						ply:huntTarget()
					else
						-- Search for weapons
						if not ply:hasGuns() then
							ply:findWeapon()
						end
					end
				end
			else
				ply:setTarget( nil )
				ply:idle()
			end
		else
			ply:idle()
		end
	end
end)

--// EntityTakeDamage hook so bots can fight back
hook.Add("EntityTakeDamage", "tttBots", function( ply, dmginfo )
	if ply.IsBot and ply:IsBot() then
		if not IsValid( ply:getTarget() ) then
			if !dmginfo:IsDamageType( DMG_BURN ) and !dmginfo:IsDamageType( DMG_BLAST ) then
				local target = dmginfo:GetAttacker()
				
				local ang = ply:EyeAngles()
				local tPos = target:GetPos() 
				local pos = ply:GetPos()
				local dist = pos:Distance( tPos )
				
				yaw = math.deg(math.atan2(tPos.y - pos.y, tPos.x - pos.x))
				pitch = math.deg(math.atan2( -(tPos.z - pos.z), dist))
				
				local sign = math.random(2) and 1 or -1
				
				-- Only lock onto the targets that the bot can see 
				if ply:isVectorVisible( target:GetPos() ) then
					ply:setTarget( dmginfo:GetAttacker() )
					ply:setNewAngles( Angle( ang.p + math.random(-10, 10), yaw, 0 ) )
				else
					-- Look around randomly in an attempt to find who shot us
					ply:setNewAngles( Angle( ang.p + math.random(-50, 50), yaw + (math.random(50, 150)*sign), 0 ) )
				end
			end
		end
	end
end)

--// Player metatable functions
local plymeta = FindMetaTable("Player")

function plymeta:GetAvoidDetective()
	if self.IsBot and self:IsBot() then return true end
	
	return self:GetInfoNum("ttt_avoid_detective", 0) > 0
end

function plymeta:setTarget( target )
	self.tttBot_target = target
end

function plymeta:getTarget()
	return self.tttBot_target
end

function plymeta:setNewPos( vector )
	self.tttBot_newPos = vector
end

function plymeta:getNewPos()
	return self.tttBot_newPos
end

function plymeta:setNewAngles( ang )
	self.tttBot_oldAng = self:EyeAngles()
	self.tttBot_newAng = ang
end

function plymeta:getNewAngles()
	return self.tttBot_newAng, self.tttBot_oldAng
end

function plymeta:idle()
	local cmd = self.cmd
	
	cmd:ClearMovement()
	cmd:ClearButtons()
end

--// General bot AI functions

--// Locates a new player to attack thats close
function plymeta:findNewTarget( bLazy )
	local players = player.GetAll()

	local target 
	local closestDist = 100000
	
	if #players > 1 then
		for key, ply in pairs( players ) do
			if IsValid( ply ) and ply:Alive() and ply != self and ply:GetRole() != self:GetRole() then
				local dist = self:GetPos():Distance( ply:GetPos() )
				
				if dist < closestDist and (bLazy or self:isVectorVisible( ply:GetPos() )) then
					closestDist = dist
					target = ply
				end
			end
		end
	end
	
	-- Can't immediately find a target, wander around some more
	if not IsValid( target ) then
		self.tttBot_endGunSearchTime = CurTime() + math.random(5, 15)
	end

	return target
end

--// Lerps the bot's angles between their current and new ones.
function plymeta:lerpAngles()	
	local cmd = self.cmd

	local eyeAng = self.tttBot_oldAng or self:EyeAngles()
	local newAng = self.tttBot_newAng
	
	if newAng then
		cmd:SetViewAngles( LerpAngle( 0.7, eyeAng, newAng ) )
	end
end

--// Returns if the the bot can see the given vector
function plymeta:isVectorVisible( pos )
	local cone = math.cos( 30 )
	local dir = (self:GetPos() - pos):GetNormal()
	
	-- Math that I don't understand
	local dot = self:GetForward():Dot( -dir )
	
	local visible = false
	
	if dot > cone then
		visible = true
	end
	
	return visible, dot
end

--// Hunts down and kills the target
local nextPosTrace = 0
function plymeta:huntTarget()
	local cmd = self.cmd
	
	if self:targetIsValid() then
		local ang = self:EyeAngles()
		local tPos = self:getTarget():GetPos()
		local pos = self:GetPos()
		local dist = pos:Distance( tPos )
		
		yaw = math.deg(math.atan2(tPos.y - pos.y, tPos.x - pos.x))
		pitch = math.deg(math.atan2( -(tPos.z - pos.z), dist))
		
		-- Is there a clear line between us and the target?
		-- Is the target in our cone of view?
		local clearLOS = self:clearLOS( self:getTarget() )
		local vectorVisible = true
		
		--print(vectorVisible, clearLOS)
		
		-- The target is within our cone of vision and we can see them
		if vectorVisible and clearLOS then
			--self:setNewAngles( Angle( pitch, yaw, 0 ) )
			self.targetPos = tPos
			
			if CurTime() > nextPosTrace then
				local tracedata = {}
				tracedata.start = tPos
				tracedata.filter = {self}
				tracedata.endpos = tPos + ang:Forward() * 1000
				local trace = util.TraceLine(tracedata)
				
				self:setNewPos( trace.HitPos )
				
				nextPosTrace = CurTime() + 2
			end
		end
		
		-- If we have a last known position of our target, run towards it
		if self.targetPos then
			if not clearLOS and self.targetPos:Distance( self:GetPos() ) < 25 then
				-- We can't see the target and we reached their last known position
				-- They are gone
				self:setTarget( nil )
			else
				cmd:SetForwardMove( tttBot.speed )
				self:lookAtPos( self.targetPos )
			end
		else
			-- Otherwise Traitor bots should find a new target and everyone else should wander
			if self:GetRole() == ROLE_TRAITOR then
				self:setTarget( self:findNewTarget() )
			else
				self:wander()
			end
		end
		
		if not IsValid( self:GetActiveWeapon() ) then return end
		
		local activeClass = self:GetActiveWeapon():GetClass()
		
		-- We have weapons
		if self:hasGuns() then
			self:selectGun()
			if clearLOS then
				-- Shoot at them
				self:attackTarget()
				
				-- Fake some revoil
				local ang = Angle(pitch, yaw, 0)
				cmd:SetViewAngles( Angle(ang.p + math.random(5, 10), ang.y + math.random(-5,5), ang.r) )
			else
				cmd:ClearButtons()
			end
		elseif dist < 70 and clearLOS then
			-- Whack the target
			self:selectCrowbar()
			self:attackTarget()
		end
	else
		if self:GetRole() == ROLE_TRAITOR then
			print("New target - Hunt")
			self:setTarget( self:findNewTarget( ) )
		else
			print("Delete target - Hunt")
			self:setTarget( nil )
		end
	end
end

local spawns = {
	"info_player_deathmatch", "info_player_combine",
	"info_player_rebel", "info_player_counterterrorist", "info_player_terrorist",
	"info_player_axis", "info_player_allies", "gmod_player_start",
	"info_player_teamspawn", "info_player_start"
}

--// Makes the bot walk between random positions and search for guns every so often
function plymeta:wander()
	local cmd = self.cmd
	
	local newPos = self:getNewPos()
	
	if newPos and self:GetPos():Distance( newPos ) > 50 and math.abs(newPos.z - self:GetPos().z) < 200 then
		self:lookAtPos( newPos )
		cmd:SetForwardMove( tttBot.speed )
	else
		self.tttBot_nextWeaponSearch = self.tttBot_nextWeaponSearch or 0
		
		if CurTime() > self.tttBot_nextWeaponSearch and not self:hasGuns() then
			-- Search for a weapon 
			local wep = self:findWeapon()
			
			if not wep then
				self.tttBot_nextWeaponSearch = CurTime() + 5
			end
		else
			-- Wander around the map
			local spawnpoints = {}
				
			for _, ent in pairs( ents.GetAll() ) do
				for _, class in pairs( spawns ) do
					if ent:GetClass():lower() == class:lower() then
						table.insert( spawnpoints, ent )
					end
				end
			end
			
			for _, v in pairs( player.GetAll() ) do
				if v:Alive() then
					table.insert( spawnpoints, v )
				end
			end
			
			local spawn = table.Random( spawnpoints )

			self:setNewPos( spawn:GetPos() + Vector( 0, 0, 30 ) )
		end
	end
end

--// Makes the bot look at a vector
function plymeta:lookAtPos( vector )
	if not IsValid( self ) then return end
	local cmd = self.cmd
	local target = self:getTarget()
	
	local pos = self:GetPos()
	local dist = pos:Distance( vector )
	
	yaw = math.deg(math.atan2(vector.y - pos.y, vector.x - pos.x))
	pitch = math.deg(math.atan2( -(vector.z - pos.z), dist))
	
	self:setNewAngles( Angle( pitch, yaw, 0 ) )
end

--// Returns if the bot's target is valid
function plymeta:targetIsValid()
	local cmd = self.cmd
	local target = self:getTarget()
	
	if not IsValid( target ) then return false end
	if not target:Alive() then return false end
	if target:IsSpec() then return false end
	
	if self:GetRole() == ROLE_TRAITOR then
		-- Don't RDM T buddies
		if target:GetRole() == self:GetRole() then return false end
	end

	return true
end

--// Checks to see if there is a clear line between the bot's head and the target's head
function plymeta:clearLOS( target )
	local head = target:LookupBone("ValveBiped.Bip01_Head1")
	if head != nil then
		local headpos = target:GetBonePosition(head)
		
		local pos = self:GetShootPos()
		local ang = (headpos - self:GetShootPos()):Angle()
		local tracedata = {}
		tracedata.start = pos
		tracedata.filter = {self}
		tracedata.endpos = target:GetShootPos() + ang:Forward() * 10000
		local trace = util.TraceLine(tracedata)
		
		if IsValid( trace.Entity ) and trace.Entity == target then
			return true
		end
	end
	return false
end

--// Searches the world to try to find weapons to pick up
function plymeta:findWeapon()
	local cmd = self.cmd
	local weps = {}
	
	for _, ent in pairs( ents.GetAll() ) do
		if ent:IsWeapon() and not IsValid( ent:GetOwner() ) then
			table.insert( weps, ent )
		end
	end
	
	local closestDist = 100000
	local closestKey = 0
	for k, wep in pairs( weps ) do
		if tttBot.weaponIsValid( wep ) then
			local dist = self:GetPos():Distance( wep:GetPos() )
			
			if dist < closestDist then
				if self:GetEyeTrace().Entity == wep then
					closestDist = dist
					closestKey = k
				end
			end
		end
	end
	
	if IsValid( weps[closestKey] ) then
		self:setNewPos( weps[closestKey]:GetPos() )
	end
	
	return weps[closestKey]
end

--// Attacks 
function plymeta:attackTarget()
	local cmd = self.cmd
	
	cmd:SetButtons(IN_ATTACK)
end

--// Helper function to select the crowbar
function plymeta:selectCrowbar()
	local cmd = self.cmd
	
	for _, v in pairs( self:GetWeapons() ) do
		if v:GetClass() == "weapon_zm_improvised" then
			cmd:SelectWeapon( v )
		end
	end
end

--// Tells the bot to select the first weapon it has
function plymeta:selectGun( class )
	local cmd = self.cmd
	
	class = class or "N/A"
	
	for _, v in pairs( self:GetWeapons() ) do
		if tttBot.weaponIsNotDefault( v ) or v:GetClass():lower() == class:lower() then
			cmd:SelectWeapon( v )
		end
	end
end

--// Returns true if the bot has a gun with ammo
function plymeta:hasGuns()
	local cmd = self.cmd
	
	for _, v in pairs( self:GetWeapons() ) do
		if tttBot.weaponIsNotDefault( v ) then
			if v:Ammo1() > 0 or v:Clip1() > 0 then
				return true
			end
		end
	end
end

--// Returns if the weapon is valid for the bot to pick up
function tttBot.weaponIsValid( wep )
	if not IsValid( wep ) then return false end
	if IsValid( wep:GetOwner() ) then return false end
	
	return true
end

--// Returns if the given weapon is not a default weapon
function tttBot.weaponIsNotDefault( wep )
	if wep:GetClass() == "weapon_zm_improvised" or wep:GetClass() == "weapon_ttt_unarmed" or wep:GetClass() == "weapon_zm_carry" then
		return false
	end
	
	return true
end