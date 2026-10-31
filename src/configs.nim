import sim, os, strutils

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

const defaultConfig*: string = staticRead("config.default.ini")

proc generateDefaultConfig(): string =
  ## Write the default config to ~/.config/nimTodo/config.ini
  ## and return its path. Creates parent directory if needed.
  let dir = "~/.config/nimTodo".expandTilde()
  if not dirExists(dir):
    createDir(dir)
  let path = dir / "config.ini"
  writeFile(path, defaultConfig)
  echo "# Generated default config at: ", path
  return path

proc getConfigPath(): string = 
  ## Looks for a config based on the search order and returns the path to it.
  ## If no existing config is found, generates a default config and returns its path.
  # Config search order:
  let configSearchOrder = @[
    getAppDir() / "config.ini",             # 1. right next to the executable
    "~/.config/nimTodo/config.ini".expandTilde(),  # 2. in the user dirs config
    "/etc/nimTodo/config.ini"                # 3. in the global config
  ]
  for possibleConfigPath in configSearchOrder:
    if possibleConfigPath.fileExists():
      return possibleConfigPath

  # No config found anywhere — generate default
  return generateDefaultConfig()

var configPath: string = getConfigPath()
let config*: Config = loadObject[Config](configPath, false) # global config object

# basic tests if config is valid
if config.matchers.len != 4:
  raise newException(ValueError,
    "config.matchers should be 4 eg: \"TODO,DOING,DONE,DISCARD\" currently its:" & $config.matchers)

when isMainModule:
  echo loadObject[Config](getAppDir() / "config.ini", false)
