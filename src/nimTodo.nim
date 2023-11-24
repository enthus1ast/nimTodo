import os, osproc, json, strformat, strutils, tables, std/enumerate
# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

const basePath = "/home/david/projects/obsidian/diary"
const matchers = ["DOING", "TODO"]


type 
  Match = object
    lineNumber: int
    line: string
    path: string

proc `$`(match: Match): string =
  return fmt"{match.path}: {match.line}"

iterator find(basePath: string, matchers: openarray[string]): Match =
  for path in walkDirRec(basePath):
    for lineNumber, line in enumerate(path.lines()):
      for matcher in matchers:
        if line.contains(matcher):
          yield Match(lineNumber: lineNumber, line: line.strip(), path: path)

var tab: Table[int, Match]

var idx = 1
for match in find(basePath, matchers):
  echo fmt"{idx}: {match} :: {idx}"
  tab[idx] = match
  idx.inc

# var idx = 1
# for matcher in matchers:
#   let rg = fmt"rg '{matcher}' '{basePath}' ---json"
#   let outp = execCmdEx(rg, {poEvalCommand}).output
#   for line in outp.splitlines():
#     ## This is jsonl
#     if line.isEmptyOrWhitespace(): continue
#     let js = line.parseJson()
#     if js["type"].getStr() == "match":
#       var info: Info
#       info.path = js["data"]["path"]["text"].getStr()
#       info.text = js["data"]["lines"]["text"].getStr().strip()
#       try:
#         info.lineNumber = js["data"]["line_number"].getInt()
#       except:
#         info.lineNumber = 0
#       tab[idx] = info
#       echo fmt"{idx}: {info} :: {idx}"
#       idx.inc

stdout.write("Choose: ")
var choiceStr = stdin.readLine().strip()
try:
  var choiceInt = parseInt(choiceStr)
  let info = tab[choiceInt]
  let cmd = fmt"nvim '{info.path}' +:{info.lineNumber}"
  discard execShellCmd(cmd)
except:
  discard

