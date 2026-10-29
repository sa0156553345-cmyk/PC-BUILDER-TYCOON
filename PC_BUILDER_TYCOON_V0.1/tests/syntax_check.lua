-- tests/syntax_check.lua
-- Checks that every .lua file under src/ parses with standard Lua 5.3 syntax.
-- LIMITATION: this is NOT a Luau checker. Luau-only syntax (type annotations, +=, continue)
-- would be reported as an error, and Roblox API misuse is NOT detected.
-- Passing here does NOT mean the scripts run inside Roblox.
-- Run from the project root:   texlua tests/syntax_check.lua

local files = {}
local p = io.popen('find src -name "*.lua" | sort')
for line in p:lines() do table.insert(files, line) end
p:close()

local failures = 0
for _, path in ipairs(files) do
	local f, err = loadfile(path)
	if f then
		print("OK    " .. path)
	else
		failures = failures + 1
		print("ERROR " .. err)
	end
end

print(string.format("\n%d files checked, %d with syntax errors", #files, failures))
os.exit(failures == 0 and 0 or 1)
