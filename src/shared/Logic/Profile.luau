--!strict
-- Persistent onboarding record, independent of Roblox so failure handling is testable under the luau CLI.
-- Rule that matters: a failed read is never "new player". A missing key (GetAsync -> nil) is.

export type Record = {
	version: number,
	hasSeenOnboarding: boolean, -- was offered the choice and made one
	hasCompletedTutorial: boolean, -- finished every practice round
	onboardingChoice: string?, -- "tutorial" | "skipped"; the first choice wins
}
export type Patch = {
	hasSeenOnboarding: boolean?,
	hasCompletedTutorial: boolean?,
	onboardingChoice: string?,
}
export type Store = {
	GetAsync: (Store, string) -> any,
	UpdateAsync: (Store, string, (any) -> any) -> any,
}
export type Options = { attempts: number?, delay: number?, sleep: ((number) -> ())? }
export type LoadStatus = "loaded" | "new" | "failed"

local Profile = {}
Profile.__index = Profile

Profile.VERSION = 1

function Profile.default(): Record
	return { version = Profile.VERSION, hasSeenOnboarding = false, hasCompletedTutorial = false }
end

-- Tolerates missing or damaged fields. Unknown fields are not carried; merge() preserves them in the store.
function Profile.normalize(raw: any): Record
	local r = Profile.default()
	if typeof(raw) ~= "table" then
		return r
	end
	r.hasSeenOnboarding = raw.hasSeenOnboarding == true
	r.hasCompletedTutorial = raw.hasCompletedTutorial == true
	if raw.onboardingChoice == "tutorial" or raw.onboardingChoice == "skipped" then
		r.onboardingChoice = raw.onboardingChoice
	end
	if typeof(raw.version) == "number" then
		r.version = raw.version
	end
	return r
end

-- Flags only ever move false -> true and the first choice wins, so saving after a failed load cannot
-- clobber existing progress, and a stale session cannot downgrade a record.
function Profile.merge(old: any, patch: Patch): { [string]: any }
	local out: { [string]: any } = {}
	if typeof(old) == "table" then
		for k, v in old do
			out[k] = v
		end
	end
	local base = Profile.normalize(old)
	out.version = math.max(base.version, Profile.VERSION)
	out.hasSeenOnboarding = base.hasSeenOnboarding or patch.hasSeenOnboarding == true
	out.hasCompletedTutorial = base.hasCompletedTutorial or patch.hasCompletedTutorial == true
	out.onboardingChoice = base.onboardingChoice or patch.onboardingChoice
	return out
end

function Profile.new(store: Store, opts: Options?)
	local o = opts or {}
	return setmetatable({
		store = store,
		attempts = o.attempts or 3,
		delay = o.delay or 1,
		sleep = o.sleep or function(_: number) end,
	}, Profile)
end

local function retry(self: any, fn: () -> (boolean, any)): (boolean, any)
	local lastErr: any
	for attempt = 1, self.attempts do
		local ok, result = fn()
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < self.attempts then
			self.sleep(self.delay * attempt)
		end
	end
	return false, lastErr
end

function Profile.load(self: any, key: string): (LoadStatus, Record?)
	local ok, value = retry(self, function()
		return pcall(self.store.GetAsync, self.store, key)
	end)
	if not ok then
		return "failed", nil
	end
	if value == nil then
		return "new", Profile.default()
	end
	return "loaded", Profile.normalize(value)
end

function Profile.update(self: any, key: string, patch: Patch): boolean
	local ok = retry(self, function()
		return pcall(self.store.UpdateAsync, self.store, key, function(old: any)
			return Profile.merge(old, patch)
		end)
	end)
	return ok
end

return Profile
