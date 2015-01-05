import re, option, unicode
from strutils import continuesWith, parseInt, parseFloat, strip, split

type
  TokenType* = enum
    tt_keyval_sep,
    tt_key,
    tt_int,
    tt_float,
    tt_bool,
    tt_string,
    tt_datetime,
    tt_table_head,
    tt_arr_table_head,

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
      of tt_datetime:
        datetimeVal: DateTime
      of tt_table_head, tt_arr_table_head:
        headVal: seq[string]
      else:
        nil

  DateTime* = object
    time*: Option[tuple[subsecond: Option[float],  ## ∈ [0, 1)
                        second: range[0 .. 60],  ## 60 for leap seconds
                        minute: range[0 .. 59],
                        hour: range[0 .. 23]]]

    date*: Option[tuple[monthday: range[1 .. 31],
                        month: range[0 .. 12],
                        year: range[0 .. 9999]]]

    offset*: Option[tuple[positive: bool,
                          minute: range[0 .. 59],
                          hour: range[0 .. 23]]]

  LexContext* = ref object
    input*: string
    idx*: int

  SyntaxError* = ref object of Exception

proc matchString(ctx: LexContext): Option[string]
include lex_string

proc matchDateTime(ctx: LexContext): Option[DateTime]
include lex_datetime

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
    return Some[int64](parseInt matches[0])
  return None[int64]()

let
  FloatLit = re"""([+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?) """

proc matchFloat(ctx: LexContext): Option[float64] =
  var matches: array[1, string]
  if ctx.input.findBounds(FloatLit, matches, ctx.idx) != (-1, 0):
    ctx.idx += matches[0].len
    return Some(parseFloat matches[0])
  return None[float64]()

let
  HeaderInclude = """
  (?(DEFINE)
    (?<ident_chars> [^\x00-\x19\n=\[\]"'#]+)
    (?<ident> (?&ident_chars) (?: \. (?&ident_chars)*) )
  )
  """
  RoughTableHeader = re""" \[ [^\[\]]* \] """
  RoughArrTableHeader = re""" \[\[ [^\]\[]* \]\] """
  TableHeader = re(""" \[ ((?&ident)) \] """ & HeaderInclude)
  ArrTableHeader = re(""" \[\[ ((?&ident)) \]\] """ & HeaderInclude)

proc matchHeader(str: string, idx: var int, regex: Regex, roughRegex: Regex): Option[seq[string]] =
  let roughBounds = str.findBounds(roughRegex, idx)
  if roughBounds != (-1, 0):
    var matches: array[1, string]
    let bounds = str.findBounds(regex, matches, idx)
    if bounds != (-1, 0):
      assert(bounds == roughBounds)
      idx += bounds.last - bounds.first
      return Some(matches[0]
                  .split('.')
                  .map(proc (str: string): string = strip(str)))
    else:
      raise SyntaxError(msg: $idx & ": Invalid header")
  else:
    return None[seq[string]]()

proc matchTableHeader(ctx: LexContext): Option[seq[string]] =
  return matchHeader(ctx.input, ctx.idx, TableHeader, RoughTableHeader)

proc matchArrTableHeader(ctx: LexContext): Option[seq[string]] =
  return matchHeader(ctx.input, ctx.idx, ArrTableHeader, RoughArrTableHeader)

proc nextTok(ctx: LexContext, expected: set[TokenType]): Option[Token] =
  discard
