import os, strformat, strutils, tables, std/enumerate, terminal, cligen, algorithm, terminal
# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

## Quick fix list
# file row col errormessage

const basePath = "/home/david/projects/obsidian/diary"
const matchers = ["DOING", "TODO", "DONE"]


type 
  Match = object
    lineNumber: int
    columnNumber: int
    line: string
    path: string
    matcher: string


# type
#   TokenKind = enum
#     TStr, TQuestion, TExclamation
#   Token = object
#     kind: TokenKind
#     data: str
# proc parseStr() =
#   discard
# proc parseImportant() =
#   discard
# proc parseQuestion() =
#   discard

proc colorParser(str: string): string =
  for ch in str:
    if ch == '!':
      result.add ansiForegroundColorCode(fgRed)
      result.add ansiStyleCode(styleBlink)
      result.add ansiStyleCode(styleBright)
      result.add ch
      result.add ansiResetCode
      result.add ansiForegroundColorCode(fgDefault)
    # elif ch == '?':
    #   result.add ansiForegroundColorCode(fgBlue)
    #   # result.add ansiStyleCode(styleBlink)
    #   # result.add ansiStyleCode(styleBright)
    #   result.add ch
    #   # result.add ansiResetCode
    #   result.add ansiForegroundColorCode(fgDefault)
    else:
      result.add ch


# proc `$`(match: Match): string =
proc toStr(match: Match, color = true): string =
  if color:
    return fmt"{match.path}: {match.line.colorParser()}"
  else:
    return fmt"{match.path}: {match.line}"


iterator find(basePath: string, matchers: openarray[string]): Match =
  var paths: seq[string] = @[]
  for path in walkDirRec(basePath):
    paths.add path
  paths.sort()

  for path in paths:
    for lineNumber, line in enumerate(path.lines()):
      for matcher in matchers:
        let columnNumber = line.find(matcher)
        if columnNumber >= 0:
          yield Match(
            lineNumber: lineNumber + 1,
            columnNumber: columnNumber + 1,
            line: line.strip(),
            path: path,
            matcher: matcher
          )

proc ctrlc() {.noconv.} =
  echo ""
  quit()

proc main(basePath = basePath, absolutePath = false, showDone = false, quiet = false, clist = false) =
  ## `basePath` is the path which is searched
  ## when `absolutePath` is true print the whole pat
  ## when `json` is true print the output as json, the user is not asked then.
  ## when `quiet` is true, do not ask for the file
  setControlCHook(ctrlc)
  var tab: Table[int, Match]
  let isatty = isatty(stdout)
  var idx = 1
  for match in find(basePath.absolutePath(), matchers):
    var style = ""
    
    if isatty:
      # Only show colors when on a tty (not eg in vim)
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


      if clist:
        echo fmt"{printMatch.path}:{printMatch.lineNumber}:{printMatch.columnNumber}:{printMatch.line}"
      else:
        echo fmt"{style}{idx:>3}: {printMatch.toStr(isatty)} :: {idx}"

      tab[idx] = match
      idx.inc

  
  if isatty:
    resetAttributes()

  if quiet == false and isatty:
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
  
