-- Path of Building: PoE2 — Share Code Exporter
-- Usage: luajit tools/export_share_code.lua <build.xml>
--
-- Encodes a local build XML into a pobb.in share-code URL.

local buildPath = arg[1]
if not buildPath then
	print("Usage: luajit tools/export_share_code.lua <build.xml>")
	os.exit(1)
end

local f, err = io.open(buildPath, "r")
if not f then
	print("Cannot open build: " .. tostring(err))
	os.exit(1)
end
local xml = f:read("*a")
f:close()

if not xml:find("PathOfBuilding2", 1, true) then
	print("File does not appear to be a PoB2 build XML")
	os.exit(1)
end

local share = dofile("tools/lib/share_code.lua")
local ok, codeOrUrl = pcall(share.encodeToURL, xml)
if not ok then
	print("Failed to encode share code: " .. tostring(codeOrUrl))
	os.exit(1)
end

print(codeOrUrl)
