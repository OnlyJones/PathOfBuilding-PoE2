-- Path of Building: PoE2 — Share Code Decoder CLI
-- Usage: luajit tools/decode_share_code.lua <code_or_url> [output.xml]
--
-- Decodes a PoB2 share code (base64 + zlib) or downloads from a supported URL.

local input = arg[1]
local outputPath = arg[2]

if not input then
	print("Usage: luajit tools/decode_share_code.lua <code_or_url> [output.xml]")
	print("Supported URLs: maxroll.gg, pobb.in, poe.ninja, poe2db.tw, pastebin.com, pastebinp.com, rentry.co")
	os.exit(1)
end

local share = dofile("tools/lib/share_code.lua")
local xml = share.decodeInput(input)

if outputPath then
	local f, err = io.open(outputPath, "w")
	if not f then
		error("Cannot write " .. outputPath .. ": " .. tostring(err))
	end
	f:write(xml)
	f:close()
	print("Decoded build XML to " .. outputPath)
else
	print(xml)
end
