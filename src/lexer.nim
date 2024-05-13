import strutils, parseutils, times

type
  TokenKind* = enum
    TStr, TQuestion, TExclamation, TStar, TBacktick, TQuotation, TTag, TStrike, TDate
  Token* = object
    kind*: TokenKind
    data*: string
    col*: int

const 
  tagChars =  Digits + Letters 

proc parse*(str: string): seq[Token] =
  var pos = 0
  var data = ""
  while pos < str.len:
    let ch = str[pos]
    if ch == '!':
      pos += str.parseWhile(data, {'!'}, pos)
      result.add Token(kind: TExclamation, data: data, col: pos)
    elif ch == '?':
      pos += str.parseWhile(data, {'?'}, pos)
      result.add Token(kind: TQuestion, data: data, col: pos)
    elif ch == '*':
      pos.inc
      pos += str.parseUntil(data, {'*'}, pos)
      result.add Token(kind: TStar, data: "*" & data & "*", col: pos)
      pos.inc
    elif ch == '`':
      pos.inc
      pos += str.parseUntil(data, {'`'}, pos)
      result.add Token(kind: TBacktick, data: "`" & data & "`", col: pos)
      pos.inc
    elif ch == '"':
      pos.inc
      pos += str.parseUntil(data, {'"'}, pos)
      result.add Token(kind: TQuotation, data: "\"" & data & "\"", col: pos)
      pos.inc
    elif ch == '#':
      pos.inc
      pos += str.parseWhile(data, tagChars, pos)
      var kind: TokenKind
      if data.len == 0 or data.startsWith("#"):
        # filter invalid tags
        # only '#' or '##...' tag -> emit as TStr
        kind = TStr
      else:
        kind = TTag
      result.add Token(kind: kind, data: "#" & data, col: pos)
    elif ch == '~':
      pos.inc
      pos += str.parseUntil(data, {'~'}, pos)
      result.add Token(kind: TStrike, data: "~" & data & "~", col: pos)
      pos.inc
    elif ch == '@':
      pos.inc # skip "@"
      let oldPos = pos # store the pos if its not a date, we can go back
      if pos >= str.len:
        break
      if str[pos] notin Digits:
        # not a date
        result.add Token(kind: TStr, data: "@", col: pos)
        continue

      # The following could be a date, extract it and try to parse it
      # TODO currently we parse the date two times, one time to generate
      #   the token, then later for the calendar functionality
      var dateStr = ""
      pos += str.parseUntil(dateStr, Whitespace, pos)
      try:
        var date = parse(dateStr, "yyyy'.'MM'.'dd'__'hh:mm:ss")
        result.add Token(kind: TDate, data: "@" & dateStr, col: pos)
        continue
      except:
        discard
      
      try:
        var date = parse(dateStr, "yyyy'.'MM'.'dd")
        result.add Token(kind: TDate, data: "@" & dateStr, col: pos)
        continue
      except:
        discard
        pos = oldPos # reset to old pos, to try to parse with other parsers
 

    else:
      pos += str.parseUntil(data, {'?', '!', '*', '`', '\"', '#', '~', '@'}, pos)
      result.add Token(kind: TStr, data: data, col: pos)


when isMainModule:
  # let tt = "!!- TODO Buy a new *macbook* for ivan!!!(angebot:   Fwd: CANCOM Angebot 10152018  )!!!?? "
  # let tt = "- DOING *Bremm Lab* Printer funktioniert noch nicht, kein Netzwerk (Kori, Luca) !!GET PORT!!" 
  let tt = "foo `*baa*` baz asdf  \"Some stuff\" asdf #foo #baa ~striked~ @a asd @123 @2024.05.13__16:34:38"
  for tok in parse(tt):
    echo tok

