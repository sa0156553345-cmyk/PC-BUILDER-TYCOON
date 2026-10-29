-- RemoteLayout.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "RemoteLayout")
-- PURE. Decides how the server must set up its RemoteEvent folder, given what already exists.
-- The server collects the top-level objects with the folder name and passes them in. Nothing is changed here.
-- Rule: when anything is ambiguous or wrong, STOP and report. Never guess, never silently replace existing objects.

local RemoteLayout = {}

local function findChildrenNamed(children, name)
	local found = {}
	for _, child in ipairs(children) do
		if child.name == name then
			table.insert(found, child)
		end
	end
	return found
end

-- folderName: expected folder name. required: RemoteEvent names. topLevel: { { name, className, children } }.
-- Returns { ok, action = "use_existing" | "create_folder" | "stop", create = { names }, issues = { { code, params } } }
function RemoteLayout.plan(folderName, required, topLevel)
	local matches = {}
	for _, obj in ipairs(topLevel) do
		if obj.name == folderName then
			table.insert(matches, obj)
		end
	end

	if #matches == 0 then
		local create = {}
		for _, name in ipairs(required) do
			table.insert(create, name)
		end
		return { ok = true, action = "create_folder", create = create, issues = {} }
	end

	-- The client resolves the folder by name. Two candidates would make the two sides disagree.
	if #matches > 1 then
		return { ok = false, action = "stop", create = {}, issues = { { code = "DUPLICATE_FOLDER", params = { name = folderName, count = #matches } } } }
	end

	local folder = matches[1]
	if folder.className ~= "Folder" then
		return { ok = false, action = "stop", create = {}, issues = { { code = "NAME_TAKEN_BY_NON_FOLDER", params = { name = folderName, className = folder.className } } } }
	end

	local children = folder.children or {}
	local issues, create = {}, {}
	for _, name in ipairs(required) do
		local found = findChildrenNamed(children, name)
		if #found == 0 then
			table.insert(create, name)
		elseif #found > 1 then
			table.insert(issues, { code = "DUPLICATE_REMOTE", params = { name = name, count = #found } })
		elseif found[1].className ~= "RemoteEvent" then
			table.insert(issues, { code = "WRONG_REMOTE_CLASS", params = { name = name, className = found[1].className } })
		end
	end

	if #issues > 0 then
		return { ok = false, action = "stop", create = {}, issues = issues }
	end
	return { ok = true, action = "use_existing", create = create, issues = {} }
end

return RemoteLayout
