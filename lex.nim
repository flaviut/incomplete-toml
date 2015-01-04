import re, option, unicode
from strutils import continuesWith, parseInt

type
  TokenType* = enum
    tt_keyval_sep,
    tt_key,
    tt_int,
    tt_float,
    tt_bool,
    tt_string

  Token* = object
    case kind: TokenType
      of tt_key, tt_string:
        strVal: string
      of tt_int:
        intVal: int64
      of tt_float:
        floatVal: float64
      of tt_bool:
        boolVal: bool
      else:
        nil
  LexContext* = ref object
    input: string
    idx: int

  SyntaxError* = ref object of Exception

proc matchString(ctx: LexContext): Option[string]
include lex_string

proc matchBool(ctx: LexContext): Option[bool] =
  if ctx.input.continuesWith("true", ctx.idx):
    ctx.idx += 4
    return Some(true)
  elif ctx.input.continuesWith("false", ctx.idx):
    ctx.idx += 5
    return Some(false)

  return None[bool]()

let
  IntLit = re"""([+-]?[0-9]+)"""

proc matchInt(ctx: LexContext): Option[int64] =
  var matches: array[1, string]
  if ctx.input.findBounds(IntLit, matches, ctx.idx) != (-1, 0):
    ctx.idx += matches[0].len
    return Some(parseInt matches[0])
  return None[int64]()

proc nextTok(ctx: LexContext, expected: set[TokenType]): Option[Token] =
  discard

echo matchString(LexContext(input : """
"123 12 321 312 "
"""
))
