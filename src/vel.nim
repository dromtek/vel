import dimscord
    , asyncdispatch
    , strutils
    , options
    , os
    , sets
    , repository/state_repository
    , model/state
    , model/cache
    , std/tables
    , std/db_sqlite

proc getToken(): string =
    let token = os.getEnv("DISCORD_BOT_TOKEN")
    if token == "":
        raise newException(OSError,"DISCORD_BOT_TOKEN not supplied") 
    return token

proc establishDatabaseConnection(): DbConn =
    try:
        return open("mysqlite.db", "", "", "")
    except:
        raise newException(OSError,"fail connect to dtabase") 

let discord = newDiscordClient(getToken())

var mCache : MemCache = initTable[string, string]()

let db : DbConn = establishDatabaseConnection()

db.exec(sql"""
CREATE TABLE IF NOT EXISTS states (
    context CHAR
    , key CHAR
    , value CHAR
    , guild_id CHAR
)
""")

var stateRepo : stateRepository = newStateRepo(db,mCache)

proc isServerOwner(m: Message): Future[bool] {.async.} =
    if m.member.isNone or m.guild_id.isNone: 
        return false
 
    let guild = await discord.api.getGuild(m.guild_id.get())
    if (m.author.id != guild.owner_id): 
        return false 
    
    return true

proc isGuildCommunityAndInRuleChannelByMessage(m: Message): Future[bool] {.async.} =
    # let guild = await discord.api.getGuild(m.guild_id.get())
    # if guild.features.contains("COMMUNITY"):
    #     if guild.rules_channel_id.isSome:
    #         return guild.rules_channel_id.get() == m.channel_id
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

# TODO: Listen to interaction react to specific message
proc messageReactionAdd(s: Shard, m: Message, u: User, e: Emoji, exists: bool) {.event(discord).} =
    # let msg  = i.message.get()
    # let member = i.member.get()

    echo m.id
    # let state = stateRepo.findStateByStateQuery(stateQuery(
    #     context: ctxMemberVerification
    #     , key: "$1".format(MemberVerificationMessage)
    #     , guildID: msg.guild_id.get()
    # ))

    # if state.isSome:
    #     if msg.id == state.get().value:
    #         if msg.

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
        let community = await isGuildCommunityAndInRuleChannelByMessage(m)
        if not community : return

        var text = args[1..args.high].join(" ")
        if text == "":
            text = "Empty text."
        
        # TODO: Catch any exception here to rollback message and role creation.
        var msgId,roleId : string
        try:
            # silenced everyone
            let everyoneSilenced = await blindfoldEverybodyRoleInServer(m)
            if not everyoneSilenced:
                discard await discord.api.sendMessage(m.channel_id, "Fail to silenced everyone, I need more privilege to doing this.")
                return
            
            # create role for allwed role
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
                        allowed: role.permissions + disabled
                        , denied: role.permissions - disabled 
                    )

                    # This should check the roleId already exist or not if not
                    # proceed to create the role
                    if stateRepo.findStateByStateQuery(stateQuery(
                        context: ctxMemberVerification
                        , key: "$1".format(MemberVerificationRole)
                        , guildID: m.guild_id.get()
                    )).isSome:
                        break

                    let role = await discord.api.createGuildRole(
                        m.guild_id.get()
                        , "Vel's Approved"
                        , permissions = newPerm
                    )
                    roleId = role.id
                    
                    if not stateRepo.createState(stateData(
                        context: ctxMemberVerification
                        , key: "$1".format(MemberVerificationRole)
                        , value: role.id
                        , guildID: m.guild_id.get()
                    )):
                        echo "Failed to createState of MVRole"
                        break

                    break
            
             # Send message of aggrement
            let msg = await discord.api.sendMessage(m.channel_id, text)
            await discord.api.addMessageReaction(msg.channel_id,msg.id,"✔️")

            discard stateRepo.destroyStateByStateQuery(stateQuery(
                context: ctxMemberVerification
                , key: "$1".format(MemberVerificationMessage)
                , guildID: m.guild_id.get()
            ))

            if not stateRepo.createState(stateData(
                context: ctxMemberVerification
                , key: "$1".format(MemberVerificationMessage)
                , value: msg.id
                , guildID: m.guild_id.get()
            )):
                echo "Failed to createState of MVRule"
                await discord.api.deleteMessage(msg.channel_id,msg.id)
                break

            msgId = msg.id
        except:
            if msgId != "":
                await discord.api.deleteMessage(m.channel_id,msgId)
            if roleId != "":
                # do not delete roleId if config already exist
                await discord.api.deleteGuildRole(m.guild_id.get(),roleId)
        discard 
    else:
        discard

proc onReady(s: Shard, r: Ready) {.event(discord).} =
  echo "Ready as: " & $r.user

  await s.updateStatus(activity = some ActivityStatus(
      name: "reality.",
      kind: atWatching
  ), status = "idle")


# gateway_intents: is way to access some event that limited in default by discord
# so use intents to open that limit.
waitFor discord.startSession(
    gateway_intents = {giGuildMessageReactions}
)
