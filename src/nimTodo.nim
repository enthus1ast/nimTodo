## - TODO jump direct to item by:
##  tt 10
##  tt 15
## - TODO modularize the main function
## - DONE build --open functionallity (to open all the matches)
## - DONE Quick fix list
##    file row col errormessage
## - DONE generate ctags for tags autocompletion
# {.push raises: [].}

import std/[os, strformat, strutils, tables, enumerate,
  terminal, algorithm, times, sets, osproc, sequtils]
import cligen, sim
import configs, lexer, types, tags, openers, calendars


template TODO(matchers: seq[string]): string = matchers[0]
template DOING(matchers: seq[string]): string = matchers[1]
template DONE(matchers: seq[string]): string = matchers[2]
template DISCARD(matchers: seq[string]): string = matchers[3]

iterator linesBuffer(fh: File): string {.raises: IoError.} =
  ## if the file is small enough, we read it in completely
  ## otherwise, this behaves like `lines()`
  if fh.getFileSize < 1_000_000:  # smaller than 1mb
    let buf = fh.readAll()
    for line in buf.splitLines():
      yield line
  else:
    for line in fh.lines():
      yield line

proc render(tokens: seq[Token], style: string = ""): string {.raises: ValueError.} =
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
    of TDate:
      result.add ansiForegroundColorCode(fgMagenta)
      result.add token.data
      result.add ansiStyleCode(styleBright)
      let (date, calKind) = token.data.parseDateFromSoup() 
      let dur = date - now() 
      let parts = dur.toParts()
      if parts[Days] < 1:
        result.add ansiForegroundColorCode(fgRed)
      if parts[Days] <= 0 and parts[Hours] <= 0 and parts[Minutes] < 15:
        result.add ansiStyleCode(styleBlink)
      if parts[Weeks].abs > 0:
        result.add &"  in {parts[Weeks]}W:{parts[Days]}D:{parts[Hours]}H:{parts[Minutes]}M  "
      else:
        result.add &"  in {parts[Days]}D:{parts[Hours]}H:{parts[Minutes]}M  "
      result.add ansiResetCode
    of TBirthday:
      result.add ansiStyleCode(styleUnderscore)
      result.add token.data
      result.add ansiResetCode
      

proc toStr(match: Match, style: string, color = true): string =
  try:
    if color:
      # var tokens = parse(match.line)
      return fmt"{match.path}: {match.tokens.render(style)}"
    else:
      return fmt"{match.path}: {match.line}"
  except:
    echo "Could stringify match: ", match

iterator find(basePath: string, matchers: openarray[string], extentionsToOpen: seq[string]): Match =
  var paths: seq[string] = @[]
  try:
    for path in walkDirRec(basePath):
      for ext in extentionsToOpen:
        if path.endsWith(ext):
          paths.add path
  except:
    echo "Could not walk dir: ", basePath
  paths.sort()

  for path in paths:

    let curFile = 
      try:
        open(path, fmRead)
      except:
        echo "Could not open file: ", path
        continue
    for lineNumber, line in enumerate(curFile.linesBuffer()):
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
  ## Graceful exit on ctrl-c
  echo ""
  quit()

var matchesToOpenLater: HashSet[string]


proc genStyle(match: Match, config: Config, showAll: bool): string =
  if match.matcher == config.matchers.DOING:
    result = ansiForegroundColorCode(fgYellow)
  elif match.matcher == config.matchers.DISCARD:
    result &= ansiForegroundColorCode(fgWhite)
    result &= ansiStyleCode(styleDim)
    result &= ansiStyleCode(styleStrikethrough)
  elif showAll and match.matcher == config.matchers.DONE:
    result = ansiForegroundColorCode(fgGreen)
  else:
    resetAttributes() 

proc main(basePathRaw = config.basePath, absolutePath = false, showAll = false,
    quiet = false, clist = false, doingOnly = false, newFile = false,
    tags = false, tagsFiles = false, tagOpen = "", grep = "", open = false, ctags = false, upcomingTasks = false) =
  ## `basePath` is the path which is searched
  ## when `absolutePath` is true print the whole pat
  ## when `json` is true print the output as json, the user is not asked then.
  ## when `quiet` is true, do not ask for the file
  setControlCHook(ctrlc)
  
  let basePath =  
    if basePathRaw.isAbsolute: 
      basePathRaw
    else:
      basePathRaw.absolutePath()

  block specials:
    ## Here all the special commands are handled

    if config.preCommand != "":
      discard execCmdEx(config.preCommand, workingDir = basePath)

    if config.asyncPreCommand != "":
      discard startProcess(
        config.asyncPreCommand, 
        workingDir = basePath, 
        options = {poEvalCommand}
      )

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
    var calendar: Calendar
    var tab: Table[int, Match]
    let isatty = isatty(stdout)
    var idx = 1
    for match in find(basePath.absolutePath(), config.matchers, config.extentionsToOpen):
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

          let tokens = parse(match.line)
          if config.calendarEnabled:
            try:
              calendar.add(match, tokens, idx)
            except:
              discard # has no tdate
            

          if isatty:
            # Only show colors when on a tty (not eg in vim)
            style = genStyle(match, config, showAll)

          block writeToTerminal:
            var printMatch = match
            printMatch.tokens = tokens
            if absolutePath == false:
              printMatch.path = match.path.extractFilename()
            if doingOnly and match.matcher != config.matchers.DOING: continue # skip everything that is not DOING
            if clist:
              echo fmt"{printMatch.path}:{printMatch.lineNumber}:{printMatch.columnNumber}:{printMatch.line}"
            else:
              echo fmt"{style}{idx:>3}: {printMatch.toStr(style, isatty)} :: {idx}{ansiResetCode}"

          tab[idx] = match
          idx.inc


    if upcomingTasks:
      proc renderTasks(tasks: seq[CalInfo], headline: string) = 
        if tasks.len > 0:
          echo &"\n{headline}:"
          echo "============="
          for (date, tokens, idx, match) in tasks:
            let style = genStyle(match, config, true)
            echo fmt"{style}{idx:>3}: {date} {tokens.render(style)} :: {idx}"
      renderTasks(calendar.getMissedTasks(), "Missed Tasks")
      renderTasks(calendar.getTodaysTasks(), "Todays Tasks")
      renderTasks(calendar.getUpcompingTasks(), "Upcoming Tasks")
    
      renderTasks(calendar.getBirthdays(), "Birthdays")


    if open:
      var se: seq[string] = @[]
      for path in matchesToOpenLater:
        se.add path.quoteShell() 
      echo se.join(" ")
    else:
      if isatty:
        resetAttributes()

      if quiet == false and isatty and tab.len > 0:
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
  
