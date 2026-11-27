-- Loads the addon the way the client does: every .lua file in .toc order, each called
-- with (addonName, ns), on top of tests/wow_mock.lua. Paths are relative to the repo root.
local helper = {}

helper.ADDON = "AlertCCOnMe/"

function helper.read(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

function helper.exists(path)
	local file = io.open(path, "rb")
	if file then
		file:close()
	end
	return file ~= nil
end

function helper.tocFiles()
	local files = {}
	for line in helper.read(helper.ADDON .. "AlertCCOnMe.toc"):gmatch("[^\r\n]+") do
		line = line:match("^%s*(.-)%s*$")
		if line:sub(1, 1) ~= "#" and line:lower():match("%.lua$") then
			files[#files + 1] = helper.ADDON .. line:gsub("\\", "/")
		end
	end
	return files
end

-- A fresh client per call: the mock and the addon write globals, so each one gets its
-- own environment and no test sees another's state. Returns that environment and a
-- runner that loads further files into it.
function helper.newClient()
	local env = setmetatable({}, { __index = _G })
	env._G = env
	local function run(path, ...)
		local chunk = assert(loadfile(path))
		setfenv(chunk, env)
		return chunk(...)
	end
	run("tests/wow_mock.lua")
	local ns = {}
	for _, path in ipairs(helper.tocFiles()) do
		run(path, "AlertCCOnMe", ns)
	end
	env.ns = ns
	return env, run
end

return helper
