import typetraits
import re, option, lex
from strutils import `%`, parseFloat, parseInt, toLower

let
  DateTimeInclude = """
  (?(DEFINE)
    (?<fullyear>\d{4})
    (?<month>\d{2})    # ∈ [01, 12]
    (?<mday>\d{2})     # ∈ [01, 31]
    (?<hour>\d{2})     # ∈ [00, 23]
    (?<minute>\d{2})   # ∈ [00, 59]
    (?<second>\d{2})   # ∈ [00, 60]
    (?<secfrac>\.\d+)
    (?<numoffset>[+-] (?&hour) : (?&minute))
    (?<timeoffset>[zZ] | (?&numoffset))
  )
  """

  PartialTimeLit = re("""((?&hour)):((?&minute)):((?&second)) ((?&secfrac))?""" & DateTimeInclude)

  FullTimeLit = re("""
  ((?&hour)):((?&minute)):((?&second)) ((?&secfrac))?  # sync with PartialTime
  ((?&timeoffset))
  """ & DateTimeInclude)

  TimeOffset = re(""" ([+-]) ((?&hour)) : ((?&minute)) | ([zZ]) """ & DateTimeInclude)

  FullDateLit = re("""((?&fullyear))-((?&month))-((?&mday))""" & DateTimeInclude)

  DateTimeLit = re("""
  ((?&fullyear))-((?&month))-((?&mday))  # sync with FullDate
  [tT ]
  ((?&hour)):((?&minute)):((?&second)) ((?&secfrac))? ((?&timeoffset))  # sync with FullTime
  """ & DateTimeInclude)


proc fillDate(result: var DateTime, matches: openarray[string], offset: int) =
  result.date = Some((
     monthday : range[1  ..  31](parseInt matches[2 + offset]),
     month    : range[0  ..  12](parseInt matches[1 + offset]),
     year     : range[0 .. 9999](parseInt matches[0 + offset]),
  ))

proc fillPartialTime(result: var DateTime, matches: openarray[string], offset: int) =
  result.time = Some((
    subsecond: if matches[3 + offset] != nil: Some(parseFloat matches[3 + offset])
               else: None[float64](),
    second : range[0 .. 60](parseInt matches[2 + offset]),
    minute : range[0 .. 59](parseInt matches[1 + offset]),
    hour   : range[0 .. 23](parseInt matches[0 + offset]),
  ))

proc fillFullTime(result: var DateTime, oldMatches: openarray[string], offset: int) =
  var offset = offset
  result.fillPartialTime(oldMatches, offset)
  assert(oldMatches[4 + offset] != nil)
  if oldMatches[4 + offset] =~ TimeOffset:
    if matches[3] != nil and
       matches[3].len == 1 and
       matches[3][0] in {'z', 'Z'}:
      # UTC is defined as +00:00
      result.offset = Some((
        positive : true,
        minute   : range[0 .. 59](0),
        hour     : range[0 .. 23](0),
      ))
    else:
      result.offset = Some((
        positive : matches[0] == "+",
        minute   : range[0 .. 59](parseInt matches[2]),
        hour     : range[0 .. 23](parseInt matches[1]),
      ))
  else:
    raise newException(ValueError,
      "unable to parse input `$1` as a timezone offset" % [oldMatches[4 + offset]])

proc matchDateTime(ctx: LexContext): Option[DateTime] =
  var matches: array[8, string]
  if (let len = ctx.input.findBounds(DateTimeLit, matches, ctx.idx); len != (-1, 0)):
    ctx.idx += len.last - len.first
    var dtResult: DateTime
    dtResult.fillDate(matches, 0)
    dtResult.fillFullTime(matches, 3)
    return Some(dtResult)
  elif (let len = ctx.input.findBounds(FullDateLit, matches, ctx.idx); len != (-1, 0)):
    ctx.idx += len.last - len.first
    var dtResult: DateTime
    dtResult.fillDate(matches, 0)
    return Some(dtResult)
  elif (let len = ctx.input.findBounds(FullTimeLit, matches, ctx.idx); len != (-1, 0)):
    ctx.idx += len.last - len.first
    var dtResult: DateTime
    dtResult.fillFullTime(matches, 0)
    return Some(dtResult)
  elif (let len = ctx.input.findBounds(PartialTimeLit, matches, ctx.idx); len != (-1, 0)):
    ctx.idx += len.last - len.first
    var dtResult: DateTime
    dtResult.fillPartialTime(matches, 0)
    return Some(dtResult)
  else:
    return None[DateTime]()
