-- Path of Building: PoE2 — Share Code Utilities
--
-- Decodes and encodes PoB2 build share codes (base64 + zlib).
-- Also supports direct URL-to-XML fetching for known build sites.

local M = {}

-- === zlib inflate/deflate via Python (most reliable cross-arch) ===
local function pythonZlib(bin, mode, windowBits)
	windowBits = windowBits or 15
	local b64 = require("tools/lib/base64")
	local encoded = b64.encode(bin)

	local pyPath = os.tmpname() .. ".py"
	local f = io.open(pyPath, "w")
	if mode == "deflate" then
		f:write(string.format([[
import base64, zlib, sys
try:
    data = base64.b64decode(%q)
    out = zlib.compress(data, level=9)
    # Strip zlib 2-byte header and 4-byte adler32 trailer for raw deflate
    out = out[2:-4]
    sys.stdout.buffer.write(out)
except Exception as e:
    sys.stderr.write(str(e))
    sys.exit(1)
]], encoded))
	else
		f:write(string.format([[
import base64, zlib, sys
try:
    data = base64.b64decode(%q)
    out = zlib.decompress(data, %d)
    sys.stdout.buffer.write(out)
except Exception as e:
    sys.stderr.write(str(e))
    sys.exit(1)
]], encoded, windowBits))
	end
	f:close()

	local pipe = io.popen('python "' .. pyPath .. '" 2>nul', "rb")
	if not pipe then
		os.remove(pyPath)
		error("Failed to spawn Python for zlib")
	end
	local data = pipe:read("*a")
	local ok, _, code = pipe:close()
	os.remove(pyPath)
	if not (ok or code == 0) or not data or #data == 0 then
		error("Python zlib " .. mode .. " failed (windowBits=" .. windowBits .. ")")
	end
	return data
end

-- === Decode a raw share code ===
function M.decodeRawCode(code)
	local normalized = code:gsub("^[%s?]+", ""):gsub("[%s?]+$", "")
	local b64 = require("tools/lib/base64")
	local bin = b64.decode(normalized)
	return pythonZlib(bin, "inflate", 15)
end

-- === Decode raw code with raw deflate (no zlib header) fallback ===
function M.decode(code)
	local ok, xml = pcall(M.decodeRawCode, code)
	if not ok then
		ok, xml = pcall(function()
			local b64 = require("tools/lib/base64")
			local bin = b64.decode(code)
			return pythonZlib(bin, "inflate", -15)
		end)
	end
	if not ok then
		error("Failed to decode share code: " .. tostring(xml))
	end
	return xml
end

-- === Encode XML into a PoB share code (raw deflate + URL-safe base64) ===
function M.encode(xml)
	local rawDeflate = pythonZlib(xml, "deflate")
	local b64 = require("tools/lib/base64")
	return b64.encode(rawDeflate)
end

function M.encodeToURL(xml)
	local code = M.encode(xml)
	return "https://pobb.in/" .. code
end

-- === Known build-site definitions ===
M.websiteList = {
	{
		label = "Maxroll",
		matchURL = "^https?://maxroll%.gg/poe2/pob/.*",
		regexURL = "^https?://maxroll%.gg/poe2/pob/([%w_%-]+)%s*$",
		downloadURL = "https://maxroll.gg/poe2/api/pob/%1",
	},
	{
		label = "pobb.in",
		matchURL = "^https?://pobb%.in/.+",
		regexURL = "^https?://pobb%.in/([%w_%-]+)%s*$",
		downloadURL = "https://pobb.in/pob/%1",
	},
	{
		label = "poe.ninja",
		matchURL = "^https?://poe2?%.ninja/?p?o?e?2?/pob/.+",
		regexURL = "^https?://poe2?%.ninja/?p?o?e?2?/pob/([%w_%-]+)%s*$",
		downloadURL = "https://poe.ninja/poe2/pob/raw/%1",
	},
	{
		label = "poe2db.tw",
		matchURL = "^https?://poe2db%.tw/pob/.+",
		regexURL = "^https?://poe2db%.tw/pob/([%w_%-]+)%s*$",
		downloadURL = "https://poe2db.tw/pob/%1/raw",
	},
	{
		label = "Pastebin.com",
		matchURL = "^https?://pastebin%.com/%w+",
		regexURL = "^https?://pastebin%.com/(%w+)%s*$",
		downloadURL = "https://pastebin.com/raw/%1",
	},
	{
		label = "PastebinP.com",
		matchURL = "^https?://pastebinp%.com/%w+",
		regexURL = "^https?://pastebinp%.com/(%w+)%s*$",
		downloadURL = "https://pastebinp.com/raw/%1",
	},
	{
		label = "Rentry.co",
		matchURL = "^https?://rentry%.co/%w+",
		regexURL = "^https?://rentry%.co/(%w+)%s*$",
		downloadURL = "https://rentry.co/paste/%1/raw",
	},
}

local function matchSite(url)
	for _, site in ipairs(M.websiteList) do
		if url:match(site.matchURL) then
			return site
		end
	end
	return nil
end

local function downloadWithCurl(url)
	local cmd = string.format('curl -sL -A "PathOfBuilding-ShareDecoder/1.0" "%s"', url:gsub('"', '\\"'))
	local pipe = io.popen(cmd, "r")
	if not pipe then return nil end
	local data = pipe:read("*a")
	pipe:close()
	if data and #data > 0 then
		return data
	end
	return nil
end

local function downloadWithPowerShell(url)
	local cmd = string.format(
		'powershell -NoProfile -Command "try { (Invoke-WebRequest -Uri \'%s\' -UserAgent \'PathOfBuilding-ShareDecoder/1.0\' -UseBasicParsing).Content } catch { exit 1 }"',
		url:gsub("'", "''")
	)
	local pipe = io.popen(cmd, "r")
	if not pipe then return nil end
	local data = pipe:read("*a")
	local ok, _, code = pipe:close()
	if (ok or code == 0) and data and #data > 0 then
		return data
	end
	return nil
end

function M.downloadURL(url)
	local data = downloadWithCurl(url)
	if data then return data end
	return downloadWithPowerShell(url)
end

function M.urlToRawCode(url)
	local site = matchSite(url)
	if not site then
		error("Unsupported build share URL: " .. url)
	end
	local downloadURL = url:gsub(site.regexURL, site.downloadURL)
	local data = M.downloadURL(downloadURL)
	if not data or #data == 0 then
		error("Failed to download build from " .. downloadURL)
	end
	return data
end

function M.decodeURL(url)
	local raw = M.urlToRawCode(url)
	return M.decode(raw)
end

-- === Dispatcher ===
function M.decodeInput(input)
	input = input:gsub("^[%s?]+", ""):gsub("[%s?]+$", "")
	if input:match("^https?://") then
		return M.decodeURL(input)
	end
	return M.decode(input)
end

return M
