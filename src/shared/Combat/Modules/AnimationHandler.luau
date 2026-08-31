local AnimationHandler = {}

local trackCache = {}

local function GetAnimator(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	return humanoid:FindFirstChildOfClass("Animator")
end

local function GetTrack(character, animation)
	local animator = GetAnimator(character)
	if not animator then return nil end
	if not trackCache[character] then
		trackCache[character] = {}
	end
	local animId = animation.AnimationId
	if not trackCache[character][animId] then
		trackCache[character][animId] = animator:LoadAnimation(animation)
	end
	return trackCache[character][animId]
end

function AnimationHandler:Play(character, animation, fadeTime)
	if not character or not animation then return end
	local track = GetTrack(character, animation)
	if not track then return end
	track:Play(fadeTime or 0.1)
end

function AnimationHandler:Stop(character, animation, fadeTime)
	if not character or not animation then return end
	local track = GetTrack(character, animation)
	if not track then return end
	track:Stop(fadeTime or 0.1)
end

function AnimationHandler:StopAll(character, fadeTime)
	if not trackCache[character] then return end
	for _, track in pairs(trackCache[character]) do
		track:Stop(fadeTime or 0.1)
	end
end

function AnimationHandler:Cleanup(character)
	trackCache[character] = nil
end

return AnimationHandler