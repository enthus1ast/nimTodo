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
    calendarEnabled*: bool
    dateMatcherShort*: string
    dateMatcherLong*: string
    hideUpcomingMoreThanDays*: int
    extentionsToOpen*: seq[string]


proc getConfigPath(): string = 
  ## looks for a config based on the below search order and returns the path to it
  # Config search order:
  let configSearchOrder = @[
    getAppDir() / "config.ini",     # 1. right next to the executable
    "~/.config/nimTodo/config.ini".expandTilde(),   # 2. in the user dirs config
    "/etc/nimTodo/config.ini"        # 3. in the global config
  ]
  for possibleConfigPath in configSearchOrder:
    if possibleConfigPath.fileExists():
      # echo "# Use config: ", possibleConfigPath
      return possibleConfigPath

var configPath: string = getConfigPath()
let config* = loadObject[Config](configPath, false) # global config object

# basic tests if config is valid
if config.matchers.len != 4:
  raise newException(ValueError,
    "config.matchers should be 4 eg: \"TODO,DOING,DONE,DISCARD\" currently its:" & $config.matchers)

when isMainModule:
  echo loadObject[Config](getAppDir() / "config.ini", false)
