if not SERVER then return end

SW = SW or {}

-- "hardcoded" (SW.Whitelist below) or "mysql" (needs the mysqloo module).
SW.Storage = "hardcoded"

-- SteamID -> allowed groups. STEAM_0:X:Y or 64-bit keys both work.
SW.Whitelist = {
	-- ["STEAM_0:1:11101"]   = { "superadmin" },
	-- ["76561197960287930"] = { "superadmin", "owner" },
}

-- Groups that require a whitelist entry to hold.
SW.ProtectedGroups = { "superadmin", "owner" }

-- Where violators are sent. Must not be a protected group.
SW.DefaultGroup = "user"

-- "log" | "demote" | "kick" | "kick_demote" | "kick_ban"
SW.EnforcementMode = "kick_demote"

SW.BanDuration = 0                              -- minutes for kick_ban (0 = permanent)
SW.BanReason   = "Unauthorized rank detected"

SW.RecheckInterval = 60                         -- seconds between sweeps (0 = off)

-- Suspend enforcement when the whitelist is empty, so a typo can't mass-punish.
SW.AllowEmptyWhitelist = false

-- Player:SetUserGroup for admin systems that skip CAMI. false to disable.
SW.DetourSetUserGroup = true

SW.DiscordWebhook = ""                          -- webhook URL, empty = disabled
SW.AlertCooldown  = 300                         -- seconds between repeat alerts per SteamID

SW.WebhookRate       = 2                        -- seconds between Discord sends
SW.WebhookQueueLimit = 50                       -- queued alerts before overflow is dropped
SW.ReconnectDelay    = 5                        -- seconds between MySQL reconnect attempts
SW.KeepAliveInterval = 30                       -- seconds between MySQL keepalive pings

-- Only used when SW.Storage == "mysql".
SW.MySQL = {
	host     = "",
	username = "",
	password = "",
	database = "",
	port     = 3306,
}
