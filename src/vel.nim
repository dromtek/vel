import dimscord
    , asyncdispatch
    , strutils
    , options
    , os
    , sets

proc getToken(): string =
    let token = os.getEnv("DISCORD_BOT_TOKEN")
    if token == "":
        raise newException(OSError,"DISCORD_BOT_TOKEN not supplied") 
    return token

let discord = newDiscordClient(getToken())

proc isServerOwner(m: Message): Future[bool] {.async.} =
    if m.member.isNone or m.guild_id.isNone: 
        return false
 
    let guild = await discord.api.getGuild(m.guild_id.get())
    if (m.author.id != guild.owner_id): 
        return false 
    
    return true

proc isGuildCommunityByMessage(m: Message): Future[bool] {.async.} =
    let guild = await discord.api.getGuild(m.guild_id.get())
    return guild.features.contains("COMMUNITY")

proc blindfoldEverybodyRoleInServer(m: Message): Future[bool] {.async.} =
    let roles = await discord.api.getGuildRoles(m.guild_id.get())
    for role in roles:
        if role.name == "@everyone":

            let disabled : set[PermissionFlags] = {
                permViewChannel
                , permVoiceConnect
                , permMentionEveryone 
                , permManageGuild
            }

            let newPerm = PermObj(
                allowed: role.permissions - disabled
                , denied: disabled 
            )

            discard await discord.api.editGuildRole(
                m.guild_id.get()
                , role.id
                , some role.name 
                , role.icon
                , role.unicode_emoji 
                , some newPerm
                , some role.color 
                , some role.hoist 
                , some role.mentionable
            )
            return true
    return false

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    let args = m.content.split(" ") # Splits a message.
    if m.author.bot or not args[0].startsWith("$$"): return
    let command = args[0][2..args[0].high]
 
    case command.toLowerAscii():
    of "test": # Sends a basic message.
        discard await discord.api.sendMessage(m.channel_id, "Success!")
    of "shut_everyone":
        let shut = await blindfoldEverybodyRoleInServer(m)
        if shut:
            discard await discord.api.sendMessage(m.channel_id, "Everybody has silenced!")
        else:
            discard await discord.api.sendMessage(m.channel_id, "Fail to controlling crowd!")

    of "roles":
        let roles = await discord.api.getGuildRoles(m.guild_id.get())
        var role = ""
        for r in roles:
            role = role & r.id & " " & r.name & " - "  
            echo r.name
            for p in r.permissions:
               case p:
               of permViewChannel:
                echo "Boleh Liat Channel"
               else:
                discard

        discard await discord.api.sendMessage(m.channel_id, role)
    of "rule":
        # check is sender are server owner
        let owner = await isServerOwner(m)
        if not owner : return

        # check is server are enable community feature
        let community = await isGuildCommunityByMessage(m)
        if not community : return

        var text = args[1..args.high].join(" ")
        if text == "":
            text = "Empty text."

        # silenced everyone
        let everyoneSilenced = await blindfoldEverybodyRoleInServer(m)
        if not everyoneSilenced:
            discard await discord.api.sendMessage(m.channel_id, "Fail to silenced everyone, I need more privilege to doing this.")
            return

        # Send message of aggrement
        let msg = await discord.api.sendMessage(m.channel_id, text)
        await discord.api.addMessageReaction(msg.channel_id,msg.id,"✔️")

        # set this to storage for reread.

        discard 
    else:
        discard

proc onReady(s: Shard, r: Ready) {.event(discord).} =
  echo "Ready as: " & $r.user

  await s.updateStatus(activity = some ActivityStatus(
      name: "reality.",
      kind: atWatching
  ), status = "idle")


waitFor discord.startSession()
