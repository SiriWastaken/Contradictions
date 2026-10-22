--!strict
-- Contradictions server entry point. Two-phase bootstrap: init() everything, then start() everything.

local folder = script:FindFirstChild("Systems")

local loaded: { [string]: any } = {}
if folder then
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			loaded[child.Name] = require(child)
		end
	end
end

for _, module in loaded do
	if typeof(module.init) == "function" then
		module.init()
	end
end

for _, module in loaded do
	if typeof(module.start) == "function" then
		task.spawn(module.start)
	end
end

print("[Contradictions] server started")
