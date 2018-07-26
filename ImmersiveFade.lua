-- Here be dragons!
-- Configuration can be edited in Config.lua

local addonName, options = ... ;

local ALPHA_EPSILON = 0.025
local TIME_EPSILON = 0.01677777
local DEFAULT_FRAMES = {

	-- Achievements and quests
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

	-- Inventory
	BagsMover,
	BankFrame,
	GuildBankFrame,
	VoidStorageFrame,

	-- All the rest
	-- Missing default frame? Open a PR!
	GameMenuFrame,
	GossipFrame,
	WorldMapFrame,
	MailFrame,
	PVEFrame,
	LFGDungeonReadyDialog,
	LFGDungeonReadyStatus,
	LFGDungeonReadyPopup,
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
	MirrorTimer1
}

-- Type check config
local DEBUG = true;
local FADE_IN_DELAY = 0.0;
local FADE_IN_TIME = 0.1;
local FADE_IN_VALUE = 1.0;
local FADE_OUT_DELAY = 30.0;
local FADE_OUT_TIME = 2.0;
local FADE_OUT_VALUE = 0.0;
local CUSTOM_FRAMES = {};
local EXCLUDE_FRAMES = {};

if type(options.DEBUG) == "boolean" then
	DEBUG = options.DEBUG;
end
if type(options.FADE_IN_DELAY) == "number" then
	FADE_IN_DELAY = options.FADE_IN_DELAY;
end
if type(options.FADE_IN_TIME) == "number" then
	FADE_IN_TIME = options.FADE_IN_TIME;
end
if type(options.FADE_IN_TIME) == "number" then
	FADE_IN_VALUE = options.FADE_IN_VALUE;
end
if type(options.FADE_OUT_DELAY) == "number" then
	FADE_OUT_DELAY = options.FADE_OUT_DELAY;
end
if type(options.FADE_OUT_TIME) == "number" then
	FADE_OUT_TIME = options.FADE_OUT_TIME;
end
if type(options.FADE_OUT_TIME) == "number" then
	FADE_OUT_VALUE = options.FADE_OUT_VALUE;
end
if type(options.CUSTOM_FRAMES) == "table" then
	CUSTOM_FRAMES = options.CUSTOM_FRAMES;
end
if type(options.EXCLUDE_FRAMES) == "table" then
	EXCLUDE_FRAMES = options.EXCLUDE_FRAMES;
end

-- Main addon frame
local addonFrame = CreateFrame("Frame");

-- Fade variables
local fadeInTable = {};
local fadeOutTable = {};

local fadeProgress = {}
fadeProgress.FadeIn = false;
fadeProgress.FadeOut = false;

-- Event tracking variables
local castSucceeded = false;
local receivedWhisper = false;

-- Track spellcasts (including instant cast spells)
addonFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
addonFrame:HookScript("OnEvent", function(self, event, unit, lineIdCounter, spellId)
	if unit == "player" then
		-- Check if spell is usable
		usable, nomana = IsUsableSpell(spellId);
		if not usable then
			return;
		end

		-- Check if spell was a passive effect
		isPassive = IsPassiveSpell(spellId);
		if isPassive then
			return;
		end

		-- Check if spell is actually learned (not a hidden aura)
		name = GetSpellInfo(spellId)
		bookName = GetSpellInfo(name)
		if bookName == nil then
			return;
		end

		castSucceeded = true;
	end;
end);

-- Track whispers
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", function(self, event, msg, author)
	receivedWhisper = true;
end);

-- Addon functions
function ImmersiveFade_LogDebug(msg)
	if DEBUG then
		print("|cffb538e2Immersive|r|cffd6b5e2Fade|r: " .. msg);
	end
end

function ImmersiveFade_ClearFlags()
	castSucceeded = false;
	receivedWhisper = false;
end

function ImmersiveFade_SetAlpha(alpha)
	ImmersiveFade_ClearFlags();
	fadeProgress.FadeIn = false;
	fadeProgress.FadeOut = false;
	UIParent:SetAlpha(alpha);
end

