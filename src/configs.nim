import sim, os
type
  Config* = object
    basePath*: string 
    matchers*: seq[string]
    openFileAtLine*: string
    openFile*: string
    ctagsAutogenerate*: bool
    ctagsFilePath*: string
    preCommand*: string
    asyncPreCommand*: string
    dateMatcherShort*: string
    dateMatcherLong*: string


# global config object
let config* = loadObject[Config](getAppDir() / "config.ini", false)

# basic tests if config is valid
if config.matchers.len != 4:
  raise newException(ValueError,
    "config.matchers should be 4 eg: \"TODO,DOING,DONE,DISCARD\" currently its:" & $config.matchers)

when isMainModule:
  echo loadObject[Config](getAppDir() / "config.ini", false)
