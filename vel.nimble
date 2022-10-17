# Package

version       = "0.1.0"
author        = "dromtek"
description   = "Discord bot for Dromtek HQ"
license       = "ISC"
srcDir        = "src"
bin           = @["vel"]


# Dependencies

requires "nim >= 1.3.4", "https://github.com/krisppurg/dimscord#head"

when defined(nimdistros):
  import distros
  if detectOs(Debian) or detectOs(Ubuntu):
    foreignDep "libsqlite3-dev"
  else:
    foreignDep "libsqlite3"