function ImmersiveFade_CreateFadeEvent(eventName, fadeTable, fadeTime, fadeValue, fadeFunc)
	addonFrame:HookScript("OnUpdate", function (self, dt)

		-- Don't run in combat
		if UnitAffectingCombat("Player")
		or InCombatLockdown() then
			tremove(fadeTable, 1);
			ImmersiveFade_SetAlpha(FADE_IN_VALUE);
			return;
		end

		if #fadeTable > 0 then
			delay = tremove(fadeTable, 1);
			if delay > dt then
				tinsert(fadeTable, delay - dt);
			else
				startAlpha = UIParent:GetAlpha();

				if not fadeProgress[eventName] then
					fadeProgress[eventName] = true;
					ImmersiveFade_LogDebug(eventName .. " invoked (" .. startAlpha .. " start alpha, " .. fadeTime ..
						"s fade time, " .. fadeValue .. " end alpha)"
					);
					fadeFunc(UIParent, fadeTime, startAlpha, fadeValue);
					UIParent.fadeInfo.finishedFunc = function()
						ImmersiveFade_LogDebug(eventName .. " finished");
						ImmersiveFade_SetAlpha(fadeValue);
					end;
				end
			end
		end
	end);
end;

function ImmersiveFade_FadeIn()
	-- Stop fade out
	if #fadeOutTable ~= 0 or fadeProgress.FadeOut then
		ImmersiveFade_LogDebug("FadeOut cancelled");
		tremove(fadeOutTable, 1);
		fadeProgress.FadeOut = false;
	end

	-- Clear flags
	ImmersiveFade_ClearFlags();

	-- Add fade in if not already added
	if #fadeInTable == 0 and fadeProgress.FadeIn ~= true then
		startAlpha = UIParent:GetAlpha()

		-- Ignore if alpha is close enough
		if math.abs(startAlpha - FADE_IN_VALUE) < ALPHA_EPSILON then
			return;
		end

		if FADE_IN_DELAY > TIME_EPSILON then
			ImmersiveFade_LogDebug("FadeIn started (" .. FADE_IN_DELAY .. "s delay)");
			tinsert(fadeInTable, FADE_IN_DELAY);
		else
			ImmersiveFade_LogDebug("FadeIn no delay");
			fadeProgress.FadeIn = true;
			UIFrameFadeIn(UIParent, FADE_IN_TIME, startAlpha, FADE_IN_VALUE);
			UIParent.fadeInfo.finishedFunc = function()
				ImmersiveFade_LogDebug("FadeIn no delay finished");
				ImmersiveFade_SetAlpha(FADE_IN_VALUE);
			end;
		end
	end
end

function ImmersiveFade_FadeOut()
	-- Don't fade out if fading in
	if #fadeInTable ~= 0 or fadeProgress.FadeIn == true then
		return;
	end

	-- Add fade out if not already added
	if #fadeOutTable == 0 and fadeProgress.FadeOut ~= true then
		startAlpha = UIParent:GetAlpha()

		-- Ignore if alpha is close enough
		if math.abs(startAlpha - FADE_OUT_VALUE) < ALPHA_EPSILON then
			return;
		end

		if FADE_OUT_DELAY > TIME_EPSILON then
			ImmersiveFade_LogDebug("FadeOut started (" .. FADE_OUT_DELAY .. "s delay)");
			tinsert(fadeOutTable, FADE_OUT_DELAY);
		else
			ImmersiveFade_LogDebug("FadeOut no delay");
			fadeProgress.FadeOut = true;
			UIFrameFadeIn(UIParent, FADE_OUT_TIME, startAlpha, FADE_OUT_VALUE);
			UIParent.fadeInfo.finishedFunc = function()
				ImmersiveFade_LogDebug("FadeOut no delay finished");
				ImmersiveFade_SetAlpha(FADE_OUT_VALUE);
			end;
		end
	end
end

-- Create events
ImmersiveFade_LogDebug("Creating fade events");

ImmersiveFade_CreateFadeEvent(
	"FadeIn",
	fadeInTable,
	FADE_IN_TIME,
	FADE_IN_VALUE,
	UIFrameFadeIn
);

ImmersiveFade_CreateFadeEvent(
	"FadeOut",
	fadeOutTable,
	FADE_OUT_TIME,
	FADE_OUT_VALUE,
	UIFrameFadeOut
);

