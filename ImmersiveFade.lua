-- Create addon
ImmersiveFade = LibStub("AceAddon-3.0"):NewAddon("ImmersiveFade", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
ImmersiveFadeExcludeParent = CreateFrame("Frame", "ImmersiveFadeExcludeParent")

local HookFrame = CreateFrame("Frame")

-- Constants
local ALPHA_EPSILON = 0.025
local TIME_EPSILON = 0.01677777
local CHAT_FRAMES = { ChatFrame1, ChatFrame2, ChatFrame3, ChatFrame4, ChatFrame5, ChatFrame6 }
local CHAT_FRAME_EDIT_BOXES =
	{ ChatFrame1EditBox, ChatFrame2EditBox, ChatFrame3EditBox, ChatFrame4EditBox, ChatFrame5EditBox, ChatFrame6EditBox }
local DEFAULT_FRAMES =
	{
		AchivementFrame,
		AchivementAlertFrame1,
		AchivementAlertFrame2,
		CriteriaAlertFrame1,
		CriteriaAlertFrame2,
		GuildChallengeAlertFrame,
		ObjectiveTrackerFrameMover,
		ObjectiveTrackerBonusBannerFrame,
		QuestLogPopupDetailFrame,
		QuestNPCModel,
		QuestFrame,
		QuestChoiceFrame,
		WorldQuestCompleteAlertFrame,
		TalkingHeadFrame,
		BagsMover,
		BankFrame,
		GuildBankFrame,
		VoidStorageFrame,
		GameMenuFrame,
		GossipFrame,
		WorldMapFrame,
		MailFrame,
		PVEFrame,
		RolePollPopup,
		LFDRoleCheckPopup,
		ReadyCheckFrame,
		BonusRollFrame,
		ChallengesKeystoneFrame,
		EncounterJournal,
		LevelUpDisplay,
		FriendsFrame,
		CommunitiesFrame,
		ChannelFrame,
		CollectionsJournal,
		SpellBookFrame,
		PlayerTalentFrame,
		CharacterFrame,
		PVPUIFrame,
		StaticPopup1,
		MirrorTimer1,
		InterfaceOptionsFrame,
		VideoOptionsFrame
	}

-- Variables
local db = {}
local fadeInTracker = {}
local fadeOutTracker = {}
local fadeProgress = {}
local fadeIn = false
local fadeOut = false
local castSucceeded = false
local receivedWhisper = false

-- Defaults and options
local defaults = {
	profile = {
		enabled = true,
		debug = false,
		fadeIn = {
			delay = 0.0,
			duration = 0.1,
			alpha = 1.0
		},
		fadeOut = {
			delay = 30.0,
			duration = 2.0,
			alpha = 0.0
		},
		frames = {
			include = "",
			exclude = "MinimapCluster\nBNToastFrame\nPVPFramePopup\nLFGDungeonReadyPopup"
		}
	}
}
local options = {
	name = "ImmersiveFade",
	type = "group",
	args = {
		enable = {
			name = "Enable",
			desc = "Enable / disables the addon",
			type = "toggle",
			set = function(info, val)
				db.profile.enabled = val
			end,
			get = function()
				return db.profile.enabled
			end
		},
		debug = {
			name = "Show debug info",
			desc = "Enable / disable debug information",
			type = "toggle",
			set = function(info, val)
				db.profile.debug = val
			end,
			get = function()
				return db.profile.debug
			end
		},
		fadeIn = {
			type = "group",
			name = "Fade in",
			args = {
				delay = {
					name = "Delay",
					desc = "Fade in delay (in seconds)",
					type = "range",
					min = 0.0,
					softMax = 60.0,
					get = function()
						return db.profile.fadeIn.delay
					end,
					set = function(info, val)
						db.profile.fadeIn.delay = val
					end
				},
				duration = {
					name = "Duration",
					desc = "Fade in duration (in seconds)",
					type = "range",
					min = 0.0,
					softMax = 5.0,
					get = function()
						return db.profile.fadeIn.duration
					end,
					set = function(info, val)
						db.profile.fadeIn.duration = val
					end
				},
				alpha = {
					name = "Alpha",
					desc = "Fade in alpha",
					type = "range",
					min = 0.0,
					max = 1.0,
					softMin = 0.1,
					isPercent = true,
					get = function()
						return db.profile.fadeIn.alpha
					end,
					set = function(info, val)
						db.profile.fadeIn.alpha = val
					end
				}
			}
		},
		fadeOut = {
			type = "group",
			name = "Fade out",
			args = {
				delay = {
					name = "Delay",
					desc = "Fade out delay (in seconds)",
					type = "range",
					min = 0.0,
					softMax = 60.0,
					get = function()
						return db.profile.fadeOut.delay
					end,
					set = function(info, val)
						db.profile.fadeOut.delay = val
					end
				},
				duration = {
					name = "Duration",
					desc = "Fade out duration (in seconds)",
					type = "range",
					min = 0.0,
					softMax = 5.0,
					get = function()
						return db.profile.fadeOut.duration
					end,
					set = function(info, val)
						db.profile.fadeOut.duration = val
					end
				},
				alpha = {
					name = "Alpha",
					desc = "Fade out alpha",
					type = "range",
					min = 0.0,
					max = 1.0,
					isPercent = true,
					get = function()
						return db.profile.fadeOut.alpha
					end,
					set = function(info, val)
						db.profile.fadeOut.alpha = val
					end
				}
			}
		},
		frames = {
			type = "group",
			name = "Include/exclude frames",
			args = {
				include = {
					name = "Frame whitelist",
					desc = "If these frames are visible (separated with commas or whitespace), the UI will not fade out",
					type = "input",
					multiline = true,
					get = function()
						return db.profile.frames.include
					end,
					set = function(info, val)
						db.profile.frames.include = val
					end
				},
				exclude = {
					name = "Frame blacklist",
					desc = "Add names of frames (separated with commas or whitespace) to re-parent to prevent fading out",
					type = "input",
					multiline = true,
					get = function()
						return db.profile.frames.exclude
					end,
					set = function(info, val)
						db.profile.frames.exclude = val
					end
				}
			}
		}
	}
}

-- Helper functions
function ImmersiveFade:SplitStr(str, ...)
	local t = {}
	local i = 1

	if arg == nil or arg[n] == 0 then
		for str in string.gmatch(str, "([^%s]+)") do
			t[i] = str
			i = i + 1
		end
	else
		for _, sep in ipairs(arg) do
			if sep == nil or sep == "" then
				sep = "%s"
			end

			for str in string.gmatch(str, "([^" .. sep .. "]+)") do
				t[i] = str
				i = i + 1
			end
		end
	end

	return t
end

-- Track spellcasts (including instant cast spells)
function ImmersiveFade:UNIT_SPELLCAST_SUCCEEDED(eventName, unit, lineIdCounter, spellId)
	if unit == "player" then
		-- Check if spell is usable
		local usable, nomana = IsUsableSpell(spellId)
		if not usable then return end

		-- Check if spell was a passive effect
		local isPassive = IsPassiveSpell(spellId)
		if isPassive then return end

		-- Check if spell is actually learned (not a hidden aura)
		name = GetSpellInfo(spellId)
		bookName = GetSpellInfo(name)
		if bookName == nil then return end

		castSucceeded = true
	end
end

-- Track whispers
function ImmersiveFade:CHAT_MSG_WHISPER()
	receivedWhisper = true
end

-- Addon functions
function ImmersiveFade:PrintDebug(msg, ...)
	if db.profile.debug then
		self:Printf("|cffd6b5e2[DEBUG]|r " .. msg, ...)
	end
end

function ImmersiveFade:ClearFlags()
	castSucceeded = false
	receivedWhisper = false
end

function ImmersiveFade:SetAlpha(alpha)
	self:ClearFlags()
	fadeProgress.FadeIn = false
	fadeProgress.FadeOut = false
	UIParent:SetAlpha(alpha)
end

function ImmersiveFade:UpdateFade(dt, id, fadeTracker, fadeDuration, fadeAlpha, fadeFunc)
	-- Don't run in combat
	if UnitAffectingCombat("Player") or InCombatLockdown() then
		tremove(fadeTracker, 1)
		self:SetAlpha(db.profile.fadeIn.alpha)
		return
	end

	if #fadeTracker > 0 then
		local delay = tremove(fadeTracker, 1)
		if delay > dt then
			tinsert(fadeTracker, delay - dt)
		else
			local startAlpha = UIParent:GetAlpha()

			if not fadeProgress[id] then
				fadeProgress[id] = true
				self:PrintDebug(
					"%s invoked (%.4g start alpha, %.4g s fade time, %.4g end alpha)",
					id,
					startAlpha,
					fadeDuration,
					fadeAlpha
				)
				fadeFunc(UIParent, fadeDuration, startAlpha, fadeAlpha)
				UIParent.fadeInfo.finishedFunc = function()
					self:PrintDebug("%s finished", id)
					self:SetAlpha(fadeAlpha)
				end
			end
		end
	end
end

-- Fade in
function ImmersiveFade:FadeIn()
	-- Stop fade out
	if #fadeOutTracker ~= 0 or fadeProgress.FadeOut then
		self:PrintDebug("FadeOut cancelled")
		tremove(fadeOutTracker, 1)
		fadeProgress.FadeOut = false
	end

	-- Clear flags
	self:ClearFlags()

	-- Add fade in if not already added
	if #fadeInTracker == 0 and fadeProgress.FadeIn ~= true then
		local startAlpha = UIParent:GetAlpha()

		-- Ignore if alpha is close enough
		if math.abs(startAlpha - db.profile.fadeIn.alpha) < ALPHA_EPSILON then return end

		if db.profile.fadeIn.delay > TIME_EPSILON then
			self:PrintDebug("FadeIn started (%.4g s delay)", db.profile.fadeIn.delay)
			tinsert(fadeInTracker, db.profile.fadeIn.delay)
		else
			self:PrintDebug("FadeIn no delay")
			fadeProgress.FadeIn = true
			UIFrameFadeIn(UIParent, db.profile.fadeIn.duration, startAlpha, db.profile.fadeIn.alpha)
			UIParent.fadeInfo.finishedFunc = function()
				self:PrintDebug("FadeIn no delay finished")
				self:SetAlpha(db.profile.fadeIn.alpha)
			end
		end
	end
end

-- Fade out
function ImmersiveFade:FadeOut()
	-- Don't fade out if fading in
	if #fadeInTracker ~= 0 or fadeProgress.FadeIn == true then return end

	-- Add fade out if not already added
	if #fadeOutTracker == 0 and fadeProgress.FadeOut ~= true then
		startAlpha = UIParent:GetAlpha()

		-- Ignore if alpha is close enough
		if math.abs(startAlpha - db.profile.fadeOut.alpha) < ALPHA_EPSILON then return end

		if db.profile.fadeOut.delay > TIME_EPSILON then
			self:PrintDebug("FadeOut started (%.4g s delay)", db.profile.fadeOut.delay)
			tinsert(fadeOutTracker, db.profile.fadeOut.delay)
		else
			self:PrintDebug("FadeOut no delay")
			fadeProgress.FadeOut = true
			UIFrameFadeIn(UIParent, db.profile.fadeOut.duration, startAlpha, db.profile.fadeOut.alpha)
			UIParent.fadeInfo.finishedFunc = function()
				self:PrintDebug("FadeOut no delay finished")
				self:SetAlpha(db.profile.fadeOut.alpha)
			end
		end
	end
end

-- Addon lifecycle
function ImmersiveFade:OnInitialize()
	db = LibStub("AceDB-3.0"):New("ImmersiveFade", defaults)
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(db)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("ImmersiveFade", options, { "ifade", "immersivefade" })
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ImmersiveFade", "Immersive|cffd6b5e2Fade|r")
end
function ImmersiveFade:OnEnable()
	self:PrintDebug("Registering events and hooks")

	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", self.CHAT_MSG_WHISPER)

	self:HookScript(
		HookFrame,
		"OnUpdate",
		function(_, dt)
			-- Don't run if disabled
			if db.profile.enabled == false then
				self:SetAlpha(db.profile.fadeIn.alpha)
				return
			end

			-- Update fade in and out
			self:UpdateFade(
				dt,
				"FadeIn",
				fadeInTracker,
				db.profile.fadeIn.duration,
				db.profile.fadeIn.alpha,
				UIFrameFadeIn
			)
			self:UpdateFade(
				dt,
				"FadeOut",
				fadeOutTracker,
				db.profile.fadeOut.duration,
				db.profile.fadeOut.alpha,
				UIFrameFadeOut
			)
			-- Don't continue if in combat
			if UnitAffectingCombat("Player") or InCombatLockdown() then return end

			-- Set parent for excluded frames
			local excludeFrames = self:SplitStr(db.profile.frames.exclude, "%s", ",")
			for i = 1, #excludeFrames do
				local ExcludeFrame = _G[excludeFrames[i]:gsub("%s+", "")]
				if ExcludeFrame ~= nil and ExcludeFrame:GetParent() ~= ImmersiveFadeExcludeParent then
					self:PrintDebug("Exclude %s from fading (SetParent)", ExcludeFrame:GetName())
					ExcludeFrame:SetParent(ImmersiveFadeExcludeParent)
				end
			end

			-- Set exclude parent properties
			-- TODO: This doesn't need to happen every frame
			ImmersiveFadeExcludeParent:SetFrameStrata(UIParent:GetFrameStrata())
			ImmersiveFadeExcludeParent:SetWidth(UIParent:GetWidth())
			ImmersiveFadeExcludeParent:SetHeight(UIParent:GetHeight())
			ImmersiveFadeExcludeParent:SetPoint("CENTER",0,0)
			ImmersiveFadeExcludeParent:SetScale(UIParent:GetScale())
			if ImmersiveFadeExcludeParent:IsShown() ~= true then
				ImmersiveFadeExcludeParent:Show()
			end

			-- In group or raid
			if IsInGroup() or IsInRaid() then
				self:FadeIn()
				return
			end

			-- Currently dead or ghost
			if UnitIsDeadOrGhost("player") then
				self:FadeIn()
				return
			end

			-- In vehicle
			if UnitInVehicle("player") then
				self:FadeIn()
				return
			end

			-- Player or pet health less than max health
			if UnitHealth("player") < UnitHealthMax("player") then
				self:FadeIn()
				return
			end
			if UnitHealth("pet") < UnitHealthMax("pet") then
				self:FadeIn()
				return
			end

			-- Unit conditions (target, focus)
			if UnitExists("target") or UnitExists("focus") then
				self:FadeIn()
				return
			end

			-- Unit conditions (casting)
			if castSucceeded then
				self:FadeIn()
				return
			end
			if UnitCastingInfo("player") or UnitCastingInfo("vehicle") then
				self:FadeIn()
				return
			end
			if UnitChannelInfo("player") or UnitChannelInfo("vehicle") then
				self:FadeIn()
				return
			end

			-- Whisper received
			if receivedWhisper then
				self:FadeIn()
				return
			end

			-- Chat frame edit box has text
			for i = 1, #CHAT_FRAME_EDIT_BOXES do
				local EditBox = CHAT_FRAME_EDIT_BOXES[i]
				if EditBox:GetText() ~= nil and EditBox:GetText() ~= "" then
					self:FadeIn()
					return
				end
			end

			-- Mouse over chat
			for i = 1, #CHAT_FRAMES do
				local ChatFrame = CHAT_FRAMES[i]
				if MouseIsOver(ChatFrame) then
					self:FadeIn()
					return
				end
			end

			-- Mouse over any other UI frame
			if GetMouseFocus() then
				MouseFrame = GetMouseFocus():GetName()
				if MouseFrame ~= "WorldFrame" then
					self:FadeIn()
					return
				end
			end

			-- Frame visibility control, default frames
			for i = 1, #DEFAULT_FRAMES do
				DefaultFrame = DEFAULT_FRAMES[i]
				if DefaultFrame ~= nil and DefaultFrame:IsVisible() then
					self:FadeIn()
					return
				end
			end

			-- Frame visibility control, include frames
			local includeFrames = self:SplitStr(db.profile.frames.include, "%s", ",")
			for i = 1, #includeFrames do
				local IncludeFrame = _G[includeFrames[i]:gsub("%s+", "")]
				if IncludeFrame ~= nil and IncludeFrame:IsVisible() then
					self:FadeIn()
					return
				end
			end

			-- Fade out
			self:FadeOut()
		end,
		true
	)
end
function ImmersiveFade:OnDisable()
	self:PrintDebug("Removing events and hooks")

	self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", self.CHAT_MSG_WHISPER)

	self:UnhookAll()

	local excludeFrames = self:SplitStr(db.profile.frames.exclude, "%s", ",")
	for i = 1, #excludeFrames do
		local ExcludeFrame = _G[excludeFrames[i]:gsub("%s+", "")]
		if ExcludeFrame ~= nil and ExcludeFrame:GetParent() == ExcludeParentFrame then
			self:PrintDebug("Resetting %s parent", ExcludeFrame:GetName())
			ExcludeFrame:SetParent(UIParent)
		end
	end

	if #fadeInTracker > 0 then
		tremove(fadeInTracker, 1)
	end
	if #fadeOutTracker > 0 then
		tremove(fadeOutTracker, 1)
	end
	self:ClearFlags()
	self:SetAlpha(1)
end