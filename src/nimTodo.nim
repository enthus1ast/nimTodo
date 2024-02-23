## - TODO jump direct to item by:
##  tt 10
##  tt 15
## - TODO modularize the main function
## - TODO build --open functionallity (to open all the matches)

import std/[os, strformat, strutils, tables, enumerate,
  terminal, algorithm, terminal, times, sequtils]
import cligen, sim
import configs, lexer, types, tags, openers

## Quick fix list
# file row col errormessage

template TODO(matchers: seq[string]): string = matchers[0]
template DOING(matchers: seq[string]): string = matchers[1]
template DONE(matchers: seq[string]): string = matchers[2]
template DISCARD(matchers: seq[string]): string = matchers[3]

proc render(tokens: seq[Token], style: string): string =
  for token in tokens:
    case token.kind
    of TStr, TBacktick:
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
      result.add ansiStyleCode(styleBright)
      result.add token.data
      result.add ansiResetCode
    of TQuotation:
      result.add ansiStyleCode(styleItalic)
      result.add token.data
      result.add ansiResetCode
    of TTag:
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

proc genTodaysFileName(): string =
  return now().format("YYYY-MM-dd") & ".md"

proc ctrlc() {.noconv.} =
  echo ""
  quit()


proc main(basePath = config.basePath, absolutePath = false, showAll = false,
    quiet = false, clist = false, doingOnly = false, newFile = false,
    tags = false, tagsFiles = false, tagOpen = "", grep = "", open = false) =
  ## `basePath` is the path which is searched
  ## when `absolutePath` is true print the whole pat
  ## when `json` is true print the output as json, the user is not asked then.
  ## when `quiet` is true, do not ask for the file
  setControlCHook(ctrlc)

  block specials:
    ## Here all the special commands are handled

    # Open all files that contain the given tag
    if tagOpen.len > 0:
      let tags = populateTags()
      tags.openAllTagFiles(tag = tagOpen)
      quit()

    # Handle "tags" this just prints all the tags
    if tags:
      let tags = populateTags()
      tags.printPathAndTags()
      quit()

    # Handle "tags" this just prints all the tags
    if tagsFiles:
      let tags = populateTags()
      tags.printTagAndFiles()
      quit()

    # Handle "newFile" which is special since it directly opens todays file
    if newFile:
      try:
        let path = basePath / genTodaysFileName() # "diary" must be configurable
        openFile(path)
        quit()
      except:
        discard

  var validMatches: seq[Match]
  
  block normal:
    ## Here the normal operations are handled, display the TODOs
    var tab: Table[int, Match]
    let isatty = isatty(stdout)
    var idx = 1
    for match in find(config.basePath.absolutePath(), config.matchers):
      var style = ""
      
      if isatty:
        # Only show colors when on a tty (not eg in vim)
        if match.matcher == config.matchers.DOING:
          style = ansiForegroundColorCode(fgYellow)
        elif match.matcher == config.matchers.DISCARD:
          style &= ansiForegroundColorCode(fgWhite)
          style &= ansiStyleCode(styleDim)
          style &= ansiStyleCode(styleStrikethrough)
        elif showAll and match.matcher == config.matchers.DONE:
          style = ansiForegroundColorCode(fgGreen)
        else:
          resetAttributes()


      var shouldPrint = false
      if showAll and match.matcher == config.matchers.DONE:
        shouldPrint = true
      elif showAll and match.matcher == config.matchers.DISCARD:
        shouldPrint = true
      elif match.matcher in @[config.matchers.TODO, config.matchers.DOING]:
        shouldprint = true

      if shouldPrint and grep != "":
        if match.line.toLower().contains(grep.toLower()):
          shouldPrint = true
        else:
          shouldPrint = false
      
      if shouldPrint:
        validMatches.add match


      # if (showAll and match.matcher == config.matchers.DONE) or match.matcher != config.matchers.DONE:
      if shouldPrint:
        var printMatch = match
        if absolutePath == false:
          printMatch.path = match.path.extractFilename()
        if doingOnly and match.matcher != config.matchers.DOING: continue # skip everything that is not DOING
        if clist:
          echo fmt"{printMatch.path}:{printMatch.lineNumber}:{printMatch.columnNumber}:{printMatch.line}"
        else:
          echo fmt"{style}{idx:>3}: {printMatch.toStr(style, isatty)} :: {idx}{ansiResetCode}"

        tab[idx] = match
        idx.inc
    

    # if open:
    #   ## When open is true, do not ask but open all matches
      

    if isatty:
      resetAttributes()

    if quiet == false and isatty:
      stdout.write("Choose: ")
      var choiceStr = stdin.readLine().strip()
      try:
        var choiceInt = parseInt(choiceStr)
        let info = tab[choiceInt]
        openFile(info.path, info.lineNumber)
      except:
        discard


when isMainModule:

  # ## Special jump direct to xx item
  # if paramCount() == 2:
  

  dispatch(main,
    help = {
      "absolutePath": "Prints the whole path to the file",
      "showAll": "Also print `DONE` and `DISCARD` entries",
      "clist": "Prints entries in the vim `quick fix list` format",
      "quiet": "Just print, do not ask the user",
      "newFile": "Opens the todays diary file",
      "grep": "Filters entries by the given text, can be combined with `-a' `-d` etc.",
      "tags": "prints all files with their tags",
      "tagsFiles": "prints all tags grouped together with their file",
      "open": "Opens all the files found in the query, can be combined with `-a` `-d` `-g` etc."

    },
    short = {
      "absolutePath": 'p',
      "showAll": 'a',
      "tagsFiles": 'f'
    }
  )
  
