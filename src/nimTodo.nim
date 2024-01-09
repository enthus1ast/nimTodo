import os, strformat, strutils, tables, std/enumerate, terminal, cligen, algorithm, terminal
import lexer

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

proc render(tokens: seq[Token], style: string): string =
  for token in tokens:
    case token.kind
    of TStr:
      result.add style
      result.add token.data
    of TQuestion:
      result.add ansiForegroundColorCode(fgBlue)
      result.add ansiStyleCode(styleBright)
      result.add token.data
      result.add ansiResetCode
    of TExclamation:
      result.add ansiForegroundColorCode(fgRed)
      result.add ansiStyleCode(styleBlink)
      result.add ansiStyleCode(styleBright)
      result.add token.data
      result.add ansiResetCode
    of TStar:
      result.add ansiStyleCode(styleItalic)
      result.add ansiStyleCode(styleBright)
      result.add token.data
      result.add ansiResetCode

proc toStr(match: Match, style: string, color = true): string =
  if color:
    var tokens = parse(match.line)
    return fmt"{match.path}: {tokens.render(style)}"
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


proc main(basePath = basePath, absolutePath = false, showDone = false, quiet = false, clist = false, doingOnly = false) =
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
      if doingOnly and match.matcher != "DOING": continue # skip everything that is not DOING
      if clist:
        echo fmt"{printMatch.path}:{printMatch.lineNumber}:{printMatch.columnNumber}:{printMatch.line}"
      else:
        echo fmt"{style}{idx:>3}: {printMatch.toStr(style, isatty)} :: {idx}"

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
  dispatch(main, 
    help={
      "absolutePath": "Prints the whole path to the file",
      "showDone": "Also print `DONE` entries",
      "clist": "Prints entries in the vim `quick fix list` format",
      "quiet": "Just print, do not ask the user",

    },
    short={
      "absolutePath": 'p',
      "showDone": 'a'
    }
  )
  
