{.push raises: [].}
import times, parseutils, options, strutils, tables, hashes
import lexer, configs

type 
  Calendar = object
    dates: Table[Datetime, seq[Token]]

proc hash*(datetime: Datetime): Hash =
  hash($datetime)

# proc newCalendar(): Calendar =
#   result = Calendar()
#   result.dates = @[]

proc getDateToken(tokens: seq[Token]): Token {.raises: ValueError.} =
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

proc add(cal: var Calendar, tokens: seq[Token]) =
  ## adds a new entry to the calendar
  let tdate = 
    try:
      tokens.getDateToken()
    except:
      echo getCurrentExceptionMsg()
      return
  var date: Datetime
  if not tdate.data.parseDateFromSoup(date):
    echo "Could not parse date from: ", tdate
    return
  cal.dates[date] = tokens

proc add*(cal: var Calendar, line: string) =
  let tokens = line.parse()
  cal.add(tokens)

proc getTodaysTasks*(cal: Calendar): seq[tuple[date: Datetime, tokens: Tokens]] =
  let curDate = now()
  for date, tokens in cal.dates:
    if date.format("yyyy-MM-dd") == curDate.format("yyyy-MM-dd"):
      result.add (date, tokens)

proc getUpcompingTasks*(cal: Calendar): seq[tuple[date: Datetime, tokens: Tokens]] =
  let curDate = now()
  for date, tokens in cal.dates:
    if date > curDate:
      result.add (date, tokens)

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
