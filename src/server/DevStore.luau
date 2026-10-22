--!strict
-- Studio-only stand-in for DataStoreService, selected with ServerStorage attribute "DevStore".
-- Real DataStores are blocked in Studio unless "Enable Studio Access to API Services" is on, so this lets the
-- onboarding flows be exercised end to end. Contents are mirrored into attribute "DevStoreData" for inspection.
-- Modes: "empty" (a new player), "returning" (finished onboarding), "failload" (every read errors),
--        "failsave" (reads succeed, every write errors), "flaky" (the first two reads error, then it recovers).

local HttpService = game:GetService("HttpService")

local DevStore = {}

function DevStore.make(mode: string, host: Instance)
	local data: { [string]: any } = {}
	local failedReads = 0
	local function mirror()
		host:SetAttribute("DevStoreData", HttpService:JSONEncode(data))
	end
	local store = {}
	function store.GetAsync(_: any, key: string): any
		if mode == "flaky" and failedReads < 2 then
			failedReads += 1
			error("DevStore: simulated transient read failure")
		end
		if mode == "failload" then
			error("DevStore: simulated read failure")
		end
		if mode == "returning" and data[key] == nil then
			data[key] = {
				version = 1,
				hasSeenOnboarding = true,
				hasCompletedTutorial = true,
				onboardingChoice = "tutorial",
			}
			mirror()
		end
		return data[key]
	end
	function store.UpdateAsync(_: any, key: string, fn: (any) -> any): any
		if mode == "failsave" then
			error("DevStore: simulated write failure")
		end
		data[key] = fn(data[key])
		mirror()
		return data[key]
	end
	mirror()
	return store
end

return DevStore
