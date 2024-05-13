import times, parseutils, options, strutils

# proc parseDateFromSoup(str: string): Option[Datetime] =
proc parseDateFromSoup(str: string, date: var Datetime): bool =
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
      date = parse(dateStr, "yyyy'.'MM'.'dd'__'hh:mm:ss")
      return true
    except:
      discard

    try:
      date = parse(dateStr, "yyyy'.'MM'.'dd")
      return true 
    except:
      discard


  # var dt = parse("@2024.05.13__13:38:34", "yyyy'.'MM'.'dd'__'hh:mm:ss")
  # dt = parse("2024.05.13", "yyyy'.'MM'.'dd")
  # echo dt
  # # echo dt.format("yyyy-MM-dd")

when isMainModule:
  import unittest
  suite "calendar":
    var date: Datetime
    check true == parseDateFromSoup("asdfa foo@baa.de wdsf @2024.05.13__13:38:34  ajskdfljasdkfj asdf", date)
    check true == parseDateFromSoup("asdfa foo@baa.de wdsf @2254.de  @2024.05.13__13:38:34\tajskdfljasdkfj asdf", date)
    check true == parseDateFromSoup("asdfa foo@baa.de wdsf @2254.de  @2024.05.13\tajskdfljasdkfj asdf", date)
    check false == parseDateFromSoup("adsf", date)
    # "2024.05.13__13:38:34"
    # "2024.05.13"
