-- Path of Building: PoE2 — Smoke test for optimizer tooling
-- Usage: luajit tools/smoke_test.lua
--
-- Exits with non-zero status if any tool fails a basic sanity check.

local function run(cmd)
	local pipe = io.popen(cmd .. " 2>&1", "r")
	local out = pipe:read("*a")
	local ok, exitType, code = pipe:close()
	if ok == true then
		return true, out
	else
		return false, out .. "\n(exit " .. tostring(exitType) .. " " .. tostring(code) .. ")"
	end
end

local function assertContains(str, pat, msg)
	if not str:find(pat, 1, true) then
		print("FAIL: " .. msg .. "\nExpected pattern: " .. pat .. "\nOutput:\n" .. str)
		os.exit(1)
	end
end

print("Testing generate_test_build.lua...")
local ok, out = run("luajit tools/generate_test_build.lua __smoke_test_build.xml")
if not ok then
	print("FAIL: generate_test_build.lua failed\n" .. out)
	os.exit(1)
end
assertContains(out, "Saved", "generate did not report save")

print("Testing headless_eval.lua...")
ok, out = run("luajit tools/headless_eval.lua __smoke_test_build.xml")
if not ok then
	print("FAIL: headless_eval.lua failed\n" .. out)
	os.exit(1)
end
assertContains(out, "TotalDPS:", "eval did not report TotalDPS")
assertContains(out, "Class: Ranger / Deadeye", "eval did not load Ranger/Deadeye")

print("Testing analyze_build.lua...")
ok, out = run("luajit tools/analyze_build.lua __smoke_test_build.xml")
if not ok then
	print("FAIL: analyze_build.lua failed\n" .. out)
	os.exit(1)
end
assertContains(out, '"class":"Ranger"', "analyzer did not report Ranger")
assertContains(out, '"ascendancy":"Deadeye"', "analyzer did not report Deadeye")

print("Testing extract_patterns.lua...")
local cmd = 'cmd /c "if not exist __smoke_corpus mkdir __smoke_corpus & copy /Y __smoke_test_build.xml __smoke_corpus\\build.xml > nul"'
os.execute(cmd)
ok, out = run("luajit tools/extract_patterns.lua __smoke_corpus __smoke_patterns.json")
if not ok then
	print("FAIL: extract_patterns.lua failed\n" .. out)
	os.exit(1)
end
assertContains(out, "Processed 1 builds", "extractor did not process one build")

print("Testing improve_build.lua...")
ok, out = run("luajit tools/improve_build.lua __smoke_test_build.xml --output __smoke_improved.xml --points 10 --gear-sets 2 --seed 1")
if not ok then
	print("FAIL: improve_build.lua failed\n" .. out)
	os.exit(1)
end
assertContains(out, "Improvement summary", "improver did not report summary")
assertContains(out, "Saved to", "improver did not save output")

-- Cleanup
os.remove("__smoke_test_build.xml")
os.remove("__smoke_patterns.json")
os.execute('cmd /c "rmdir /S /Q __smoke_corpus 2> nul"')
os.remove("__smoke_optimized.xml")
os.remove("__smoke_improved.xml")

print("")
print("All smoke tests passed.")
