--!strict
-- Get-or-create for the shared Remotes folder, so server systems can add remotes in any init order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local function folder(): Folder
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
	end
	return f :: Folder
end

function Remotes.get(name: string, className: string): any
	local f = folder()
	local r = f:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = f
	end
	return r
end

return Remotes
