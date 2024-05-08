## - TODO jump direct to item by:
##  tt 10
##  tt 15
## - TODO modularize the main function
## - DONE build --open functionallity (to open all the matches)
## - DONE Quick fix list
##    file row col errormessage
## - DONE generate ctags for tags autocompletion


import std/[os, strformat, strutils, tables, enumerate,
  terminal, algorithm, terminal, times, sequtils, sets, osproc]
import cligen, sim
import configs, lexer, types, tags, openers


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
    of TStrike:
      result.add ansiStyleCode(styleStrikethrough)
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

    let curFile = 
      try:
        open(path, fmRead)
      except:
        echo "Could not open file: ", path
        continue
    for lineNumber, line in enumerate(curFile.lines()):
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
    curFile.close()

proc genTodaysFileName(): string =
  return now().format("YYYY-MM-dd") & ".md"

proc ctrlc() {.noconv.} =
  echo ""
  quit()

var matchesToOpenLater: HashSet[string]

proc main(basePath = config.basePath, absolutePath = false, showAll = false,
    quiet = false, clist = false, doingOnly = false, newFile = false,
    tags = false, tagsFiles = false, tagOpen = "", grep = "", open = false, ctags = false) =
  ## `basePath` is the path which is searched
  ## when `absolutePath` is true print the whole pat
  ## when `json` is true print the output as json, the user is not asked then.
  ## when `quiet` is true, do not ask for the file
  setControlCHook(ctrlc)

  block specials:
    ## Here all the special commands are handled

    if config.preCommand != "":
      discard execCmdEx(config.preCommand, workingDir = basePath)

    if ctags:
      let tags = populateTags()
      echo tags.generateCtags()
      quit()

    if config.ctagsAutogenerate:
      let tags = populateTags()
      let newContent = tags.generateCtags
      let oldContent = readFile(config.ctagsFilePath)
      if newContent != oldContent:
        # only rewrite if changed
        let tagsFile = open(config.ctagsFilePath, fmWrite)
        tagsFile.write(newContent)
        tagsFile.close()

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


  block normal:
    ## Here the normal operations are handled, display the TODOs
    var tab: Table[int, Match]
    let isatty = isatty(stdout)
    var idx = 1
    for match in find(basePath.absolutePath(), config.matchers):
      var style = ""
      
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

        if open:
          matchesToOpenLater.incl(match.path)
        else:
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

          block writeToTerminal:
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
    
    if open:
      var se: seq[string] = @[]
      for path in matchesToOpenLater:
        se.add path.quoteShell() 
      echo se.join(" ")
    else:
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
  
