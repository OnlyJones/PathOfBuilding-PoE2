-- Path of Building: PoE2 — Corpus Fetcher
-- Usage: luajit tools/fetch_corpus.lua <codes.txt> <output_dir>
--
-- Reads one share code/URL per line from codes.txt, decodes each to XML,
-- and writes it to output_dir/<index>.xml.

local codesPath = arg[1]
local outDir = arg[2]

if not codesPath or not outDir then
	print("Usage: luajit tools/fetch_corpus.lua <codes.txt> <output_dir>")
	os.exit(1)
end

local share = dofile("tools/lib/share_code.lua")

os.execute('cmd /c "if not exist \"' .. outDir:gsub("/", "\\") .. '\" mkdir \"' .. outDir:gsub("/", "\\") .. '\""')

local f, err = io.open(codesPath, "r")
if not f then
	error("Cannot open " .. codesPath .. ": " .. tostring(err))
end

local successes = 0
local failures = 0
local idx = 1
for line in f:lines() do
	line = line:gsub("^%s+", ""):gsub("%s+$", "")
	if line ~= "" and not line:match("^#") then
		print("[" .. idx .. "] " .. line:sub(1, 60) .. (#line > 60 and "..." or ""))
		local ok, xml = pcall(function() return share.decodeInput(line) end)
		if ok and xml and xml:match("PathOfBuilding2") then
			local outPath = outDir .. "/" .. idx .. ".xml"
			local outf = io.open(outPath, "w")
			outf:write(xml)
			outf:close()
			print("      -> saved " .. outPath .. " (" .. #xml .. " bytes)")
			successes = successes + 1
		else
			print("      -> FAILED: " .. tostring(xml))
			failures = failures + 1
		end
		idx = idx + 1
	end
end
f:close()

print("")
print("Done. Successes: " .. successes .. ", Failures: " .. failures)
if failures > 0 then
	os.exit(1)
end
