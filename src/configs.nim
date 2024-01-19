type
  Config* = object
    basePath*: string 
    matchers*: seq[string]


when isMainModule:
  import sim, os
  echo loadObject[Config](getAppDir() / "config.ini", false)
