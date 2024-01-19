import sim, os
type
  Config* = object
    basePath*: string 
    matchers*: seq[string]

let config* = loadObject[Config](getAppDir() / "config.ini", false)
if config.matchers.len != 3:
  raise newException(ValueError,
    "config.matchers should be 3 eg: \"TODO,DOING,DONE\" currently its:" & $config.matchers)

when isMainModule:
  echo loadObject[Config](getAppDir() / "config.ini", false)
