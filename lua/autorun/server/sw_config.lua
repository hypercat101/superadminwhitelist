--[[----------------------------------------------------------------------------
    hyper-superwhitelist  ::  configuration

    This is the only file you need to edit. Authorization is by SteamID only,
    never by name, and nothing here is ever sent to clients.
------------------------------------------------------------------------------]]
if not SERVER then return end

SW = SW or {}

--[[ Storage ---------------------------------------------------------------- ]]

-- "hardcoded" reads SW.Whitelist below. "mysql" reads a database (needs mysqloo).
SW.Storage = "hardcoded"

-- SteamID -> the usergroups that SteamID is allowed to hold.
-- Keys may be STEAM_0:X:XXXXXXX or a 64-bit SteamID; both work.
SW.Whitelist = {
	-- ["STEAM_0:1:11101"]   = { "superadmin" },
	-- ["76561197960287930"] = { "superadmin", "owner" },
}

--[[ Groups ----------------------------------------------------------------- ]]

-- Groups that require a whitelist entry. Holding one without an entry is a violation.
SW.ProtectedGroups = { "superadmin", "owner" }

-- Where violators are put back to. Must NOT be one of SW.ProtectedGroups.
SW.DefaultGroup = "user"

--[[ Enforcement ------------------------------------------------------------ ]]

-- "log" | "demote" | "kick" | "kick_demote" | "kick_ban"
SW.EnforcementMode = "kick_demote"

-- Ban length in minutes for "kick_ban" (0 = permanent), and the kick/ban reason.
SW.BanDuration = 0
SW.BanReason   = "Unauthorized rank detected"

-- Seconds between full re-validation sweeps. 0 disables the sweep.
SW.RecheckInterval = 60

--[[ Safety ----------------------------------------------------------------- ]]

-- Keep false. When the whitelist resolves to zero entries, enforcement is
-- SUSPENDED so a typo or a database blip can't demote or ban your whole staff.
-- Set true only if an empty list is meant to punish every protected-group holder.
SW.AllowEmptyWhitelist = false

-- Fallback detour of Player:SetUserGroup, for admin systems that change groups
-- without firing CAMI. Set false if it conflicts with another addon.
SW.DetourSetUserGroup = true

--[[ Alerts ----------------------------------------------------------------- ]]

-- Discord webhook for violation alerts. Empty = disabled.
SW.DiscordWebhook = ""

-- Seconds to suppress repeat alerts for the same SteamID (anti-spam).
SW.AlertCooldown = 300

--[[ (safe defaults - leave these unless you have a reason) ---------- ]]

SW.WebhookRate       = 2   -- seconds between Discord sends
SW.WebhookQueueLimit = 50  -- queued alerts before the overflow is dropped
SW.ReconnectDelay    = 5   -- seconds between MySQL reconnect attempts
SW.KeepAliveInterval = 30  -- seconds between MySQL keepalive pings

--[[ MySQL (only used when SW.Storage == "mysql") --------------------------- ]]

SW.MySQL = {
	host     = "",
	username = "",
	password = "",
	database = "",
	port     = 3306,
}
