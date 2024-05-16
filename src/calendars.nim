{.push raises: [].}
import times, parseutils, options, strutils, tables, hashes, algorithm
import lexer, configs, types

type 
  Calendar* = object
    dates: seq[tuple[date: Datetime, tokens: seq[Token], idx: int]]
  CalInfo* = tuple[date: Datetime, tokens: Tokens, idx: int]

proc hash*(datetime: Datetime): Hash =
  hash($datetime)

# proc newCalendar(): Calendar =
#   result = Calendar()
#   result.dates = @[]


proc getDateToken*(tokens: seq[Token]): Token {.raises: ValueError.} =
  ## returns the first TDate token
  for token in tokens:
    if token.kind == TDate:
      return token
  raise newException(ValueError, "no TDate token")


proc parseDateFromSoup*(str: string, date: var Datetime): bool =
  ## try to parse a date string, from a soup of text
  ## 2024.05.13__13:38:34
  ## 2024.05.13
  var pos = 0
  while pos < str.len:
    pos += skipUntil(str, '@', pos)
    pos.inc # skip "@"
    if pos >= str.len:
      break
    if str[pos] notin Digits:
      continue
    # The following could be a date, extract it and try to parse it
    var dateStr = ""
    pos += str.parseUntil(dateStr, Whitespace, pos)
    try:
      date = parse(dateStr, config.dateMatcherLong)
      return true
    except:
      discard

    try:
      date = parse(dateStr, config.dateMatcherShort)
      return true 
    except:
      discard

proc parseDateFromSoup*(str: string): Datetime =
  discard str.parseDateFromSoup(result)

proc add*(cal: var Calendar, tokens: seq[Token], idx: int = 0) =
  ## adds a new entry to the calendar
  let tdate = 
    try:
      tokens.getDateToken()
    except:
      return
  var date: Datetime
  if not tdate.data.parseDateFromSoup(date):
    echo "Could not parse date from: ", tdate
    return
  cal.dates.add( (date, tokens, idx) )

proc add*(cal: var Calendar, line: string, idx: int = 0) =
  let tokens = line.parse()
  cal.add(tokens, idx)

proc dateCmp(aa, bb: CalInfo): int =
  return cmp(aa.date, bb.date)

proc isToday(date, curDate: Datetime): bool =
  date.format("yyyy-MM-dd") == curDate.format("yyyy-MM-dd")

proc getMissedTasks*(cal: Calendar): seq[CalInfo] =
  let curDate = now()
  for (date, tokens, idx) in cal.dates:
    if date < curDate and not isToday(date, curDate):
      result.add (date, tokens, idx)
  result.sort(dateCmp, Ascending)
  

proc getTodaysTasks*(cal: Calendar): seq[CalInfo] =
  let curDate = now()
  for (date, tokens, idx) in cal.dates:
    if isToday(date, curDate):
      result.add (date, tokens, idx)
  result.sort(dateCmp, Ascending)

proc getUpcompingTasks*(cal: Calendar): seq[CalInfo] =
  let curDate = now()
  for (date, tokens, idx) in cal.dates:
    if date > curDate and not isToday(date, curDate):
      result.add (date, tokens, idx)
  result.sort(dateCmp, Ascending)

when isMainModule:
  import unittest
  suite "calendar":

    var cal: Calendar
    cal.add("Chun kommt am @2024.05.17")

    echo cal.getUpcompingTasks()

    var date: Datetime
    check true == parseDateFromSoup("asdfa foo@baa.de wdsf @2024.05.13__13:38:34  ajskdfljasdkfj asdf", date)
    check true == parseDateFromSoup("asdfa foo@baa.de wdsf @2254.de  @2024.05.13__13:38:34\tajskdfljasdkfj asdf", date)
    check true == parseDateFromSoup("asdfa foo@baa.de wdsf @2254.de  @2024.05.13\tajskdfljasdkfj asdf", date)
    check false == parseDateFromSoup("adsf", date)
    # "2024.05.13__13:38:34"
    # "2024.05.13"
