import tables

type 
  Path* = string
  Match* = object
    lineNumber*: int
    columnNumber*: int
    line*: string
    path*: Path
    matcher*: string
  Tag* = string
  Tags* = Table[Path, seq[Match]] ## for storing and query tags


