--!strict
-- Server-side onboarding persistence. The client never reports its own status; it asks and is told.
-- Studio needs "Enable Studio Access to API Services" (Game Settings > Security) for DataStores to work.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Profile = require(Shared.Logic.Profile)
local Remotes = require(Shared.Util.Remotes)

-- "loading" | "new" | "returning" | "unavailable"  (unavailable = load failed; never treated as new)
type State = {
	status: string,
	record: Profile.Record,
	pending: number,
	unsaved: Profile.Patch?,
}

local ProfileService = {}

local states: { [Player]: State } = {}
local profile: any = nil
local getProfile: RemoteFunction

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function makeRealProfile()
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(Config.STORE_NAME)
	end)
	if not ok then
		warn("[Contradictions] DataStore unavailable: " .. tostring(store))
		return nil
	end
	return Profile.new(store, { attempts = 3, delay = 1, sleep = task.wait })
end

local function load(player: Player)
	local state: State = { status = "loading", record = Profile.default(), pending = 0 }
	states[player] = state
	if not profile then
		state.status = "unavailable"
		return
	end
	local status, record = Profile.load(profile, keyFor(player))
	if not player.Parent then
		return
	end
	if status == "failed" then
		state.status = "unavailable"
		warn(
			("[Contradictions] could not load onboarding record for %s; using a session-only fallback and not marking them new"):format(
				player.Name
			)
		)
	else
		state.record = record :: Profile.Record
		state.status = if state.record.hasSeenOnboarding then "returning" else "new"
	end
end

local function persist(state: State, player: Player, patch: Profile.Patch)
	state.pending += 1
	task.spawn(function()
		local merged: Profile.Patch = patch
		if state.unsaved then
			merged = {
				hasSeenOnboarding = patch.hasSeenOnboarding or state.unsaved.hasSeenOnboarding,
				hasCompletedTutorial = patch.hasCompletedTutorial
					or state.unsaved.hasCompletedTutorial,
				onboardingChoice = state.unsaved.onboardingChoice or patch.onboardingChoice,
			}
		end
		if Profile.update(profile, keyFor(player), merged) then
			state.unsaved = nil
		else
			state.unsaved = merged
			warn(
				("[Contradictions] could not save onboarding record for %s; will retry when they leave"):format(
					player.Name
				)
			)
		end
		state.pending -= 1
	end)
end

-- Yields until the load finishes (or the player leaves).
function ProfileService.wait(player: Player): State?
	local state = states[player]
	local waited = 0
	while (not state or state.status == "loading") and player.Parent and waited < 60 do
		task.wait(0.1)
		waited += 0.1
		state = states[player]
	end
	return states[player]
end

function ProfileService.noteChoice(player: Player, choice: string)
	local state = states[player]
	if not state or state.status == "loading" or state.record.hasSeenOnboarding then
		return
	end
	state.record.hasSeenOnboarding = true
	state.record.onboardingChoice = choice
	if state.status == "new" then
		state.status = "returning"
	end
	persist(state, player, { hasSeenOnboarding = true, onboardingChoice = choice })
end

function ProfileService.noteTutorialCompleted(player: Player)
	local state = states[player]
	if not state or state.status == "loading" or state.record.hasCompletedTutorial then
		return
	end
	state.record.hasCompletedTutorial = true
	persist(state, player, { hasSeenOnboarding = true, hasCompletedTutorial = true })
end

local function flush(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local waited = 0
	while state.pending > 0 and waited < 10 do
		task.wait(0.1)
		waited += 0.1
	end
	if state.unsaved and profile then
		if Profile.update(profile, keyFor(player), state.unsaved) then
			state.unsaved = nil
		end
	end
end

-- Test hooks: swap the backing store and re-run the load for a player already in the server.
function ProfileService._useStore(store: any, opts: Profile.Options?)
	profile = Profile.new(store, opts)
end

function ProfileService._reload(player: Player)
	load(player)
end

function ProfileService.init()
	getProfile = Remotes.get("GetProfile", "RemoteFunction")
	profile = makeRealProfile()
end

function ProfileService.start()
	getProfile.OnServerInvoke = function(player: Player)
		local state = ProfileService.wait(player)
		if not state then
			return { status = "unavailable", hasCompletedTutorial = false }
		end
		return { status = state.status, hasCompletedTutorial = state.record.hasCompletedTutorial }
	end

	local function track(player: Player)
		if not states[player] then
			task.spawn(load, player)
		end
	end
	Players.PlayerAdded:Connect(track)
	for _, p in Players:GetPlayers() do
		track(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		flush(player)
		states[player] = nil
	end)
	game:BindToClose(function()
		for _, p in Players:GetPlayers() do
			flush(p)
		end
	end)
end

return ProfileService
