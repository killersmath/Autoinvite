AutoInvite = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceEvent-2.0", "AceHook-2.1" ,  "AceDB-2.0")

local Player;

-- Default Settings
local defaults = {
  Active = true,
  Keyword = "invite",
  Type = "PARTY",
  Channel = 1,
  Whitelist = false,
  Restriction = true
}

-- command options /ai (AceConsole-2)
local options  = {
  type = "group",
  handler = AutoInvite,
  args =
  {
    Active =
    {
      name = "Active",
      desc = "Activate/Suspend 'Auto Invite'",
      type = "toggle",
      get  = function () return AutoInvite.db.profile.Active end,
      set  = function (newStatus) AutoInvite.db.profile.Active = newStatus end,
      order = 1,
    },
    Keyword =
    {
      name = "Keyword",
      desc = "Invite Keyword",
      type = "text",
      usage = "<message>",
      get = function () return AutoInvite.db.profile.Keyword end,
      set = function (newKeyword) AutoInvite.db.profile.Keyword = newKeyword end,
      disabled = function() return not AutoInvite.db.profile.Active end,
      order = 2,
    },
    Type = 
    {
      name = "Type",
      desc = "Party / Raid",
      type = "text",
      get  = function () return AutoInvite.db.profile.Type end,
      set  = function (newChannel) AutoInvite.db.profile.Type = newChannel end,
      usage = "<group>",
      disabled = function() return not AutoInvite.db.profile.Active end,
      order = 3,
      validate = {["PARTY"]=PARTY,["RAID"]=RAID},
    },
    Channel =
    {
      name = "Channel",
      desc = "1 = Whisper, 2 = Guild, 3 = Officer, 4 = Guild / Officer, 5 = All",
      type = "range",
      get  = function () return AutoInvite.db.profile.Channel end,
      set  = function (newType) AutoInvite.db.profile.Channel = newType end,
      disabled = function() return not AutoInvite.db.profile.Active end,
      min = 1,
      max = 5,
      step = 1,
      order = 4,
    },
    Whitelist =
    {
      name = "Whitelist",
      desc = "Activate/Disable Whitelist Mode",
      type = "toggle",
      get  = function () return AutoInvite.db.profile.Whitelist end,
      set  = function (newWhitelist) AutoInvite.db.profile.Whitelist = newWhitelist end,
      disabled = function() return not AutoInvite.db.profile.Active end,
      order = 5,
    },
    Restriction =
    {
      name = "Rescrition",
      desc = "Activate/Disable Officer Whitelist restriction",
      type = "toggle",
      get  = function () return AutoInvite.db.profile.Restriction end,
      set  = function (newRestriction) AutoInvite.db.profile.Restriction = newRestriction end,
      disabled = function() return not AutoInvite.db.profile.Active end,
      order = 6,
    },
    AList = 
	{
	  order = 3,
	  name = "AList", 
	  type = "execute",
	  desc = "Invite all players from whitelist",
      func = function() AutoInvite:InviteWhiteList() end,
      disabled = function() return not AutoInvite.db.profile.Active end,
	},
  },
}

-- Messages Array
local messages = {
  Invite = "AutoInvite: Invite has been sent to %s.",
  Not_in_Whitelist = "AutoInvite: Can't invite %s, it is not in the Whitelist.",
  Party_Full = "AutoInvite: Can't invite %s right now, party is full.",
  Raid_Full = "AutoInvite: Can't invite %s right now, raid is full",
  Not_Party_Leader = "AutoInvite: Can't invite %s right now, i'm not party leader.",
  Not_RL_Assist = "AutoInvite: Can't invite %s right now, i'm not raid leader/assistant.",
}

-- Called when the addon is initialized
function AutoInvite:OnInitialize()
  Player = UnitName("player");

  self:RegisterEvent("CHAT_MSG_WHISPER");
  self:RegisterEvent("CHAT_MSG_GUILD");
  self:RegisterEvent("CHAT_MSG_OFFICER");

  self:RegisterDB("AutoInviteDB", "AutoInviteDBPC")
  self:RegisterDefaults("profile", defaults )

  self:RegisterChatCommand({"/autoinvite", "/ai"}, options)
end

-- Whisper messages handler (msg, player, ...)
function AutoInvite:CHAT_MSG_WHISPER() 
  if(self.db.profile.Active) then
    if(self.db.profile.Channel == 1 or self.db.profile.Channel == 5) then
      local who = arg2;
      local what = arg1;
      if(who ~= Player) then self:ProcessMessage(who, what) end;
    end
  end
end

-- Guild Chat messages handler (msg, player, ...)
function AutoInvite:CHAT_MSG_GUILD() 
  if(self.db.profile.Active) then
    if(self.db.profile.Channel == 2 or self.db.profile.Channel == 4 or self.db.profile.Channel == 5) then
      local who = arg2;
      local what = arg1;
      if(who ~= Player) then self:ProcessMessage(who, what) end;
    end
  end
