# hyper-superwhitelist

> Secure SteamID-based protection for privileged usergroups in Garry's Mod.

<p align="center">
    <img src="https://img.shields.io/github/last-commit/hypercat101/superadminwhitelist?style=for-the-badge">
    <img src="https://img.shields.io/github/license/hypercat101/superadminwhitelist?style=for-the-badge">
    <img src="https://img.shields.io/github/languages/top/hypercat101/superadminwhitelist?style=for-the-badge">
</p>

<p align="center">
    <img src="https://img.shields.io/badge/Garry's_Mod-Server--Side-blue?style=for-the-badge">
    <img src="https://img.shields.io/badge/CAMI-Compatible-success?style=for-the-badge">
    <img src="https://img.shields.io/badge/Lua-100%25-2C2D72?style=for-the-badge">
</p>

---

## Table of Contents

- [Highlights](#highlights)
- [How it catches things](#how-it-catches-things)
- [Requirements](#requirements)
- [Install](#install)
- [Configuration](#configuration)
- [Modes](#modes)
- [Safety notes](#safety-notes)
- [Whitelist examples](#whitelist-examples)
- [MySQL](#mysql)
- [Commands](#commands)
- [Discord alerts](#discord-alerts)
- [Compatibility](#compatibility)
- [Contributing](#contributing)
- [License](#license)

---

## Highlights

- **Four detection surfaces** — CAMI hooks, a `SetUserGroup` fallback detour, a join check, and a periodic sweep. Bypassing one still leaves the others active.
- **SteamID-only authorization** — player names are never trusted.
- **Server-side only** — the whitelist is never networked to clients.
- **Works with your admin mod** — ULX, SAM, ServerGuard, and other CAMI-compatible systems.
- **Fails safe** — an empty or glitched whitelist suspends enforcement instead of banning your staff.
- **Production-ready MySQL** — auto-reconnect, keepalive, non-blocking queries, and resilient caching.
- **Discord alerts** — rate-limited and de-duplicated to prevent webhook spam.
- **Supports SteamID and SteamID64** automatically.

---

## How it catches things

Group changes are monitored through four independent detection paths.

| Surface | Catches |
| --- | --- |
| CAMI hooks | Any CAMI-compliant admin mod (ULX, SAM, ServerGuard, etc.) |
| `Player:SetUserGroup` detour | Admin systems that bypass CAMI (optional) |
| Join check | Groups restored or applied as a player spawns |
| Periodic sweep | Anything the above miss |

All detection paths ultimately use the same authorization logic, ensuring consistent enforcement regardless of how a group was assigned.

---

## Requirements

- Garry's Mod dedicated server
- CAMI-compatible admin mod (ULX, SAM, ServerGuard, etc.)
- `mysqloo` (optional, only if using MySQL storage)

---

## Install

Drop the `hyper-superwhitelist` folder into:

```text
garrysmod/addons/
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

If using MySQL, install the **mysqloo** module into:

```text
garrysmod/lua/bin/
```

Then create the table shown below.

---

## Configuration

Everything is configured from:

```text
lua/autorun/server/sw_config.lua
```

| Option | Description |
| --- | --- |
| `SW.Storage` | `"hardcoded"` or `"mysql"` |
| `SW.Whitelist` | SteamID → allowed groups |
| `SW.ProtectedGroups` | Groups that require authorization |
| `SW.DefaultGroup` | Group violators are returned to |
| `SW.EnforcementMode` | `log`, `demote`, `kick`, `kick_demote`, `kick_ban` |
| `SW.BanDuration` | Ban duration in minutes (`0` = permanent) |
| `SW.BanReason` | Kick/Ban reason |
| `SW.RecheckInterval` | Seconds between periodic sweeps |
| `SW.AllowEmptyWhitelist` | Suspend enforcement if whitelist becomes empty |
| `SW.DetourSetUserGroup` | Enable metatable fallback hook |
| `SW.DiscordWebhook` | Discord webhook URL |
| `SW.AlertCooldown` | Alert cooldown per SteamID |
| `SW.MySQL` | MySQL connection settings |

---

## Modes

| Mode | Behaviour |
| --- | --- |
| `log` | Log only. No punishment. |
| `demote` | Demote to `DefaultGroup`. |
| `kick` | Demote, then kick. |
| `kick_demote` | Demote, then kick. |
| `kick_ban` | Demote, then ban using engine `banid`. |

---

## Safety notes

### Empty whitelist

If the whitelist resolves to zero entries, enforcement is automatically suspended instead of punishing everyone in a protected group.

Set:

```lua
SW.AllowEmptyWhitelist = true
```

only if an empty whitelist is intentional.

### Persistence

Demotion only changes the live usergroup.

It does **not** rewrite the stored group in ULX, SAM, or another admin system.

If a user is restored to a protected group later, they will be caught again on their next join.

Use `kick_ban` or remove the group from your admin system for a permanent fix.

### MySQL resilience

The MySQL connection automatically reconnects, keeps itself alive, never blocks the server, and refuses to wipe a populated cache if a query unexpectedly returns zero rows.

---

## Whitelist examples

Both SteamID and SteamID64 are accepted.

```lua
SW.Whitelist = {
    ["STEAM_0:1:11101"]    = { "superadmin" },
    ["76561197960287930"]  = { "superadmin", "owner" },
    ["STEAM_0:0:44521212"] = { "owner" },
}
```

A SteamID may be authorized for multiple protected groups.

---

## MySQL

Set:

```lua
SW.Storage = "mysql"
```

Configure:

```lua
SW.MySQL
```

Then create the table:

```sql
CREATE TABLE IF NOT EXISTS sw_whitelist (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    steamid       VARCHAR(20) NOT NULL,
    allowed_group VARCHAR(64) NOT NULL,
    UNIQUE KEY uniq_sid_group (steamid, allowed_group)
);

INSERT INTO sw_whitelist (steamid, allowed_group)
VALUES ('76561197960287930', 'superadmin');
```

The whitelist is loaded once into memory, so authorization checks never perform SQL queries during gameplay.

Run:

```text
sw_reload
```

after modifying the table.

---

## Commands

Commands may be run from the server console or in-game as a superadmin.

| Command | Description |
| --- | --- |
| `sw_reload` | Reload the whitelist from Lua or MySQL. |
| `sw_check <steamid>` | Display authorized groups for a SteamID. |

---

## Discord alerts

Create a Discord webhook and paste the URL into:

```lua
SW.DiscordWebhook
```

Leave it empty to disable alerts.

Each alert includes:

- Player name
- SteamID64
- Protected group
- Enforcement action taken

Alerts are automatically rate-limited to prevent webhook spam.

---

## Compatibility

Tested with:

- ULX / ULib
- SAM
- ServerGuard

Other CAMI-compatible admin systems should work automatically.

For systems that bypass CAMI, enable:

```lua
SW.DetourSetUserGroup = true
```

for an additional fallback detection path.

---

## Contributing

Issues, bug reports, feature requests, and pull requests are welcome.

---

## License

Released under the MIT License.
