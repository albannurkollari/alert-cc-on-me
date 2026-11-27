-- busted entry point. Behaviour tests live in test_addon.lua as T["name"] = function,
-- each run against a freshly loaded addon; the data and static checks are below.
local helper = require("tests.helper")

local TEST_FILE = "tests/test_addon.lua"

describe("addon", function()
	for line in helper.read(TEST_FILE):gmatch("[^\r\n]+") do
		local name = line:match('^T%["(.-)"%] = function')
		if name then
			it(name, function()
				local env, run = helper.newClient()
				run(TEST_FILE)
				env.T[name]()
			end)
		end
	end
end)

describe("data", function()
	it("every voice pack has both clips for every callout", function()
		local ns = helper.newClient().ns
		local keys = {}
		for _, entry in ipairs(ns.CastableCC) do
			keys[entry.callout] = true
		end
		for _, key in pairs(ns.GenericCallout) do
			keys[key] = true
		end
		local missing = {}
		for _, pack in ipairs(ns.VoicePacks) do
			for key in pairs(keys) do
				for _, clip in ipairs({ key, key .. "OnYou" }) do
					local path = ("%sMedia/Voice/%s/%s.ogg"):format(helper.ADDON, pack.Value, clip)
					if not helper.exists(path) then
						missing[#missing + 1] = path
					end
				end
			end
		end
		assert.are.same({}, missing)
	end)
end)

-- Truth-testing or comparing a secret cannot be trapped by a Lua mock, so flag the
-- risky shapes statically on names known to carry secrets.
local SECRET_NAMES = {
	"isCC", "onMe", "cast.name", "cast.texture", "cast.spellID", "cast.startMs", "cast.endMs",
	"spellID", "texture", "name", "startMs", "endMs", "plate", "canAttack", "isPlayer", "same",
	"exists", "level", "handle",
}

local function RiskyLine(code)
	-- `x and y or z` on a secret: the `and` truth-tests it.
	for _, name in ipairs(SECRET_NAMES) do
		if code:find("%f[%w_]" .. name:gsub("%.", "%%.") .. "%s+and%s+.*%f[%w_]or%f[^%w_]") then
			return true
		end
	end
	-- `x ~= nil and not IsSecret(x)`: the comparison raises before the secrecy check.
	for var, check in code:gmatch("([%w_]+)%s*[~=]=%s*nil%s+and%s+not%s+([%w_%.]+%b())") do
		if check == "IsSecret(" .. var .. ")" or check == "Util.IsSecret(" .. var .. ")" then
			return true
		end
	end
	return false
end

describe("static scan", function()
	it("finds no secret truth-tests", function()
		local issues = {}
		for _, path in ipairs(helper.tocFiles()) do
			local number = 0
			for line in (helper.read(path) .. "\n"):gmatch("(.-)\r?\n") do
				number = number + 1
				if RiskyLine(line:match("^(.-)%-%-") or line) then
					issues[#issues + 1] = ("%s:%d: %s"):format(path, number, line:match("^%s*(.-)%s*$"))
				end
			end
		end
		assert.are.same({}, issues)
	end)

	it("catches the shapes it looks for", function()
		assert.is_true(RiskyLine("local x = isCC and 1 or 0"))
		assert.is_true(RiskyLine("if plate ~= nil and not IsSecret(plate) then"))
		assert.is_false(RiskyLine("if not IsSecret(plate) and plate ~= nil then"))
	end)
end)
