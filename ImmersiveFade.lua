-- TODO: Use AceTimer for fade timers

-- Create addon
ImmersiveFade = LibStub("AceAddon-3.0"):NewAddon("ImmersiveFade", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
ImmersiveFadePermaVizRootFrame = CreateFrame("Frame", "ImmersiveFadePermaVizRootFrame")

local HookFrame = CreateFrame("Frame")

-- Constants
local ALPHA_EPSILON = 0.025
local TIME_EPSILON = 0.01677777
local CHAT_FRAMES = { ChatFrame1, ChatFrame2, ChatFrame3, ChatFrame4, ChatFrame5, ChatFrame6 }
local CHAT_FRAME_EDIT_BOXES =
	{ ChatFrame1EditBox, ChatFrame2EditBox, ChatFrame3EditBox, ChatFrame4EditBox, ChatFrame5EditBox, ChatFrame6EditBox }
local FRAMES_THAT_WILL_FORCE_FADE_IN =
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
		VideoOptionsFrame,
		LFGDungeonReadyStatus,
		LFGDungeonReadyDialog,
		PVPRoleCheckPopup,
		PVPReadyDialog
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
		disable = {
			party = false,
			raid = true
		},
		fadeIn = {
			delay = 0.0,
			duration = 0.1,
			alpha = 1.0
		},
		fadeOut = {
			delay = 30.0,
			duration = 2.0,
			alpha = 0.0,
			immediateFadeWhenFlying = true
		},
		frames = {
			include = "ContainerFrame1 \n SpellBookFrame \n FriendsFrame \n WorldMapFrame \n ClassTalentFrame \n EncounterJournal \n CollectionsJournal \n PVEFrame \n CommunitiesFrame \n AchievementFrame \n CharacterFrame",
			exclude = "MinimapCluster \n BNToastFrame \n ObjectiveTrackerUiWidgetContainer \n SuperTrackedFrame \n UIWidgetPowerBarContainerFrame \n UIErrorsFrame \n TomTomCrazyArrow \n FarmHud"
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
		fadeOut = {
			order = 10,
			type = "group",
			name = "Fade out",
			args = {
				delay = {
					order = 10,
					name = "Delay",
					desc = "How many seconds of inactivity before the UI fades",
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
					order = 20,
					name = "Duration",
					desc = "How long it takes to fade out (in seconds)",
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
					order = 30,
					name = "Alpha",
					desc = "Minimum level of visibility after a fade",
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
				},
				immediateFadeWhenFlying = {
					name = "Flying",
					desc = "Fade immediately when flying",
					type = "toggle",
					set = function(info, val)
						db.profile.immediateFadeWhenFlying = val
					end,
					get = function()
						return db.profile.immediateFadeWhenFlying
					end
				}
			}
		},
		fadeIn = {
			order = 20,
			type = "group",
			name = "Fade in",
			args = {
				delay = {
					-- this option is a can cause the UI to stay invisible for too long, so, I'm hiding it from the config screen
					order = 10,
					hidden = true,
					name = "Delay",
					desc = "How long to wait before triggering the fade-in (in seconds)",
					type = "range",
					min = 0.0,
					softMax = 10.0,
					get = function()
						return db.profile.fadeIn.delay
					end,
					set = function(info, val)
						db.profile.fadeIn.delay = val
					end
				},
				duration = {
					order = 20,
					name = "Duration",
					desc = "How long it takes to become fully visible (in seconds)",
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
					order = 30,
					name = "Alpha",
					desc = "Maximum level of visibility when fully faded in",
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
				},
				-- header = { type="header", name = "Show Me", order = 30 },
				include = {
					name = "Always fade-in for...",
					desc = "Enter the names of UI frames (separated with commas or whitespace) for the windows you want to see as soon as you open them (spellbook, bags, etc.).  To learn the names of such UI frames, enter the Blizzard command /framestack",
					order = 40,
					width = "full",
					type = "input",
					multiline = 10,
					get = function()
						return db.profile.frames.include
					end,
					set = function(info, val)
						db.profile.frames.include = val
					end
				}
			}
		},
		disable = {
			order = 40,
			type = "group",
			name = "Disable when...",
			desc = "Do not fade out when...",
			args = {
				party = {
					name = "In party",
					desc = "Disable fade while in a party",
					type = "toggle",
					get = function()
						return db.profile.disable.party
					end,
					set = function(info, val)
						db.profile.disable.party = val
					end
				},
				raid = {
					name = "In raid",
					desc = "Disable fade while in a raid",
					type = "toggle",
					get = function()
						return db.profile.disable.raid
					end,
					set = function(info, val)
						db.profile.disable.raid = val
					end
				}
			}
		},
		frames = {
			order = 25,
			type = "group",
			name = "Always Visible",
			desc = "Show certain elements regardless",
			args = {
				exclude = {
					name = "Frame blacklist |cffff0000(experimental)|r",
					desc = "Add names of frames (separated with commas or whitespace) to re-parent to prevent fading out",
					desc = "Enter the names of UI frames (separated with commas or whitespace) you want to remain visible even when the rest of the UI fades out (dragon riding vigor, objective tracker, TomTom arrow, etc.).  To learn the names of such UI frames, enter the Blizzard command /framestack",
					width = "full",
					type = "input",
					multiline = 10,
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

-- switch excluded frames' parent when every fading in/out
function ImmersiveFade:moveAlwaysVisibleFrameToPermaVizParent(action)
	local alwaysVisibleFrames = self:SplitStr(db.profile.frames.exclude, "%s", ",")
	for i = 1, #alwaysVisibleFrames do
		local keepMeVisable = _G[alwaysVisibleFrames[i]:gsub("%s+", "")]
		if keepMeVisable ~= nil then
			if (action == "FadeIn" and keepMeVisable:GetParent() == ImmersiveFadePermaVizRootFrame) then
				keepMeVisable:SetParent(UIParent)
				self:PrintDebug("Payback %s to UIParent", keepMeVisable:GetName())
			elseif (action == "FadeOut" and keepMeVisable:GetParent() ~= ImmersiveFadePermaVizRootFrame) then
				keepMeVisable:SetParent(ImmersiveFadePermaVizRootFrame)
				self:PrintDebug("Exclude %s from Fading", keepMeVisable:GetName())
			end
		end
	end
end

function ImmersiveFade:UpdateFade(elapsedTime, id, fadeTracker, immediateFadeWhenFlying, fadeDuration, fadeAlpha, fadeFunc)
	-- Don't run in combat
	if UnitAffectingCombat("Player") or InCombatLockdown() then
		tremove(fadeTracker, 1)
		self:SetAlpha(db.profile.fadeIn.alpha)
		return
	end

	if #fadeTracker > 0 then
		local delay = tremove(fadeTracker, 1)
		-- check for flying condition & option HERE
		local immediateFadeBypass = immediateFadeWhenFlying and IsFlying()
		if not immediateFadeBypass and delay > elapsedTime then
			tinsert(fadeTracker, delay - elapsedTime)
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
				self:moveAlwaysVisibleFrameToPermaVizParent(id)
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
			self:moveAlwaysVisibleFrameToPermaVizParent("FadeIn")
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
			self:moveAlwaysVisibleFrameToPermaVizParent("FadeOut")
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
				db.profile.fadeOut.immediateFadeWhenFlying,
				db.profile.fadeIn.duration,
				db.profile.fadeIn.alpha,
				UIFrameFadeIn
			)
			self:UpdateFade(
				dt,
				"FadeOut",
				fadeOutTracker,
				db.profile.fadeOut.immediateFadeWhenFlying,
				db.profile.fadeOut.duration,
				db.profile.fadeOut.alpha,
				UIFrameFadeOut
			)
			-- Don't continue if in combat
			if UnitAffectingCombat("Player") or InCombatLockdown() then return end

			-- Set Perma Viz Root Frame properties
			-- TODO: This doesn't need to happen every frame
			ImmersiveFadePermaVizRootFrame:SetFrameStrata(UIParent:GetFrameStrata())
			ImmersiveFadePermaVizRootFrame:SetWidth(UIParent:GetWidth())
			ImmersiveFadePermaVizRootFrame:SetHeight(UIParent:GetHeight())
			ImmersiveFadePermaVizRootFrame:SetPoint("CENTER", 0, 0)
			ImmersiveFadePermaVizRootFrame:SetScale(UIParent:GetScale())
			if ImmersiveFadePermaVizRootFrame:IsShown() ~= true then
				ImmersiveFadePermaVizRootFrame:Show()
			end

			-- In group
			if db.profile.disable.party and IsInGroup() then
				self:FadeIn()
				return
			end

			-- In raid
			if db.profile.disable.raid and IsInRaid() then
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
			for i = 1, #FRAMES_THAT_WILL_FORCE_FADE_IN do
				conspicuousFrame = FRAMES_THAT_WILL_FORCE_FADE_IN[i]
				if conspicuousFrame ~= nil and conspicuousFrame:IsVisible() then
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

	if #fadeInTracker > 0 then
		tremove(fadeInTracker, 1)
	end
	if #fadeOutTracker > 0 then
		tremove(fadeOutTracker, 1)
	end
	self:ClearFlags()
	self:SetAlpha(1)
end
