import strutils, parseutils

type
  TokenKind* = enum
    TStr, TQuestion, TExclamation, TStar, TBacktick, TQuotation, TTag
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
    else:
      pos += str.parseUntil(data, {'?', '!', '*', '`', '\"', '#'}, pos)
      result.add Token(kind: TStr, data: data, col: pos)


when isMainModule:
  # let tt = "!!- TODO Buy a new *macbook* for ivan!!!(angebot:   Fwd: CANCOM Angebot 10152018  )!!!?? "
  # let tt = "- DOING *Bremm Lab* Printer funktioniert noch nicht, kein Netzwerk (Kori, Luca) !!GET PORT!!" 
  let tt = "foo `*baa*` baz asdf  \"Some stuff\" asdf #foo #baa"
  for tok in parse(tt):
    echo tok

