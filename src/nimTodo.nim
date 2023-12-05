import os, strformat, strutils, tables, std/enumerate, terminal, cligen, algorithm
# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.


const basePath = "/home/david/projects/obsidian/diary"
const matchers = ["DOING", "TODO", "DONE"]


type 
  Match = object
    lineNumber: int
    line: string
    path: string
    matcher: string


proc `$`(match: Match): string =
  return fmt"{match.path}: {match.line}"


iterator find(basePath: string, matchers: openarray[string]): Match =
  var paths: seq[string] = @[]
  for path in walkDirRec(basePath):
    paths.add path
  paths.sort()

  for path in paths:
    for lineNumber, line in enumerate(path.lines()):
      for matcher in matchers:
        if line.contains(matcher):
          yield Match(lineNumber: lineNumber + 1, line: line.strip(), path: path, matcher: matcher)


proc main(basePath = basePath, absolutePath = false, showDone = false, quiet = false) =
  ## `basePath` is the path which is searched
  ## when `absolutePath` is true print the whole pat
  ## when `json` is true print the output as json, the user is not asked then.
  ## when `quiet` is true, do not ask for the file
  var tab: Table[int, Match]

  var idx = 1
  for match in find(basePath.absolutePath(), matchers):
    var style = ""
    if match.matcher == "DOING":
      style = ansiForegroundColorCode(fgYellow)
    elif showDone and match.matcher == "DONE":
      style = ansiForegroundColorCode(fgGreen)
    else:
      resetAttributes()

    if (showDone and match.matcher == "DONE") or match.matcher != "DONE":
      var printMatch = match
      if absolutePath == false:
        printMatch.path = match.path.extractFilename()
      echo fmt"{style}{idx}: {printMatch} :: {idx}"
      tab[idx] = match
      idx.inc

  resetAttributes()

  if quiet == false:
    stdout.write("Choose: ")
    var choiceStr = stdin.readLine().strip()
    try:
      var choiceInt = parseInt(choiceStr)
      let info = tab[choiceInt]
      let cmd = fmt"nvim '{info.path}' +:{info.lineNumber}"
      discard execShellCmd(cmd)
    except:
      discard

when isMainModule:
  dispatch(main)
  
