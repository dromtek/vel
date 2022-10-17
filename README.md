# Vel

![GitHub](https://img.shields.io/github/license/dromtek/vel)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](code_of_conduct.md)


Administration discord bot for Dromtek HQ server in Discord, CAUTION: this is experimental bot.

## Feature

- `%%authoritarianism`, restrict everyone role to read all channel before react the rule messages.
- `%%watashi/watashinot`, self-assign role by user throught text command. (I think this should be on slash command)
- `%%wataset`, set allowed role for watashi/watashinot command.

## How to run ?

- Install Nim and GCC.
- Install openssl development library and sqlite3 shared library (I planned to make this switchable to mysql/pg but not now).
- Make sure you had make discord application for your bot.
- Open project folder as working directory then run `DISCORD_TOKEN_BOT=<your discord bot token> DB_URL=<put you db address> nimble run` to testing run the project.
- For production, build an binary executable then run it as a service on server. This approach to reduce needed of development material at production server.

### How to deploy this bot?

This bot hosted on fly.io, to setup this you should:

- Set secrets for `DISCORD_BOT_TOKEN` and `DB_URL` (not use `sqlite3://` for  DB_URL).
- Set volume to hosting your sqlite database, you can see in this fly.toml using name "storeg" as placeholder, replace it with your volume name.
- Then, run `flyctl launch` to make it available online ([set wireguard](https://fly.io/docs/reference/private-networking/), if you're new using fly.io).
 
See the [fly.toml](./fly.toml) for details.

## How to contribute?

[CONTRIBUTING](./CONTRIBUTING.md)

## Maintainer

- Elq "Lort Kegelaban" Rett ([@frederett](https://github.com/frederett))