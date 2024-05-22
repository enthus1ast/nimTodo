import tables

type 
  Path* = string
  Match* = object
    lineNumber*: int
    columnNumber*: int
    line*: string
    path*: Path
    matcher*: string
    tokens*: Tokens
  Tag* = string
  Tags* = Table[Path, seq[Match]] ## for storing and query tags


  TokenKind* = enum
    TStr, TQuestion, TExclamation, TStar, 
    TBacktick, TQuotation, TTag, TStrike, TDate, TBirthday
  Token* = object
    kind*: TokenKind
    data*: string
    col*: int
  Tokens* = seq[Token]
