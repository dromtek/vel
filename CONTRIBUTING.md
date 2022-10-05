# Contributing

Ara-Ara~~, Thank you for putting interest to contributing in our code.

You can contribute by reporting bug, suggesting an idea, add or update documentation, bug fixes even proposing a new feature.

## Setup development workspace

- You need Nim compiler installer along with openssl source library and C/C++ compiler.
- Create a discord account and installing the account to testing the bot.

This bot depend on [dimscord](https://github.com/krisppurg/dimscord) as library, but the documentation less friendly. For understanding the discord bot concept this book is recommended : [A Guide to Discord Bots](https://maah.gitbooks.io/discord-bots/content/).

TL;DR for the book : We create an application that listen to an event from discord server to reply a response from that event, such joining user, command message or reaction, etc.

## Thing about dimscord

Dimscord handle all event as a function, which mean to handle event `onReady`  we just create a function `onReady` that will called when discord fires it, usually the function come with pragma `.event{discord}.`.

Every dimscord method from a object is asynchronous, such `getGuild` methods from `Message` object is asynchrounous. By mean, asynchronous the function execution is not in same thread as our program flow so we need to await them to finish using `await` keyword. So when you want to create a custom function to handle such things related with dimscord, make sure add `.async` pragma and use Future as return type of your function.

## Git stuff

Before you create PR for you contributtion, please check issue whether same case already exist or if you want to assigned to it just tag maintainers. If no one issue fit with you case, then you can create new issue for it. 

Make sure your commits message well written, like this

- `feature(<context>): <tell what feature you create>`
- `feature-fix(<context>): <what fixes>`
- `refactor(<context>): <what you refactor>`
- `test(<context>): <what you test>`
- `docs(<context>): <what you thing you docs>`
- `misc(<context>): <explain>`

for example:

- `docs(README): fix typos and some broken grammars.`
- `feature(convert action): only server owner can set rules pos for validate user.`

This measure to make code readable by uniforming commit message.

Make sure you make branch for you case:
- `feature/<context>-<explain shortly>`
- `feature-fix/<context>-<explain shortly>`
- `refactor/<context>-<explain shortly>`
- `test/<context>-<explain shortly>`
- `docs/<context>-<explain shortly>`
- `misc/<context>-<explain shortly>`

Pull request title follow the commit message rule, every pull request will be 
squash then merged for compactness in commit history.

After making pull request, dont forget ask reviewr from maintainers.

## Licensing

All contribution you made will licensed under same as this project, for more detail [Contributing License Agreement on Github](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#6-contributions-under-repository-license).

If there a step that missing or you didn't understand, you can open issue to disccus it.