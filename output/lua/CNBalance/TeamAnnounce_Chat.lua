-- CNBalance/TeamAnnounce_Chat.lua
-- Prints server team announcements (e.g. the Origin Form resource fetch) as a bare line in the team colour:
--   "[Origin Form]: <player> has taken <n> t-res from the team pool as p-res."
--
-- The vanilla "Chat" message cannot do that: Chat.lua ALWAYS prepends "(Team) " / "(All) ", so the line came out as
-- "(Team) : <player> ve taken [n] resources from pool.". The server sends these as "CETeamAnnounce" instead (the same
-- message the Beta / Siege builds use for their Combat Engineers announcements), and this writes them straight into
-- the chat list.
--
-- The message list (`chatMessages`) is a file-local of Chat.lua, reached as an UPVALUE of ChatUI_AddSystemMessage.
-- Re-fetched on every call: ChatUI_GetMessages REBINDS that upvalue when it flushes, so a cached reference would go
-- stale. If it cannot be reached, the line still arrives through ChatUI_AddSystemMessage (system colour).
--
-- Loaded post lua/Chat.lua.

if not Client then
    return
end

local function GetChatMessages()
    if not ChatUI_AddSystemMessage or not debug or not debug.getupvaluex then
        return nil
    end
    return debug.getupvaluex(ChatUI_AddSystemMessage, "chatMessages")
end

-- One entry is EIGHT values, as Chat.lua's own OnChatMessageInternal pushes them:
--   prefix colour, prefix text, body colour, body text, isCommander, drawRookie, reserved, reserved
local function AddTeamChatLine(text)

    local chatMessages = GetChatMessages()
    local player = Client.GetLocalPlayer()
    if not chatMessages or not text or not player then
        return false
    end

    local teamNumber = player:GetTeamNumber()
    local teamType = player.GetTeamType and player:GetTeamType() or kAlienTeamType

    table.insert(chatMessages, GetColorForTeamNumber(teamNumber))
    table.insert(chatMessages, "")
    table.insert(chatMessages, kChatTextColor[teamType] or kChatTextColor[kAlienTeamType])
    table.insert(chatMessages, text)
    table.insert(chatMessages, false)
    table.insert(chatMessages, false)
    table.insert(chatMessages, 0)
    table.insert(chatMessages, 0)

    StartSoundEffect(player:GetChatSound())

    return true
end

Client.HookNetworkMessage("CETeamAnnounce", function(message)

    if not message or not message.message then
        return
    end

    if AddTeamChatLine(message.message) then
        return
    end

    if ChatUI_AddSystemMessage then
        ChatUI_AddSystemMessage(message.message)
    end

end)