--------------------------------------------------------------------------------
-- Main addon loop
--------------------------------------------------------------------------------

addonFrame:HookScript("OnUpdate", function()

	-- UIFrameFadeIn causes an access violation in combat, set alpha to fade in instantly
	-- We generally want instant access to the UI in combat anyways
	if UnitAffectingCombat("Player")
	or InCombatLockdown() then
		ImmersiveFade_SetAlpha(FADE_IN_VALUE);
		return;
	end;

	-- Set parent for excluded frames
	for i = 1, #EXCLUDE_FRAMES do
		ExcludeFrame = EXCLUDE_FRAMES[i]
		if (ExcludeFrame ~= nil and ExcludeFrame:GetParent() ~= nil) then
			ExcludeFrame:SetParent(nil);
		end
	end

	-- In group or raid
	if IsInGroup()
	or IsInRaid() then
		ImmersiveFade_FadeIn();
		return;
	end;

	-- Currently dead or ghost
	if UnitIsDeadOrGhost("player") then
		ImmersiveFade_FadeIn();
		return;
	end;

	-- In vehicle
	if UnitInVehicle("player") then
		ImmersiveFade_FadeIn();
		return;
	end;

	-- Player or pet health less than max health
	if (UnitHealth("player") < UnitHealthMax("player"))
	or (UnitHealth("pet") < UnitHealthMax("pet")) then
		ImmersiveFade_FadeIn();
		return;
	end;

	-- Unit conditions (target, focus)
	if UnitExists("target")
	or UnitExists("focus") then
		ImmersiveFade_FadeIn();
		return;
	end

	-- Unit conditions (casting)
	if castSucceeded
	or UnitCastingInfo("player")
	or UnitCastingInfo("vehicle")
	or UnitChannelInfo("player")
	or UnitChannelInfo("vehicle") then
		ImmersiveFade_FadeIn();
		return;
	end

	-- Whisper received
	if receivedWhisper then
		ImmersiveFade_FadeIn();
		return;
	end

	-- Chat frame edit box has text
	if (ChatFrame1EditBox:GetText() ~= nil and ChatFrame1EditBox:GetText() ~= "")
	or (ChatFrame2EditBox:GetText() ~= nil and ChatFrame2EditBox:GetText() ~= "")
	or (ChatFrame3EditBox:GetText() ~= nil and ChatFrame3EditBox:GetText() ~= "")
	or (ChatFrame4EditBox:GetText() ~= nil and ChatFrame4EditBox:GetText() ~= "")
	or (ChatFrame5EditBox:GetText() ~= nil and ChatFrame5EditBox:GetText() ~= "")
	or (ChatFrame6EditBox:GetText() ~= nil and ChatFrame6EditBox:GetText() ~= "") then
		ImmersiveFade_FadeIn();
		return;
	end

	-- Mouse over chat
	if MouseIsOver(ChatFrame1)
	or MouseIsOver(ChatFrame2)
	or MouseIsOver(ChatFrame3)
	or MouseIsOver(ChatFrame4)
	or MouseIsOver(ChatFrame5)
	or MouseIsOver(ChatFrame6) then
		ImmersiveFade_FadeIn();
		return;
	end

	-- Mouse over any other UI frame
	if GetMouseFocus() then
		MouseFrame = GetMouseFocus():GetName();
		if MouseFrame ~= "WorldFrame" then
			ImmersiveFade_FadeIn();
			return;
		end;
	end;

	-- Frame visibility control, default frames
	for i = 1, #DEFAULT_FRAMES do
		DefaultFrame = DEFAULT_FRAMES[i]
		if DefaultFrame ~= nil and DefaultFrame:IsVisible() then
			ImmersiveFade_FadeIn();
			return;
		end
	end

	-- Frame visibility control, custom frames
	for i = 1, #CUSTOM_FRAMES do
		CustomFrame = CUSTOM_FRAMES[i]
		if CustomFrame ~= nil and CustomFrame:IsVisible() then
			ImmersiveFade_FadeIn();
			return;
		end
	end

	-- Fade out
	ImmersiveFade_FadeOut();
end);