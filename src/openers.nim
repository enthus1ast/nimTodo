import strutils, os, configs, sequtils

proc openFile*(path: string, line = 0) =
  let cmd = 
    if line == 0:
      config.openFile % ["path", path]
    else:
      config.openFileAtLine % [
        "path", path,
        "line", $line
      ]
  discard execShellCmd(cmd)

proc openFiles*(paths: seq[string]) =
  let params = paths.mapIt(it.quoteShell()).join(" ")
  openFile(params)

## TODO create an overload that can also jump to the line
# proc openFiles*(paths: seq[(string, int)]) =
#   discard

