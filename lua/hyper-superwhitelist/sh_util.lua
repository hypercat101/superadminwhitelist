SW = SW or {}
SW.Util = SW.Util or {}

local string_match = string.match
local string_format = string.format

function SW.Util.IsSteamID64(id)
	if not isstring(id) then return false end
	return string_match(id, "^7656119%d%d%d%d%d%d%d%d%d%d$") ~= nil
end

function SW.Util.IsLegacySteamID(id)
	if not isstring(id) then return false end
	return string_match(id, "^STEAM_%d:[01]:%d+$") ~= nil
end

function SW.Util.NormalizeSteamID64(id)
	if not isstring(id) then return nil end

	id = string.Trim(id)

	if SW.Util.IsSteamID64(id) then
		return id
	end

	if SW.Util.IsLegacySteamID(id) then
		local converted = util.SteamIDTo64(id)
		if SW.Util.IsSteamID64(converted) then
			return converted
		end
	end

	return nil
end

function SW.Util.Log(fmt, ...)
	MsgC(Color(80, 170, 255), "[SuperWhitelist] ", color_white, string_format(fmt, ...), "\n")
end

function SW.Util.Warn(fmt, ...)
	MsgC(Color(255, 90, 90), "[SuperWhitelist] ", color_white, string_format(fmt, ...), "\n")
end

function SW.Util.Timestamp()
	return os.date("!%Y-%m-%dT%H:%M:%SZ")
end
