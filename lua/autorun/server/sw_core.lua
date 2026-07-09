if not SERVER then return end

SW = SW or {}

include("hyper-superwhitelist/sh_util.lua")

local Util = SW.Util
local NS   = "hyper.superwhitelist"

SW._Cache  = SW._Cache or {}
SW._Count  = SW._Count or 0
SW._Loaded = SW._Loaded or false
SW._Empty  = true

local enforcing     = {}
local protected     = {}
local alertCooldown = {}

local VALID_MODES = {
	log         = true,
	demote      = true,
	kick        = true,
	kick_demote = true,
	kick_ban    = true,
}

local function buildCache(source)
	local cache, count, skipped = {}, 0, 0

	for rawID, groups in pairs(source) do
		local sid64 = Util.NormalizeSteamID64(rawID)
		if not sid64 then
			skipped = skipped + 1
			Util.Warn("Ignoring invalid SteamID in whitelist: %s", tostring(rawID))
		else
			local entry = cache[sid64]
			if not entry then
				entry = {}
				cache[sid64] = entry
				count = count + 1
			end

			if istable(groups) then
				for _, g in ipairs(groups) do
					if isstring(g) then entry[string.lower(g)] = true end
				end
			elseif isstring(groups) then
				entry[string.lower(groups)] = true
			end
		end
	end

	return cache, count, skipped
end

local function rebuildProtected()
	local lookup = {}
	if istable(SW.ProtectedGroups) then
		for _, g in ipairs(SW.ProtectedGroups) do
			if isstring(g) then lookup[string.lower(g)] = true end
		end
	end
	protected = lookup
end

local function isProtected(lgroup) return protected[lgroup] == true end
local function isAuthorized(sid64, lgroup)
	local entry = sid64 and SW._Cache[sid64]
	return entry ~= nil and entry[lgroup] == true
end

function SW.IsAuthorized(sid64, group)
	if not isstring(sid64) or not isstring(group) then return false end
	return isAuthorized(sid64, string.lower(group))
end

local function defaultGroupUsable()
	local dg = SW.DefaultGroup
	return isstring(dg) and dg ~= "" and not isProtected(string.lower(dg))
end

local function enforcementSuspended()
	return SW._Empty and not SW.AllowEmptyWhitelist
end

local function validateConfig()
	if not VALID_MODES[SW.EnforcementMode or ""] then
		Util.Warn("EnforcementMode '%s' is not recognised; using 'kick_demote'.", tostring(SW.EnforcementMode))
		SW.EnforcementMode = "kick_demote"
	end
	if not defaultGroupUsable() then
		Util.Warn("SW.DefaultGroup '%s' is empty or protected; demotions are refused until this is fixed.", tostring(SW.DefaultGroup))
	end
end

local function applyCache(cache, count, skipped, label)
	if count == 0 and SW._Count > 0 and not SW.AllowEmptyWhitelist then
		Util.Warn("%s came back empty while %d entries are cached; keeping the current cache. Set SW.AllowEmptyWhitelist to override.", label, SW._Count)
		return false
	end

	SW._Cache, SW._Count, SW._Loaded = cache, count, true
	SW._Empty = count == 0

	Util.Log("Loaded %d whitelisted SteamID(s) from %s%s.", count, label,
		skipped > 0 and string.format(" (%d invalid skipped)", skipped) or "")

	if enforcementSuspended() then
		Util.Warn("Whitelist is empty - enforcement is SUSPENDED. Add entries or set SW.AllowEmptyWhitelist.")
	end
	return true
end

local function loadHardcoded(onDone)
	local cache, count, skipped = buildCache(istable(SW.Whitelist) and SW.Whitelist or {})
	applyCache(cache, count, skipped, "hardcoded config")
	if onDone then onDone(true) end
end

local db
local mysqlReady, querying, reconnecting = false, false, false

local function mysqlConnected()
	return db ~= nil and mysqlReady and mysqloo ~= nil and db:status() == mysqloo.DATABASE_CONNECTED
end

