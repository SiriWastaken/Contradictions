--!strict
-- Persistence logic against fake stores: success, new player, load failure, transient failure, save failure.
local Profile = require("../src/shared/Logic/Profile")

type Fake = {
	data: { [string]: any },
	failGet: number,
	failUpdate: number,
	calls: { get: number, update: number },
}

local function fakeStore(initial: { [string]: any }?): (any, Fake)
	local state: Fake =
		{ data = initial or {}, failGet = 0, failUpdate = 0, calls = { get = 0, update = 0 } }
	local store = {}
	function store.GetAsync(_: any, key: string): any
		state.calls.get += 1
		if state.failGet > 0 then
			state.failGet -= 1
			error("simulated GetAsync failure")
		end
		return state.data[key]
	end
	function store.UpdateAsync(_: any, key: string, fn: (any) -> any): any
		state.calls.update += 1
		if state.failUpdate > 0 then
			state.failUpdate -= 1
			error("simulated UpdateAsync failure")
		end
		state.data[key] = fn(state.data[key])
		return state.data[key]
	end
	return store, state
end

return function(test: (string, () -> ()) -> ())
	test("P1 missing key is a new player", function()
		local store = fakeStore()
		local status, rec = Profile.new(store):load("k")
		assert(
			status == "new" and rec and not rec.hasSeenOnboarding and not rec.hasCompletedTutorial
		)
	end)
	test("P2 existing record loads", function()
		local store = fakeStore({
			k = {
				version = 1,
				hasSeenOnboarding = true,
				hasCompletedTutorial = true,
				onboardingChoice = "tutorial",
			},
		})
		local status, rec = Profile.new(store):load("k")
		assert(
			status == "loaded"
				and rec
				and rec.hasSeenOnboarding
				and rec.hasCompletedTutorial
				and rec.onboardingChoice == "tutorial"
		)
	end)
	test("P3 load failure is 'failed', never 'new'", function()
		local store, st = fakeStore({ k = { version = 1, hasSeenOnboarding = true } })
		st.failGet = 99
		local status, rec = Profile.new(store, { attempts = 3 }):load("k")
		assert(status == "failed" and rec == nil)
		assert(st.calls.get == 3, "retried")
	end)
	test("P4 transient load failure recovers", function()
		local store, st = fakeStore({ k = { version = 1, hasSeenOnboarding = true } })
		st.failGet = 2
		local slept = 0
		local status, rec = Profile.new(store, {
			attempts = 3,
			sleep = function(s: number)
				slept += s
			end,
		}):load("k")
		assert(status == "loaded" and rec and rec.hasSeenOnboarding)
		assert(slept == 3, "backoff 1s then 2s")
	end)
	test("P5 damaged record falls back safely", function()
		local store = fakeStore({ k = "garbage" })
		local status, rec = Profile.new(store):load("k")
		assert(status == "loaded" and rec and not rec.hasSeenOnboarding)
		local s2 = fakeStore({ k = { hasSeenOnboarding = "yes", onboardingChoice = "hax" } })
		local _, r2 = Profile.new(s2):load("k")
		assert(r2 and not r2.hasSeenOnboarding and r2.onboardingChoice == nil)
	end)
	test("P6 update writes a new record", function()
		local store, st = fakeStore()
		assert(
			Profile.new(store)
				:update("k", { hasSeenOnboarding = true, onboardingChoice = "skipped" })
		)
		assert(
			st.data.k.hasSeenOnboarding
				and not st.data.k.hasCompletedTutorial
				and st.data.k.onboardingChoice == "skipped"
		)
		assert(st.data.k.version == Profile.VERSION)
	end)
	test("P7 merge is monotonic: failed-load save cannot clobber progress", function()
		local store, st = fakeStore({
			k = {
				version = 1,
				hasSeenOnboarding = true,
				hasCompletedTutorial = true,
				onboardingChoice = "tutorial",
			},
		})
		assert(
			Profile.new(store)
				:update("k", { hasSeenOnboarding = true, onboardingChoice = "skipped" })
		)
		local r = st.data.k
		assert(
			r.hasCompletedTutorial and r.onboardingChoice == "tutorial",
			"first choice and completion kept"
		)
	end)
	test("P8 merge preserves unknown and future fields", function()
		local store, st =
			fakeStore({ k = { version = 7, hasSeenOnboarding = true, extra = "keep" } })
		assert(Profile.new(store):update("k", { hasCompletedTutorial = true }))
		assert(
			st.data.k.extra == "keep" and st.data.k.version == 7 and st.data.k.hasCompletedTutorial
		)
	end)
	test("P9 save failure retries then reports false, store untouched", function()
		local store, st = fakeStore({ k = { version = 1, hasSeenOnboarding = false } })
		st.failUpdate = 99
		assert(not Profile.new(store, { attempts = 3 }):update("k", { hasSeenOnboarding = true }))
		assert(st.calls.update == 3 and st.data.k.hasSeenOnboarding == false)
	end)
	test("P10 transient save failure recovers", function()
		local store, st = fakeStore()
		st.failUpdate = 1
		assert(Profile.new(store):update("k", { hasCompletedTutorial = true }))
		assert(st.data.k.hasCompletedTutorial)
	end)
end
