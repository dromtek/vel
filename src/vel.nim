import dimscord, asyncdispatch, strutils, options, os

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

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    let args = m.content.split(" ") # Splits a message.
    if m.author.bot or not args[0].startsWith("$$"): return
    let command = args[0][2..args[0].high]

    case command.toLowerAscii():
    of "test": # Sends a basic message.
        discard await discord.api.sendMessage(m.channel_id, "Success!")
    of "rule":
        let isOwner = await isServerOwner(m)
        if not isOwner : return

        var text = args[1..args.high].join(" ")
        if text == "":
            text = "Empty text."
        let msg = await discord.api.sendMessage(m.channel_id, text)
        await discord.api.addMessageReaction(msg.channel_id,msg.id,"✔️")
        discard 
        # let emoji : string = "👀"
        # discard await discord.api.addMessageReaction(msg.channel_id,msg.id,emoji)
    else:
        discard

proc onReady(s: Shard, r: Ready) {.event(discord).} =
  echo "Ready as: " & $r.user

  await s.updateStatus(activity = some ActivityStatus(
      name: "reality.",
      kind: atWatching
  ), status = "idle")


waitFor discord.startSession()
