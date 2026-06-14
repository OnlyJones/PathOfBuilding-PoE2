-- Pure Lua base64 encoder/decoder (URL-safe aware)

local M = {}

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64map = { }
for i = 1, #b64chars do
	b64map[b64chars:sub(i, i)] = i - 1
end
b64map["-"] = 62
b64map["_"] = 63

function M.decode(input)
	input = input:gsub("[^A-Za-z0-9+/%-_=]", "")
	local pad = 0
	if input:sub(-1) == "=" then pad = pad + 1 end
	if input:sub(-2, -1) == "==" then pad = pad + 1 end
	input = input:gsub("=", "")

	local output = { }
	local len = #input
	for i = 1, len, 4 do
		local a = b64map[input:sub(i, i)] or 0
		local b = b64map[input:sub(i + 1, i + 1)] or 0
		local c = b64map[input:sub(i + 2, i + 2)] or 0
		local d = b64map[input:sub(i + 3, i + 3)] or 0
		local triplet = a * 262144 + b * 4096 + c * 64 + d
		table.insert(output, string.char(math.floor(triplet / 65536) % 256))
		if i + 2 <= len then
			table.insert(output, string.char(math.floor(triplet / 256) % 256))
		end
		if i + 3 <= len then
			table.insert(output, string.char(triplet % 256))
		end
	end
	return table.concat(output)
end

function M.encode(input)
	local output = { }
	local len = #input
	for i = 1, len, 3 do
		local a = input:byte(i) or 0
		local b = input:byte(i + 1) or 0
		local c = input:byte(i + 2) or 0
		local triplet = a * 65536 + b * 256 + c
		table.insert(output, b64chars:sub(math.floor(triplet / 262144) % 64 + 1, math.floor(triplet / 262144) % 64 + 1))
		table.insert(output, b64chars:sub(math.floor(triplet / 4096) % 64 + 1, math.floor(triplet / 4096) % 64 + 1))
		if i + 1 <= len then
			table.insert(output, b64chars:sub(math.floor(triplet / 64) % 64 + 1, math.floor(triplet / 64) % 64 + 1))
		else
			table.insert(output, "=")
		end
		if i + 2 <= len then
			table.insert(output, b64chars:sub(triplet % 64 + 1, triplet % 64 + 1))
		else
			table.insert(output, "=")
		end
	end
	return table.concat(output)
end

return M
