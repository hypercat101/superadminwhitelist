# hyper-superwhitelist

> SteamID-based protection for privileged usergroups in Garry's Mod.

<p align="center">
    <img src="https://img.shields.io/github/last-commit/hypercat101/superadminwhitelist?style=for-the-badge">
    <img src="https://img.shields.io/github/license/hypercat101/superadminwhitelist?style=for-the-badge">
    <img src="https://img.shields.io/github/languages/top/hypercat101/superadminwhitelist?style=for-the-badge">
</p>

<p align="center">
    <img src="https://img.shields.io/badge/CAMI-Compatible-success?style=for-the-badge">
    <img src="https://img.shields.io/badge/Lua-100%25-2C2D72?style=for-the-badge">
</p>

---

## Features

- SteamID-only authorization (supports SteamID and SteamID64)
- Server-side only (nothing is networked to clients)
- Supports ULX, SAM, ServerGuard, and other CAMI admin mods
- Four detection paths:
  - CAMI hooks
  - `Player:SetUserGroup` fallback (optional)
  - Join check
  - Periodic sweep
- Empty whitelist protection
- MySQL support with reconnects and in-memory caching
- Discord webhook alerts with rate limiting

---

## Install

Drop the addon into:

```text
garrysmod/addons/hyper-superwhitelist/
```

Your folder should look like:

```text
garrysmod/addons/hyper-superwhitelist/
├── addon.json
├── addon.txt
├── README.md
└── lua/
    ├── autorun/server/
    │   ├── sw_config.lua
    │   └── sw_core.lua
    └── hyper-superwhitelist/
        └── sh_util.lua
```

Edit:

```text
lua/autorun/server/sw_config.lua
```

Restart the server or change the map.

If using MySQL, install **mysqloo** in:

```text
garrysmod/lua/bin/
```

---

## Configuration

| Option | Description |
| --- | --- |
| `SW.Storage` | `hardcoded` or `mysql` |
| `SW.Whitelist` | SteamID → allowed groups |
| `SW.ProtectedGroups` | Protected usergroups |
| `SW.DefaultGroup` | Group violators are returned to |
| `SW.EnforcementMode` | `log`, `demote`, `kick`, `kick_demote`, `kick_ban` |
| `SW.BanDuration` | Ban length (`kick_ban`) |
| `SW.BanReason` | Kick/Ban reason |
| `SW.RecheckInterval` | Sweep interval (`0` disables) |
| `SW.AllowEmptyWhitelist` | Suspend enforcement if the whitelist is empty |
| `SW.DetourSetUserGroup` | Hook `SetUserGroup` as a fallback |
| `SW.DiscordWebhook` | Discord webhook URL |
| `SW.AlertCooldown` | Alert cooldown |
| `SW.MySQL` | MySQL connection settings |

---

## Whitelist Example

```lua
SW.Whitelist = {
    ["STEAM_0:1:11101"]   = { "superadmin" },
    ["76561197960287930"] = { "superadmin", "owner" },
    ["STEAM_0:0:44521212"] = { "owner" },
}
```

---

## MySQL

Enable MySQL:

```lua
SW.Storage = "mysql"
```

Create the table:

```sql
CREATE TABLE IF NOT EXISTS sw_whitelist (
    id INT AUTO_INCREMENT PRIMARY KEY,
    steamid VARCHAR(20) NOT NULL,
    allowed_group VARCHAR(64) NOT NULL,
    UNIQUE KEY uniq_sid_group (steamid, allowed_group)
);

INSERT INTO sw_whitelist (steamid, allowed_group)
VALUES ('76561197960287930', 'superadmin');
```

Reload the cache after changing the database:

```text
sw_reload
```

---

## Commands

| Command | Description |
| --- | --- |
| `sw_reload` | Reload the whitelist |
| `sw_check <steamid>` | Show allowed groups for a SteamID |

---

## Notes

- An empty whitelist suspends enforcement by default to prevent accidental lockouts.
- Demotion only changes the live usergroup. Remove the stored group from your admin mod or use `kick_ban` for a permanent fix.
- MySQL data is cached in memory, so permission checks never hit the database.
- Discord alerts include the player's name, SteamID64, group, and enforcement action, with built-in rate limiting.

---

## License

MIT License.
