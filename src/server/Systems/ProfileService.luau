--!strict
-- Server-side onboarding persistence. The client never reports its own status; it asks and is told.
-- Studio needs "Enable Studio Access to API Services" (Game Settings > Security) for DataStores to work.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

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

local serverRoot = script.Parent.Parent

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

local retryLoad: (Player, State) -> ()

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
		retryLoad(player, state)
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

-- After a failed first read, keep trying quietly. If it succeeds, the stored record and whatever happened
-- this session are combined, so nothing is lost and nobody is wrongly offered the tutorial.
function retryLoad(player: Player, state: State)
	task.spawn(function()
		for _ = 1, Config.PROFILE_RETRIES do
			task.wait(Config.PROFILE_RETRY_SECONDS)
			if states[player] ~= state or not profile then
				return
			end
			local status, stored = Profile.load(profile, keyFor(player))
			if status ~= "failed" then
				local before = state.record
				state.record = Profile.union(stored :: Profile.Record, before)
				state.status = if state.record.hasSeenOnboarding then "returning" else "new"
				if
					before.hasSeenOnboarding and not (stored :: Profile.Record).hasSeenOnboarding
				then
					persist(state, player, {
						hasSeenOnboarding = true,
						hasCompletedTutorial = before.hasCompletedTutorial,
						onboardingChoice = before.onboardingChoice,
					})
				end
				return
			end
		end
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

function ProfileService.init()
	if not ServerStorage:FindFirstChild("TutorialCompleted") then
		local e = Instance.new("BindableEvent")
		e.Name = "TutorialCompleted"
		e.Parent = ServerStorage
	end
	getProfile = Remotes.get("GetProfile", "RemoteFunction")
	profile = makeRealProfile()

	-- Studio only: swap in an in-memory store (see DevStore) and reload everyone already here.
	if RunService:IsStudio() then
		local function applyDevStore()
			local mode = ServerStorage:GetAttribute("DevStore")
			if typeof(mode) ~= "string" then
				return
			end
			-- selene: allow(incorrect_standard_library_use)
			profile = Profile.new(
				require(serverRoot.DevStore).make(mode, ServerStorage),
				{ attempts = 2, delay = 0 }
			)
			for _, p in Players:GetPlayers() do
				task.spawn(load, p)
			end
		end
		ServerStorage:GetAttributeChangedSignal("DevStore"):Connect(applyDevStore)
		applyDevStore()
	end
end

function ProfileService.start()
	-- Driven by remote and bindable events rather than a direct dependency on SessionService, so the two
	-- systems cannot end up holding different copies of this module's state.
	Remotes.get("Start", "RemoteEvent").OnServerEvent:Connect(function(player, mode: any)
		if mode == "tutorial" then
			ProfileService.noteChoice(player, "tutorial")
		end
	end)
	Remotes.get("Onboard", "RemoteEvent").OnServerEvent:Connect(function(player, choice: any)
		if choice == "skip" then
			ProfileService.noteChoice(player, "skipped")
		end
	end)
	ServerStorage:WaitForChild("TutorialCompleted").Event
		:Connect(ProfileService.noteTutorialCompleted)

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