end

-- Officer Chat messages handler (msg, player, ...)
function AutoInvite:CHAT_MSG_OFFICER() 
  if(self.db.profile.Active) then
    if(self.db.profile.Channel == 3 or self.db.profile.Channel == 4 or self.db.profile.Channel == 5) then
      local who = arg2;
      local what = arg1;
      if(who ~= Player) then self:ProcessMessage(who, what) end;
    end
  end
end

-- Main Function resposable to check if the current message is valid
function AutoInvite:ProcessMessage(who, what)
  if(self:HasTheKeyword(what)) then 
    if(self:IsWhiteListMode()) then
      local found = self:CheckInWhiteList(who);
      if(found) then self:ThrowInvite(who);
      else self:SendWhisper(who, string.format(messages["Not_in_Whitelist"], who));
      end
    else  self:ThrowInvite(who);
    end
  end
end

-- Invite the player to the group depending of group type
-- Throw a message to the player about the current situation of the invitation
function AutoInvite:ThrowInvite(who)
	local numgroup;
  local gtype = self.db.profile.Type;
  if(gtype == "PARTY") then
    numgroup = GetNumPartyMembers();
    if((IsPartyLeader() and numgroup < 4) or (numgroup == 0)) then 
      InviteByName(who);
      return self:SendWhisper(who, string.format(messages["Invite"], who));
    else 
      if(numgroup >= 4) then return self:SendWhisper(who, string.format(messages["Party_Full"], who));
      else return self:SendWhisper(who, string.format(messages["Not_Party_Leader"], who));
      end
    end
  elseif(gtype == "RAID") then
    numgroup = GetNumRaidMembers();
    if(numgroup == 0) then --Not currently in a raid
      numparty = GetNumPartyMembers();
      if(numparty == 0) then 
        InviteByName(who); --Nobody in the party? Start a new one!
        return self:SendWhisper(who, string.format(messages["Invite"], who));
      elseif(numparty < 4) then
        if(IsPartyLeader()) then 
          InviteByName(who); --4 or less party members? Invite if you can.
          return self:SendWhisper(who, string.format(messages["Invite"], who));
        else return self:SendWhisper(who, string.format(messages["Not_Party_Leader"], who));
        end
      elseif(GetNumPartyMembers() == 4)then --if you've got a 5-man party (GetNumPartyMembers excludes yourself) convert to raid.
        if(IsPartyLeader()) then 
          self:print("Raid mode enabled: Converting your group to a raid.");
          ConvertToRaid();
          InviteByName(who);
          return self:SendWhisper(who, string.format(messages["Invite"], who));
        else return self:SendWhisper(who, string.format(messages["Not_Party_Leader"], who));
        end
      end
    elseif((IsRaidLeader() or IsRaidOfficer()) and numgroup < 40) then 
      InviteByName(who);
      return self:SendWhisper(who, string.format(messages["Invite"], who));
    else
      if(numgroup > 39) then return self:SendWhisper(who, string.format(messages["Raid_Full"], who));
      else return self:SendWhisper(who, string.format(messages["Not_RL_Assist"], who));
      end
    end
  end
end

-- Keyword comparator
function AutoInvite:HasTheKeyword(what)
  return (what) == (self.db.profile.Keyword);
  --return string.find(string.lower(what), AutoInviteOptions[Realm][Player]["Invite"], 1, true);
end

-- 
function AutoInvite:IsWhiteListMode()
  return self.db.profile.Whitelist;
end

-- Interface to send whisper messages
function AutoInvite:SendWhisper(to, message) 
  SendChatMessage(message, "WHISPER", "Common", to);
end

-- Check if a speciic player is inside of white list array
function AutoInvite:CheckInWhiteList(nickname)
  for j = 1, 50 do
    if(WhiteList_Players[j]) then
      if(WhiteList_Players[j] == nickname) then
        return true;
      end
    end
  end
  return false
end

-- Helper to check out if it's possible to invite other players
function AutoInvite:CanInvite()
  local numgroup;
  local gtype = self.db.profile.Type;
  if(gtype == "PARTY") then
    numgroup = GetNumPartyMembers();
    if((IsPartyLeader() and numgroup < 4) or (numgroup == 0)) then return true;
    end
  elseif(gtype == "RAID") then
    numgroup = GetNumRaidMembers();
    if (numgroup == 0) then
      numparty = GetNumPartyMembers();
      if(numparty == 0) then return true;
      else return IsPartyLeader();
      end
    elseif(IsRaidLeader() or IsRaidOfficer() and (numgroup < 40)) then
      return true;
    end
  end
  return false;
end


-- Throw a invite to the all players in the Whitelist
function AutoInvite:InviteWhiteList()
  for j = 1, 50 do
    if(self:CanInvite()) then
      if (WhiteList_Players[j]) then
        self:ThrowInvite(WhiteList_Players[j]);
      end
    end
  end
end