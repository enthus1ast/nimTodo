##
## The tag handling code
##
import std/[os, strformat, strutils, tables, enumerate,
  algorithm, sequtils]
import lexer, configs, types, openers

proc normalizeTag*(str: Tag): string =
  return str.tolower()

proc sortedKeys(tags: auto): seq[string] =
  result = toSeq(tags.keys())
  result.sort()

iterator findTags*(basePath: string, matchers: openarray[string]): Match =
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
        yield Match(
          lineNumber: lineNumber + 1,
          columnNumber: token.col,
          line: token.data,
          path: path,
          matcher: "TAG" # should this be the Content/data of the Token?
        )

proc populateTags*(): Tags =
  ## Finds all the tags, stores it in tags returns tag table
  for match in findTags(config.basePath.absolutePath(), config.matchers):
    if not result.contains(match.path):
      result[match.path] = @[]
    result[match.path].add match

proc printPathAndTags*(tags: Tags) =
  ## Print all the tags from the files.
  ## So: /path/to/file.md #Tag1 #Tag2
  for path in tags.sortedKeys:
    let matches = tags[path]
    echo path, " ", matches.mapIt(it.line.toLower()).join(" ")

proc printTagAndFiles*(tags: Tags) =
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

  # get longest tag 
  var maxlen = 0
  for tag in tagFile.keys:
    maxlen = max(tag.len, maxlen)

  for tag in tagFile.sortedKeys():
    let files = tagFile[tag]
    # echo ""
    for file in files.sorted():
      echo alignLeft(tag, maxlen) & "\t" & file
    echo ""

proc generateCtags*(tags: Tags): string =
  for path, matches in tags:
    for match in matches:
      let tag = match.line.strip(true, false, {'#'})
      let path = match.path.splitPath.tail
      result.add &"{tag.normalizeTag()}\t{path}\t{match.lineNumber}\n"
  

proc `===`*(aa, bb: Tag): bool =
  ## Compare tags smart
  aa.strip(true, false, chars = {'#'}).toLower() == bb.strip(true, false, chars = {'#'}).toLower()

proc filesWithTag*(tags: Tags, tag: Tag): seq[Path] =
  ## returns a seq with all files containing the given tag
  for path, matches in tags.pairs:
    if matches.filterIt(it.line.Tag === tag).len == 0:
      result.add path

proc openAllTagFiles*(tags: Tags, tag: Tag) =
  ## Opens all the files of the given tag in nvim 
  let files = tags.filesWithTag(tag)
  openFiles(files)

  


