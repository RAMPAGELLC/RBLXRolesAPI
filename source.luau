-- Copyright (c) 2024 RAMPAGE Interactive
-- Written by vq9o

-- License: MIT
-- GitHub: https://github.com/RAMPAGELLC/RBLXRolesAPI

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Constants.Config)

export type RoleName = string
export type Role = {
	Name: RoleName,
	Everyone: boolean?,
	Players: { string | number }?,
	Teams: { Team }?,
	Groups: { { number? } }?,
	Roles: { RoleName }?,
	DiscordRoles: { string }?,
	Gamepass: { number }?,
	RequireAll: boolean?,
}

local Service = {}

function Service:GetRoleConfigByName(roleName: RoleName): Role?
	for _, role in pairs(Config.Roles) do
		if string.upper(role.Name) == string.upper(roleName) then
			return role
		end
	end

	return nil
end

function Service:HasDiscordRole(player: Player, roleId: string | number): boolean
	local playerData = _G.PlayerData and _G.PlayerData[player.Name]

	if playerData and playerData.DiscordRoles then
		return table.find(playerData.DiscordRoles, tostring(roleId)) ~= nil
	end

	return false
end

function Service:HasAllRoles(player: Player, roles: { RoleName }): boolean
	for _, role in pairs(roles) do
		if not self:HasRole(player, role) then
			return false
		end
	end

	return true
end

function Service:HasAnyRole(player: Player, roles: { RoleName }): boolean
	for _, role in pairs(roles) do
		if self:HasRole(player, role) then
			return true
		end
	end

	return false
end

function Service:HasRole(player: Player, roleName: RoleName): boolean
	local role = self:GetRoleConfigByName(roleName)

	if not role then
		warn(("%s role does not exist!"):format(roleName), debug.traceback())
		return false
	end

	if role.Everyone then
		return true
	end

	local requireAll = role.RequireAll or false
	local hasPerm: { [string]: boolean } = {}

	local function checkCondition(condition: boolean, category: string): boolean
		if condition then
			if requireAll then
				hasPerm[category] = true
			else
				return true
			end
		end

		return false
	end

	if role.Gamepass then
		for _, passId in pairs(role.Gamepass) do
			local owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)

			if checkCondition(owns, "Gamepass") then
				return true
			end
		end
	end

	if role.Teams then
		for _, team in pairs(role.Teams) do
			if checkCondition(player.Team == team, "Teams") then
				return true
			end
		end
	end

	if role.DiscordRoles then
		for _, discordId in pairs(role.DiscordRoles) do
			if checkCondition(self:HasDiscordRole(player, discordId), "DiscordRoles") then
				return true
			end
		end
	end

	if role.Players then
		for _, value in pairs(role.Players) do
			if
				checkCondition(
					(typeof(value) == "number" and player.UserId == value)
						or (typeof(value) == "string" and player.Name == value),
					"Players"
				)
			then
				return true
			end
		end
	end

	if role.Groups then
		for _, group in pairs(role.Groups) do
			if checkCondition(player:GetRankInGroup(group[1]) >= (group[2] or 1), "Groups") then
				return true
			end
		end
	end

	if role.Roles then
		for _, subRole in pairs(role.Roles) do
			if checkCondition(self:HasRole(player, subRole), "Roles") then
				return true
			end
		end
	end

	if requireAll then
		local passCount = 0

		for _, v in pairs(hasPerm) do
			if v then
				passCount += 1
			end
		end

		return passCount >= #hasPerm
	end

	return false
end

return Service
