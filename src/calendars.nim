{.push raises: [].}
import times, parseutils, options, strutils, tables, hashes, algorithm
import lexer, configs, types

## DOING handle Birthdays
##    

type 
  CalItem* = tuple[match: Match, date: Datetime, tokens: seq[Token], idx: int, calKind: CalKind]
  Calendar* = object
    dates: seq[CalItem]
    # birthdays: seq[CalItem]
  CalInfo* = tuple[date: Datetime, tokens: Tokens, idx: int, match: Match]
  CalKind* = enum
    CalDate,
    CalBirthday

proc hash*(datetime: Datetime): Hash =
  hash($datetime)

proc getDateToken*(tokens: seq[Token]): Token {.raises: ValueError.} =
  ## returns the first TDate token
  for token in tokens:
    if token.kind in {TDate, TBirthday}:
      return token
  raise newException(ValueError, "no TDate token")

proc parseDateFromSoup*(str: string, date: var Datetime, calKind: var CalKind): bool =
  ## try to parse a date string, from a soup of text
  ## 2024.05.13__13:38:34
  ## 2024.05.13
  var pos = 0
  while pos < str.len:
    pos += skipUntil(str, {'@', '+'}, pos)
    if pos >= str.len:
      break
    if str[pos] == '@':
      calKind = CalDate 
    if str[pos] == '+':
      calKind = CalBirthday 
    pos.inc # skip '@' or '+'
    if str[pos] notin Digits:
      continue
    # The following could be a date, extract it and try to parse it
    var dateStr = ""
    # The long date matcher
    pos += str.parseUntil(dateStr, Whitespace, pos)
    try:
      date = parse(dateStr, config.dateMatcherLong)
      return true
    except:
      discard
    # The short date matcher
    try:
      date = parse(dateStr, config.dateMatcherShort)
      return true 
    except:
      discard

proc parseDateFromSoup*(str: string): tuple[date: Datetime, calKind: CalKind] =
  discard str.parseDateFromSoup(result.date, result.calKind)

proc add*(cal: var Calendar, match: Match, tokens: seq[Token], idx: int = 0) =
  ## adds a new entry to the calendar
  let tdate = 
    try:
      tokens.getDateToken()
    except:
      return
  var date: Datetime
  var calKind: CalKind
  if not tdate.data.parseDateFromSoup(date, calKind):
    echo "Could not parse date from: ", tdate
    return
  cal.dates.add( (match, date, tokens, idx, calKind) )

proc dateCmp(aa, bb: CalInfo): int =
  return cmp(aa.date, bb.date)

proc isToday(date, curDate: Datetime): bool =
  date.format("yyyy-MM-dd") == curDate.format("yyyy-MM-dd")

proc isTooFarInTheFuture(date, curDate: Datetime): bool =
  date - curDate > initDuration(days = config.hideUpcomingMoreThanDays)

proc getMissedTasks*(cal: Calendar): seq[CalInfo] =
  let curDate = now()
  for (match, date, tokens, idx, calKind) in cal.dates:
    if date < curDate and not isToday(date, curDate):
      result.add (date, tokens, idx, match)
  result.sort(dateCmp, Ascending)
  
proc getTodaysTasks*(cal: Calendar): seq[CalInfo] =
  let curDate = now()
  for (match, date, tokens, idx, calKind) in cal.dates:
    if isToday(date, curDate):
      result.add (date, tokens, idx, match)
  result.sort(dateCmp, Ascending)

proc getUpcompingTasks*(cal: Calendar): seq[CalInfo] =
  let curDate = now()
  for (match, date, tokens, idx, calKind) in cal.dates:
    if date > curDate and not isToday(date, curDate) and not isTooFarInTheFuture(date, curDate):
      result.add (date, tokens, idx, match)
  result.sort(dateCmp, Ascending)

proc getBirthdays*(cal: Calendar): seq[CalInfo] =
  let curDate = now()
  for (match, date, tokens, idx, calKind) in cal.dates:
    if calKind == CalDate:
      continue
    ## To have a simpler logic, the year of the birthday is changed
    ## to the current year
    var bdate = date
    bdate.year = curDate.year
    if bdate > curDate and not isToday(bdate, curDate) and not isTooFarInTheFuture(bdate, curDate):
      result.add (date, tokens, idx, match)
  result.sort(dateCmp, Ascending)

when isMainModule:
  import unittest
  suite "calendar":

    var cal: Calendar
    # cal.add("Chun kommt am @2024.05.17")
    # cal.add("+1989.01.13 David") # Geburtstag syntax? 

    echo cal.getUpcompingTasks()

    var date: Datetime
    var calKind: CalKind
    check true == parseDateFromSoup("asdfa foo@baa.de wdsf @2024.05.13__13:38:34  ajskdfljasdkfj asdf", date, calKind)
    check true == parseDateFromSoup("asdfa foo@baa.de wdsf @2254.de  @2024.05.13__13:38:34\tajskdfljasdkfj asdf", date, calKind)
    check true == parseDateFromSoup("asdfa foo@baa.de wdsf @2254.de  @2024.05.13\tajskdfljasdkfj asdf", date, calKind)
    check false == parseDateFromSoup("adsf", date, calKind)
    # "2024.05.13__13:38:34"
    # "2024.05.13"