local function scheduleReconnect()
	if reconnecting or not mysqloo then return end
	reconnecting, mysqlReady = true, false

	local delay = tonumber(SW.ReconnectDelay) or 5
	Util.Warn("MySQL connection lost; retrying every %ds.", delay)

	timer.Create(NS .. ".reconnect", delay, 0, function()
		if not db then
			timer.Remove(NS .. ".reconnect")
			reconnecting = false
			return
		end
		if db:status() == mysqloo.DATABASE_CONNECTED then
			timer.Remove(NS .. ".reconnect")
			reconnecting, mysqlReady = false, true
			return
		end
		Util.Log("Attempting MySQL reconnect...")
		db:connect()
	end)
end

local function loadMySQL(onDone)
	if not mysqlConnected() then
		Util.Warn("MySQL is not connected; whitelist was not refreshed.")
		if onDone then onDone(false) end
		return
	end
	if querying then
		Util.Warn("A whitelist query is already running; ignoring the duplicate reload.")
		if onDone then onDone(false) end
		return
	end

	querying = true
	local q = db:query("SELECT steamid, allowed_group FROM sw_whitelist")
	if not q then
		querying = false
		Util.Warn("Failed to create the MySQL query.")
		if onDone then onDone(false) end
		return
	end

	function q:onSuccess(rows)
		querying = false

		local source = {}
		for _, row in ipairs(rows or {}) do
			local sid = row.steamid
			if isstring(sid) then
				local list = source[sid]
				if not list then list = {}; source[sid] = list end
				if isstring(row.allowed_group) then
					list[#list + 1] = row.allowed_group
				end
			end
		end

		local cache, count, skipped = buildCache(source)
		applyCache(cache, count, skipped, "MySQL")
		if onDone then onDone(true) end
	end

	function q:onError(err)
		querying = false
		Util.Warn("MySQL whitelist query failed: %s", tostring(err))
		if db and mysqloo and db:status() ~= mysqloo.DATABASE_CONNECTED then
			scheduleReconnect()
		end
		if onDone then onDone(false) end
	end

	q:start()
end

local function startKeepAlive()
	timer.Create(NS .. ".keepalive", tonumber(SW.KeepAliveInterval) or 30, 0, function()
		if not db or not mysqloo then return end
		if db:status() ~= mysqloo.DATABASE_CONNECTED then
			scheduleReconnect()
			return
		end
		local q = db:query("SELECT 1")
		if not q then return end
		function q:onError(err)
			Util.Warn("MySQL keepalive failed: %s", tostring(err))
			scheduleReconnect()
		end
		q:start()
	end)
end

local function connectMySQL()
	if SW.Storage ~= "mysql" then return end

	if not pcall(require, "mysqloo") or not mysqloo then
		Util.Warn("mysqloo module not found; MySQL storage is unavailable and enforcement will NOT start.")
		return
	end

	local cfg = SW.MySQL or {}
	if not isstring(cfg.host) or cfg.host == "" or not isstring(cfg.database) or cfg.database == "" then
		Util.Warn("MySQL config is incomplete (host/database); enforcement will NOT start.")
		return
	end

	db = mysqloo.connect(cfg.host, cfg.username or "", cfg.password or "", cfg.database, tonumber(cfg.port) or 3306)

	function db:onConnected()
		mysqlReady, reconnecting = true, false
		timer.Remove(NS .. ".reconnect")
		Util.Log("Connected to MySQL database '%s'.", tostring(cfg.database))
		loadMySQL()
	end

	function db:onConnectionFailed(err)
		mysqlReady = false
		Util.Warn("MySQL connection failed: %s", tostring(err))
		scheduleReconnect()
	end

	db:connect()
	startKeepAlive()
end

local backends = {}

backends.hardcoded = loadHardcoded

function backends.mysql(onDone)
	if mysqlConnected() then
		loadMySQL(onDone)
	elseif reconnecting then
		Util.Warn("MySQL is reconnecting; the reload will pick up once it's back.")
		if onDone then onDone(false) end
	else
		connectMySQL()
		if onDone then onDone(false) end
	end
end

local function activeBackend()
	return backends[SW.Storage] or backends.hardcoded
end

function SW.Reload(onDone)
	rebuildProtected()
	validateConfig()
	activeBackend()(onDone)
end

local webhookQueue, webhookDraining = {}, false

local function drainWebhook()
	local item = table.remove(webhookQueue, 1)
	if not item then
		webhookDraining = false
		return
	end

	HTTP({
		url    = item.url,
		method = "POST",
		type   = "application/json",
		body   = item.body,
		success = function(code)
			if code < 200 or code >= 300 then
				Util.Warn("Discord webhook returned HTTP %d.", code)
			end
		end,
		failed = function(reason)
			Util.Warn("Discord webhook request failed: %s", tostring(reason))
		end,
	})

	timer.Simple(tonumber(SW.WebhookRate) or 2, drainWebhook)
end

local function sanitize(str, maxLen)
	if not isstring(str) then return "unknown" end
	str = string.gsub(str, "[`@\r\n]", " ")
	return #str > maxLen and string.sub(str, 1, maxLen) or str
end

local function sendDiscordAlert(info)
	local url = SW.DiscordWebhook
	if not isstring(url) or url == "" then return end

	if #webhookQueue >= (tonumber(SW.WebhookQueueLimit) or 50) then
		Util.Warn("Discord webhook queue is full; dropping alert for %s.", tostring(info.sid64))
		return
	end

	local payload = {
		username = "SuperWhitelist",
		embeds = { {
			title = "Unauthorized rank change detected",
			color = 15158332,
			fields = {
				{ name = "Player",          value = sanitize(info.name, 200),  inline = true },
				{ name = "SteamID64",       value = sanitize(info.sid64, 32),  inline = true },
				{ name = "Attempted group", value = sanitize(info.group, 64),  inline = true },
				{ name = "Action taken",    value = sanitize(info.action, 200), inline = false },
			},
			footer = { text = "hyper-superwhitelist" },
			timestamp = Util.Timestamp(),
		} },
	}

	webhookQueue[#webhookQueue + 1] = { url = url, body = util.TableToJSON(payload) }
	if not webhookDraining then
		webhookDraining = true
		drainWebhook()
	end
end

local function shouldAlert(sid64)
	local now = SysTime()
	if (alertCooldown[sid64] or 0) > now then return false end
	alertCooldown[sid64] = now + (tonumber(SW.AlertCooldown) or 300)
	return true
end

local function punish(ply, sid64)
	local mode = SW.EnforcementMode or "kick_demote"

	if mode == "log" or enforcementSuspended() then
		return "logged only"
	end
	if not defaultGroupUsable() then
		Util.Warn("SW.DefaultGroup '%s' is empty or protected; refusing to enforce. Fix your config.", tostring(SW.DefaultGroup))
		return "aborted (misconfigured DefaultGroup)"
	end

	local default = SW.DefaultGroup
	enforcing[sid64] = true
	local old = ply:GetUserGroup()
	SW._SetUserGroup(ply, default) -- original method; the detour would just recurse
	if CAMI and CAMI.SignalUserGroupChanged then
		CAMI.SignalUserGroupChanged(ply, old, default, "hyper-superwhitelist")
	end
	enforcing[sid64] = nil

	if mode == "demote" then
		return "demoted to " .. default
	elseif mode == "kick" or mode == "kick_demote" then
		local reason = isstring(SW.BanReason) and SW.BanReason or "Unauthorized rank change"
		timer.Simple(0, function() if IsValid(ply) then ply:Kick(reason) end end)
		return "demoted and kicked"
	elseif mode == "kick_ban" then
		local minutes = math.max(0, math.floor(tonumber(SW.BanDuration) or 0))
		timer.Simple(0, function()
			if not IsValid(ply) then return end
			ply:Ban(minutes, true)
			RunConsoleCommand("writeid")
		end)
		return minutes > 0
			and ("demoted and banned for " .. minutes .. " minute(s)")
			or "demoted and permanently banned"
	end

	return "logged only"
end

local function enforce(ply, group)
	if not IsValid(ply) then return end
	local sid64 = ply:SteamID64()
	if not isstring(sid64) then return end

	local action = punish(ply, sid64)
	if shouldAlert(sid64) then
		Util.Warn("Violation: %s <%s> held protected group '%s' -> %s.", ply:Nick(), sid64, tostring(group), action)
		sendDiscordAlert({ name = ply:Nick(), sid64 = sid64, group = group, action = action })
	end
end

local function checkPlayer(ply, group)
	if not isstring(group) then return end
	local lgroup = string.lower(group)
	if not isProtected(lgroup) then return end
	if not isAuthorized(ply:SteamID64(), lgroup) then
		enforce(ply, group)
	end
end

local function validatePlayer(ply)
	if not SW._Loaded or not IsValid(ply) or not ply:IsPlayer() then return end
	checkPlayer(ply, ply:GetUserGroup())
end

local PLAYER = FindMetaTable("Player")
SW._SetUserGroup = SW._SetUserGroup or PLAYER.SetUserGroup

if SW.DetourSetUserGroup ~= false then
	function PLAYER:SetUserGroup(name)
		SW._SetUserGroup(self, name)
		if not SW._Loaded then return end
		local sid64 = self:SteamID64()
		if sid64 and enforcing[sid64] then return end
		validatePlayer(self)
	end
else
	PLAYER.SetUserGroup = SW._SetUserGroup
end

hook.Add("CAMI.PlayerUsergroupChanged", NS .. ".cami_player", function(ply, _, newGroup)
	if not SW._Loaded or not IsValid(ply) then return end
	local sid64 = ply:SteamID64()
	if sid64 and enforcing[sid64] then return end
	checkPlayer(ply, newGroup)
end)

hook.Add("CAMI.SteamIDUsergroupChanged", NS .. ".cami_steamid", function(steamId, _, newGroup)
	if not SW._Loaded or not isstring(newGroup) then return end
	if not isProtected(string.lower(newGroup)) then return end

	local sid64 = Util.NormalizeSteamID64(steamId)
	if not sid64 or enforcing[sid64] then return end
	if isAuthorized(sid64, string.lower(newGroup)) then return end

	local ply = player.GetBySteamID64(sid64)
	if IsValid(ply) then
		enforce(ply, newGroup)
	elseif shouldAlert(sid64) then
		Util.Warn("Offline SteamID %s was granted protected group '%s' without authorization; will enforce on join.", sid64, tostring(newGroup))
		sendDiscordAlert({ name = "(offline)", sid64 = sid64, group = newGroup, action = "flagged; enforced on join" })
	end
end)

hook.Add("PlayerInitialSpawn", NS .. ".initial_spawn", function(ply)
	timer.Simple(0, function() validatePlayer(ply) end)
	timer.Simple(3, function() validatePlayer(ply) end)
end)

local function startSweep()
	timer.Remove(NS .. ".sweep")
	local interval = tonumber(SW.RecheckInterval) or 60
	if interval <= 0 then return end

	timer.Create(NS .. ".sweep", interval, 0, function()
		local players = player.GetAll()
		for i = 1, #players do
			validatePlayer(players[i])
		end
	end)
end

local function callerAllowed(ply)
	return not IsValid(ply) or ply:IsSuperAdmin()
end

local function reply(ply, msg)
	if IsValid(ply) then
		ply:PrintMessage(HUD_PRINTCONSOLE, "[SuperWhitelist] " .. msg)
	else
		Util.Log("%s", msg)
	end
end

concommand.Add("sw_reload", function(ply)
	if not callerAllowed(ply) then return end

	local who = IsValid(ply) and ply:Nick() or "console"
	SW.Reload(function(ok)
		if ok then
			reply(ply, string.format("Reload complete: %d SteamID(s) cached.", SW._Count))
			Util.Log("Whitelist reloaded by %s.", who)
		else
			reply(ply, "Reload did not complete; check the server console.")
		end
	end)
end)

concommand.Add("sw_check", function(ply, _, args)
	if not callerAllowed(ply) then return end

	local raw = args[1]
	if not raw then
		reply(ply, "Usage: sw_check <steamid or steamid64>")
		return
	end

	local sid64 = Util.NormalizeSteamID64(raw)
	if not sid64 then
		reply(ply, "Invalid SteamID: " .. tostring(raw))
		return
	end

	local entry = SW._Cache[sid64]
	local groups = {}
	if entry then
		for g in pairs(entry) do groups[#groups + 1] = g end
	end

	if #groups == 0 then
		reply(ply, sid64 .. " is NOT whitelisted for any protected group.")
	else
		reply(ply, sid64 .. " is whitelisted for: " .. table.concat(groups, ", "))
	end
end)

rebuildProtected()
validateConfig()
activeBackend()()
startSweep()

Util.Log("Enforcement active (mode: %s, storage: %s, recheck: %ss).",
	tostring(SW.EnforcementMode), tostring(SW.Storage), tostring(SW.RecheckInterval))
