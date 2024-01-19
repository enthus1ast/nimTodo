import std/[os, strformat, strutils, tables, enumerate, terminal, algorithm, terminal, times, sequtils]
import cligen, sim
import configs, lexer



## Quick fix list
# file row col errormessage

let config = loadObject[Config](getAppDir() / "config.ini", false)


type 
  Path = string
  Tag = string
  Match = object
    lineNumber: int
    columnNumber: int
    line: string
    path: Path
    matcher: string
  Tags = Table[Path, seq[Match]] ## for storing and query tags

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

iterator findTags(basePath: string, matchers: openarray[string]): Match =
  ## Walks through the basePath folder and yields tags messages
  ## For this it lexes every line it encounters
  var paths: seq[string] = @[]
  for path in walkDirRec(basePath):
    paths.add path
  paths.sort()
  for path in paths:
    for lineNumber, line in enumerate(lines(path)):
      let tokens = parse(line).filterIt(it.kind == TTag)
      for token in tokens:
        if token.data.len() == 1: continue # filter "#" tags; TODO this should be done in parser
        if token.data[1] == '#': continue # filter "##"... tags; TODO this should be done in parser
        yield Match(
          lineNumber: lineNumber + 1,
          columnNumber: token.col,
          line: token.data,
          path: path,
          matcher: "TAG" # should this be the Content/data of the Token?
        )

proc populateTags(): Tags =
  ## Finds all the tags, stores it in tags returns tag table
  for match in findTags(config.basePath.absolutePath(), config.matchers):
    if not result.contains(match.path):
      result[match.path] = @[]
    result[match.path].add match

proc sortedKeys(tags: auto): seq[string] =
  result = toSeq(tags.keys())
  result.sort()

proc printPathAndTags(tags: Tags) =
  ## Print all the tags from the files.
  ## So: /path/to/file.md #Tag1 #Tag2
  for path in tags.sortedKeys:
    let matches = tags[path]
    echo path, " ", matches.mapIt(it.line).join(" ")

proc normalizeTag(str: string): string =
  return str.tolower()

proc printTagAndFiles(tags: Tags) =
  ## Print all the tags from the files.
  ## So: #Tag1 /path/to/file.md /path/to/file2.md 
  var tagFile: Table[Tag, seq[Path]]
  for path in tags.sortedKeys():
    let matches = tags[path]
    for match in matches:
      let tag = match.line.normalizeTag()
      if not tagFile.contains(tag):
        tagFile[tag] = @[]
      tagFile[tag].add path
  # echo tagFile
  for tag in tagFile.sortedKeys():
    let files = tagFile[tag] 
    echo tag
    for file in files.sorted():
      echo "\t" & file
    echo ""

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

proc main(basePath = config.basePath, absolutePath = false, showDone = false,
    quiet = false, clist = false, doingOnly = false, newFile = false,
    tags = false, tagsFiles = false) =
  ## `basePath` is the path which is searched
  ## when `absolutePath` is true print the whole pat
  ## when `json` is true print the output as json, the user is not asked then.
  ## when `quiet` is true, do not ask for the file
  setControlCHook(ctrlc)

  # # Handle "tags" this just prints all the tags
  if tags:
    let tagsTable = populateTags()
    tagsTable.printPathAndTags()
    quit()
  
  # Handle "tags" this just prints all the tags
  if tagsFiles:
    let tagsTable = populateTags()
    tagsTable.printTagAndFiles()
    quit()

  # Handle "newFile" which is special since it directly opens todays file
  if newFile:
    try:
      let path = basePath / genTodaysFileName() # "diary" must be configurable
      let cmd = fmt"nvim '{path}'"
      discard execShellCmd(cmd)
      quit()
    except:
      discard


  var tab: Table[int, Match]
  let isatty = isatty(stdout)
  var idx = 1
  for match in find(config.basePath.absolutePath(), config.matchers):
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
      "newFile": "Opens the todays diary file"

    },
    short={
      "absolutePath": 'p',
      "showDone": 'a',
      "tagsFiles": 'f'
    }
  )
  
