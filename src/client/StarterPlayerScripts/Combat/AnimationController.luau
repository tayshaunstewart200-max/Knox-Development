local AnimationController = {}
AnimationController.__index = AnimationController

local PRIORITY = {
	Death = 5, Stagger = 4, Dodge = 3,
	Parry = 3, M1 = 2, Sprint = 1, Idle = 0,
}

local function GetAnimator(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	return humanoid:FindFirstChildOfClass("Animator")
end

function AnimationController.new()
	local self = setmetatable({}, AnimationController)
	self.loadedTracks   = {}
	self.currentPriority = 0
	self.currentTrack   = nil
	self.animator       = nil
	return self
end

function AnimationController:Setup(character)
	self.animator        = GetAnimator(character)
	self.loadedTracks    = {}
	self.currentPriority = 0
	self.currentTrack    = nil
end

local function GetTrack(self, animation)
	if not self.animator then return nil end
	local animId = animation.AnimationId
	if not self.loadedTracks[animId] then
		self.loadedTracks[animId] = self.animator:LoadAnimation(animation)
	end
	return self.loadedTracks[animId]
end

function AnimationController:Play(animation, animName, fadeTime)
	if not self.animator or not animation then return nil end
	local priority = PRIORITY[animName] or 0
	if priority < self.currentPriority then return nil end
	local track = GetTrack(self, animation)
	if not track then return nil end
	if self.currentTrack and self.currentTrack.IsPlaying then
		self.currentTrack:Stop(fadeTime or 0.1)
	end
	self.currentPriority = priority
	self.currentTrack    = track
	track:Play(fadeTime or 0.1)
	track.Stopped:Once(function()
		if self.currentTrack == track then
			self.currentPriority = 0
			self.currentTrack    = nil
		end
	end)
	return track
end

function AnimationController:Stop(animation, fadeTime)
	if not animation then return end
	local track = self.loadedTracks[animation.AnimationId]
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0.1)
	end
end

function AnimationController:StopAll(fadeTime)
	for _, track in pairs(self.loadedTracks) do
		if track.IsPlaying then
			track:Stop(fadeTime or 0.1)
		end
	end
	self.currentPriority = 0
	self.currentTrack    = nil
end

function AnimationController:Cleanup()
	self:StopAll(0)
	for animId, track in pairs(self.loadedTracks) do
		track:Destroy()
		self.loadedTracks[animId] = nil
	end
	self.animator        = nil
	self.currentTrack    = nil
	self.currentPriority = 0
end

return AnimationController