-- Path of Building: PoE2 — Headless Environment Bootstrap
-- Usage:
--   local pob = require("tools.lib.pob_env")
--   pob.bootstrap()
--   -- now HeadlessWrapper globals (newBuild, loadBuildFromXML, build, runCallback) are available

local M = {}

function M.bootstrap()
	local runtimeDir = "runtime"
	local srcDir = "src"

	local scriptPath = arg[0] or debug.getinfo(2, "S").source:sub(2)
	local scriptDir = scriptPath:match("^(.*)[/\\]") or "."
	local projectRoot = scriptDir:match("^(.*)[/\\]tools[/\\]?$") or "."

	local ffi = require("ffi")
	ffi.cdef[[
		int SetCurrentDirectoryA(const char *lpPathName);
		unsigned long GetFullPathNameA(const char *lpFileName, unsigned long nBufferLength, char *lpBuffer, char **lpFilePart);
	]]

	local function getFullPath(rel)
		local buf = ffi.new("char[4096]")
		local len = ffi.C.GetFullPathNameA(rel, 4096, buf, nil)
		if len == 0 then return rel end
		return ffi.string(buf, len)
	end

	projectRoot = getFullPath(projectRoot):gsub("\\", "/")
	_G.POB_PROJECT_ROOT = projectRoot

	local function absPath(rel)
		return projectRoot .. "/" .. rel
	end

	package.path = absPath(runtimeDir .. "/lua/?.lua") .. ";" .. absPath(runtimeDir .. "/lua/?/init.lua") .. ";" .. package.path
	package.cpath = absPath(runtimeDir .. "/?.dll") .. ";" .. absPath(runtimeDir .. "/lua/?.dll") .. ";" .. package.cpath

	local srcAbs = (projectRoot:gsub("/", "\\") .. "\\" .. srcDir)
	local ok = ffi.C.SetCurrentDirectoryA(srcAbs)
	if ok == 0 then
		error("Failed to change working directory to src/: " .. srcAbs)
	end

	dofile(absPath(srcDir .. "/HeadlessWrapper.lua"))

	-- HeadlessWrapper's LoadModule uses loadfile relative to src/. Since we restore
	-- cwd to the project root after bootstrap, override it so modules can still be
	-- found from src/ when POB loads data during build operations.
	local srcPrefix = absPath(srcDir) .. "/"
	local function makeLoader(orig)
		return function(fileName, ...)
			if not fileName:match("%.lua") then
				fileName = fileName .. ".lua"
			end
			local func, err = loadfile(fileName)
			if not func and not fileName:match("^[a-zA-Z]:[/\\]") and not fileName:match("^[/\\]") then
				func, err = loadfile(srcPrefix .. fileName)
			end
			if not func then
				error("LoadModule() error loading '" .. fileName .. "': " .. tostring(err))
			end
			if orig then
				return orig(func, ...)
			else
				return func(...)
			end
		end
	end
	_G.LoadModule = makeLoader(nil)
	_G.PLoadModule = makeLoader(function(func, ...) return PCall(func, ...) end)

	ffi.C.SetCurrentDirectoryA((projectRoot:gsub("/", "\\")))

	return projectRoot
end

return M
