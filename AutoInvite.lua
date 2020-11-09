AutoInvite = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceEvent-2.0", "AceHook-2.1" ,  "AceDB-2.0")

local GlobalTimer = 0
local Player;

-- Default Settings
local defaults = {
  Active = true,
  Keyword = "invite", -- initial keyword
  Type = "PARTY", -- initial group mode
  Channel = 1, -- initial channel type
  Whitelist = false, -- initial whitelist mode
  Restriction = true, -- initial restriction
  Sensitive = true, -- initial case sensitive mode
}

-- command options /ai (AceConsole-2)
local options  = {
  type = "group",
  handler = AutoInvite,
  args =
  {
    active =
    {
      name = "Active",
      desc = "Activate/Suspend 'Auto Invite'",
      type = "toggle",
      get  = function () return AutoInvite.db.profile.Active end,
      set  = function (newStatus) AutoInvite.db.profile.Active = newStatus end,
      order = 1,
    },
    keyword =
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
    type = 
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
    channel =
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
    whitelist =
    {
      name = "Whitelist",
      desc = "Activate/Disable Whitelist Mode",
      type = "toggle",
      get  = function () return AutoInvite.db.profile.Whitelist end,
      set  = function (newWhitelist) AutoInvite.db.profile.Whitelist = newWhitelist end,
      disabled = function() return not AutoInvite.db.profile.Active end,
      order = 5,
    },
    restriction =
    {
      name = "Restriction",
      desc = "Activate/Disable Officer Whitelist restriction",
      type = "toggle",
      get  = function () return AutoInvite.db.profile.Restriction end,
      set  = function (newRestriction) AutoInvite.db.profile.Restriction = newRestriction end,
      disabled = function() return (not AutoInvite.db.profile.Active) or (not AutoInvite.db.profile.Whitelist) end,
      order = 6,
    },
    alist = 
    {
      name = "AList", 
      desc = "Invite all players from whitelist",
      type = "execute",
      func = function() AutoInvite:InviteWhiteList() end,
      disabled = function() return not AutoInvite.db.profile.Active end,
      order = 7,
    },
    tester =
    {
      name = "Tester",
      desc = "LALA",
      type = "execute",
      func = function () AutoInvite:Tester() end, 
    },
    case =
    {
      name = "Sensitive Keyword Check",
      desc = "Activate/Disable the Sensitive Case Check.",
      type = "toggle",
      get  = function () return AutoInvite.db.profile.Sensitive end,
      set  = function (newStatus) AutoInvite.db.profile.Sensitive = newStatus end,
      disabled = function() return not AutoInvite.db.profile.Active end,
      order = 8,
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

function AutoInvite:Tester()
  local currentTime = time()
  if(currentTime >= (GlobalTimer + 5)) then
    self:Print("Got it")
    GlobalTimer = currentTime
  else
    self:Print("Error")
  end
end

-- Called when the addon is initialized
function AutoInvite:OnInitialize()
  Player = UnitName("player");

  self:RegisterEvent("CHAT_MSG_WHISPER");
  self:RegisterEvent("CHAT_MSG_GUILD");
  self:RegisterEvent("CHAT_MSG_OFFICER");

  self:RegisterDB("AutoInviteDB", "AutoInviteDBPC")
  self:RegisterDefaults("profile", defaults )

  self:RegisterChatCommand({"/autoinvite", "/ai"}, options)

  self:Print("Addon loaded. use |cff00FF00/ai|r to configure.")
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
-- @param msg recieved keyword
-- @return if the msg is equal to the addon keyword
function AutoInvite:HasTheKeyword(msg)
  if(self.db.profile.Sensitive) then return msg == self.db.profile.Keyword;
  else return string.lower(msg) == string.lower(self.db.profile.Keyword);
  end
end

-- 
function AutoInvite:IsWhiteListMode()
  return self.db.profile.Whitelist;
end

-- Interface to send whisper messages
-- @param to reciever nickname
-- @param msg current msg sttring
function AutoInvite:SendWhisper(to, msg) 
  SendChatMessage(msg, "WHISPER", "Common", to);
end

-- Check if a speciic player is inside of white list array
-- @param nickname current player nickname
-- @return if nickname is in the white list
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
  local currentTime = time()
  if(currentTime >= (GlobalTimer + 5)) then
    self:Print("Sending the invites to all players of white list...")
    GlobalTimer = currentTime
  else
    return self:Print("You only can use this feature again after 5s.")
  end

  for j = 1, 50 do
    if(self:CanInvite()) then
      if (WhiteList_Players[j]) then
        self:ThrowInvite(WhiteList_Players[j]);
      end
    end
  end
end