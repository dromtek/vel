import dimscord
    , asyncdispatch
    , strutils
    , options
    , std/os
    , repository/state_repository
    , model/state
    , model/cache
    , model/constant
    , std/db_sqlite

proc getToken(): string =
    let token = os.getEnv("DISCORD_BOT_TOKEN")
    if token == "":
        raise newException(OSError,"DISCORD_BOT_TOKEN not supplied") 
    return token

proc establishDatabaseConnection(): DbConn =
    let dbAddress = os.getEnv("DB_URL")
    if dbAddress == "":
        raise newException(OSError,"DISCORD_BOT_TOKEN not supplied") 
    try:
        return open(dbAddress, "", "", "")
    except:
        raise newException(OSError,"fail connect to dtabase") 

let discord = newDiscordClient(getToken())

var mCache = new MemCache

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

proc isMemberApproved(m: Message): Future[bool] {.async.} =
    if m.member.isNone: return false
    let roleId = stateRepo.findStateByStateQuery(
            stateQuery(
                context: ctxMemberVerification
                , key: MemberVerificationRole
                , guildID: m.guild_id.get()
            )
        )
    if roleId.isNone : return false

    for role in m.member.get().roles:
        if role == roleId.get().value:
            return true
    return false

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

            let newPerm = PermObj(
                allowed: role.permissions - constant.everyoneDeniedPermissions
                , denied: constant.everyoneDeniedPermissions
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

    # Below this is event specific to guild only
    if m.guild_id.isNone : return

    let state = stateRepo.findStateByStateQuery(stateQuery(
        context: ctxMemberVerification
        , key: MemberVerificationMessage
        , guildID: m.guild_id.get()
    ))

    if state.isSome and (m.id == state.get().value):
        if e.name.isNone: 
            return
        if e.name.get() == constant.checkListEmoji:
            let roleId = stateRepo.findStateByStateQuery(
                stateQuery(
                    context: ctxMemberVerification
                    , key: MemberVerificationRole
                    , guildID: m.guild_id.get()
                )
            )
            if roleId.isNone : break

            let roles = await discord.api.getGuildRoles(m.guild_id.get())

            for role in roles:
                if role.id == roleId.get().value:
                    if not role.permissions.contains(permAdministrator):
                        await discord.api.addGuildMemberRole(
                            m.guild_id.get()
                            , u.id
                            , roleId.get().value
                            , "Readed group rules"
                        )
                        return
            
            await discord.api.deleteMessageReaction(
                m.channel_id
                , m.id
                , e.name.get()
                , u.id
            )
        else:
            await discord.api.deleteMessageReaction(
                m.channel_id
                , m.id
                , e.name.get()
                , u.id
            )

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    let args = m.content.split(" ") # Splits a message.
    if m.author.bot or not args[0].startsWith("%%"): return
    let command = args[0][2..args[0].high]

    case command.toLowerAscii():
    of "test": # Sends a basic message.
        # check is sender are server owner
        let owner = await isServerOwner(m)
        if not owner : return
        discard await discord.api.sendMessage(m.channel_id, "Success!")
    of "roles":
        # check is sender are server owner
        let owner = await isServerOwner(m)
        if not owner : return

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
    of "wataset":
        # check is sender are server owner
        let owner = await isServerOwner(m)
        if not owner : return

        await discord.api.deleteMessage(m.channel_id,m.id)

        var text = args[1..args.high].join(" ")
        if text == "":
            discard await discord.api.sendMessage(m.channel_id, "Use separated as coma to allowed roles to assign, like dog,cat,duck")
            return

        discard stateRepo.destroyStateByStateQuery(stateQuery(
            context: ctxWatashiFeature
            , key: AllowedRoleList
            , guildID: m.guild_id.get()
        ))
        if not stateRepo.createState(stateData(
            context: ctxWatashiFeature
            , key: AllowedRoleList
            , value: text.toLowerAscii
            , guildID: m.guild_id.get()
        )):
            discard await discord.api.sendMessage(m.channel_id, "Fail to store allowed role list.")
            return
        
        discard await discord.api.sendMessage(m.channel_id, "Ok, %%watashi/not available now.")
    of "watashi":
        # TODO: add validation about role that had privileged 
        # and circuminstances with other feature
        await discord.api.deleteMessage(m.channel_id,m.id)
        if not (await isMemberApproved(m)): return
        
        let roleApproved = stateRepo.findStateByStateQuery(stateQuery(
            context: ctxMemberVerification
            , key: MemberVerificationRole
            , guildID: m.guild_id.get()
        ))

        let roleAllowed = stateRepo.findStateByStateQuery(stateQuery(
            context: ctxWatashiFeature
            , key: AllowedRoleList
            , guildID: m.guild_id.get()
        ))

        if roleAllowed.isNone: return
        echo "1"

        let allowedRoles = roleAllowed.get().value.split(",")

        var text = args[1..args.high].join(" ")
        if text == "":
            return
        echo "2"

        let roles = await discord.api.getGuildRoles(m.guild_id.get())

        for r in roles:
            if allowedRoles.contains(r.name.toLowerAscii): 
                if not r.permissions.contains(permAdministrator):
                    if r.name.toLowerAscii() == text.toLowerAscii():
                        await discord.api.addGuildMemberRole(
                            m.guild_id.get()
                            , m.author.id
                            , r.id
                            ,"Get by using watashi feature"
                        )
                        break
    of "watashinot":
        # TODO: add validation about role that had privileged 
        # and circuminstances with other feature
        if not (await isMemberApproved(m)): return
        await discord.api.deleteMessage(m.channel_id,m.id)

        let roleApproved = stateRepo.findStateByStateQuery(stateQuery(
                context: ctxMemberVerification
                , key: MemberVerificationRole
                , guildID: m.guild_id.get()
        ))

        var text = args[1..args.high].join(" ")
        if text == "":
            return

        let roleAllowed = stateRepo.findStateByStateQuery(stateQuery(
            context: ctxWatashiFeature
            , key: AllowedRoleList
            , guildID: m.guild_id.get()
        ))

        if roleAllowed.isNone: return

        let allowedRoles = roleAllowed.get().value.split(",")

        let roles = await discord.api.getGuildRoles(m.guild_id.get())

        for r in roles:
            if allowedRoles.contains(r.name.toLowerAscii): 
                if not r.permissions.contains(permAdministrator):
                    if r.name.toLowerAscii() == text.toLowerAscii():
                        await discord.api.removeGuildMemberRole(
                            m.guild_id.get()
                            , m.author.id
                            , r.id
                            ,"remove role by using watashinot feature"
                        )
                        break
    of "authoritarianism":
        # check is sender are server owner
        let owner = await isServerOwner(m)
        if not owner : return

        # check is server are enable community feature
        let community = await isGuildCommunityAndInRuleChannelByMessage(m)
        if not community : return

        var text = args[1..args.high].join(" ")
        if text == "":
            text = "React to this message meaning you agree with you rules and will unlocked."
        
        var msgId,roleId : string
        try:
            await discord.api.deleteMessage(m.channel_id,m.id)
            # silenced everyone
            let everyoneSilenced = await blindfoldEverybodyRoleInServer(m)
            if not everyoneSilenced:
                discard await discord.api.sendMessage(m.channel_id, "Fail to silenced everyone, I need more privilege to doing this.")
                return
            
            # create role for allwed role

            # This should check the roleId already exist or not if not
            # proceed to create the role
            if stateRepo.findStateByStateQuery(stateQuery(
                context: ctxMemberVerification
                , key: MemberVerificationRole
                , guildID: m.guild_id.get()
            )).isNone:

                let newPerm = PermObj(
                    allowed: constant.approvedMemberAllowedPermissions
                )

                # create role
                let role = await discord.api.createGuildRole(
                    m.guild_id.get()
                    , "Vel's Approved"
                    , permissions = newPerm
                )
                roleId = role.id
                
                if not stateRepo.createState(stateData(
                    context: ctxMemberVerification
                    , key: MemberVerificationRole
                    , value: role.id
                    , guildID: m.guild_id.get()
                )):
                    echo "Failed to createState of MVRole"
                    break
            
             # Send message of aggrement
            let msg = await discord.api.sendMessage(m.channel_id, text)
            msgId = msg.id
            await discord.api.addMessageReaction(msg.channel_id,msg.id, constant.checkListEmoji)

            discard stateRepo.destroyStateByStateQuery(stateQuery(
                context: ctxMemberVerification
                , key: MemberVerificationMessage
                , guildID: m.guild_id.get()
            ))

            
            discard stateRepo.createState(stateData(
                context: ctxMemberVerification
                , key: MemberVerificationMessage
                , value: msg.id
                , guildID: m.guild_id.get()
            ))

            discard await discord.api.sendMessage(m.channel_id, "[DELETE AFTER READ] The Vel's Approved role is created but with buggy permission, before you proceed this rearrange permission for Vel's Approved role. If the role contain admin grant, no member will given the role.")
        except:
            if msgId != "":
                await discord.api.deleteMessage(m.channel_id,msgId)
            if roleId != "":
                # do not delete roleId if config already exist
                await discord.api.deleteGuildRole(m.guild_id.get(),roleId)
            let
                e = getCurrentException()
                msg = getCurrentExceptionMsg()
            echo "Got exception ", repr(e), " with message ", msg
            discard await discord.api.sendMessage(m.channel_id, "Fail to done this order, Maybe I need more privilege or there a bug on my algorithm.")
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
    gateway_intents = {
        giGuildMessageReactions
        , giGuildMessages
        , giGuildMembers
        , giGuilds
        , giDirectMessages
        , giMessageContent
    }
)
