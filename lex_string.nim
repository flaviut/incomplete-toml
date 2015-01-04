## INCLUDED IN lex.nim

import re, option, unicode
from parseutils import parseHex

const StringLitUtil = """
(?(DEFINE)
  (?<escaped>
    \\" | \\\\ | \\\/ | \\b |
    \\f | \\n  | \\r  | \\t |
    \\u [0-9a-zA-Z]{4}      |
    \\u [0-9a-zA-Z]{8}
  )
  (?<newline> [\n\r])

  (?<basic_unescaped>     [\x20-\x21\x23-\x5B\x5D-\xFF] )
  (?<basic_char>          (?&basic_unescaped) | (?&escaped) )
  (?<dumb_basic_char>     \\\\|\\"|[^"] )

  (?<ml_basic_unescaped>  [\x20-\x5B\x5D-\xFF] )
  (?<ml_basic_body>       (?&ml_basic_unescaped) |
                          (?&escaped) |
                          \\? (?&newline) )
  (?<dumb_ml_basic_body>  (?!" " ")(?: (?&dumb_basic_char) | "))

  (?<literal_char>        [\x09\x20-\x26\x28-\xFF])
  (?<dumb_literal_char>   [^'])

  (?<ml_literal_body>      [\x09\x20-\xFF] | (?&newline))
  (?<dumb_ml_literal_body> (?!''')[\s\S])
)

"""

let
  BasicStringLit = re(StringLitUtil & """
# Basic String
^"( (?&basic_char)* )"
""")

  MultilineStringLit = re(StringLitUtil & """
# Multiline String
^" " "( (?&ml_basic_body)* )" " "
""")


  LiteralStringLit = re(StringLitUtil & """
# Literal String
^'( (?&literal_char)* )'
""")

  MultilineLiteralStringLit = re(StringLitUtil & """
# Multiline Literal String
^'''( (?&ml_literal_body)* )'''
""")


  DumbMultilineStringLit = re(StringLitUtil & """
# Dumb Multiline String
^" " "( (?&dumb_ml_basic_body)* )" " "
""")

  DumbBasicStringLit = re(StringLitUtil & """
# Dumb Basic String
^"( (?&dumb_basic_char)* )"
""")


  DumbLiteralStringLit = re(StringLitUtil & """
# Dumb Literal String
^'( (?&dumb_literal_char)* )'
""")

  DumbMultilineLiteralStringLit = re(StringLitUtil & """
# Dumb Multiline Literal String
^'''( (?&dumb_ml_literal_body)* )'''
""")

  StringMatchers: seq[tuple[matcher, roughMatcher: Regex,
                            interpretEscapes: bool]] = @[
    (MultilineStringLit,        DumbMultilineStringLit,        true),
    (BasicStringLit,            DumbBasicStringLit,            true),
    (MultilineLiteralStringLit, DumbMultilineLiteralStringLit, false),
    (LiteralStringLit,          DumbLiteralStringLit,          false),
  ]

let EscapeReplacements = @[
  (re"\\""", "\""),
  (re"\\\\", "\\"),
  (re"\\\/", "/"),
  (re"\\b", "\b"),
  (re"\\f", "\f"),
  (re"\\n", "\l"),
  (re"\\r", "\r"),
  (re"\\t", "\t"),
]

let UnicodeEscape = re"\\u([0-9a-zA-Z]{4})|\\u([0-9a-zA-Z]{8})"

proc interpretEscapes(str: string): string =
  ## Assumes the input is valid
  assert(str != nil)

  result = str.parallelReplace(EscapeReplacements)
  result = result.replace(UnicodeEscape) do (matches: openarray[string]) -> string:
    var num: int
    if parseHex(matches[0], num) != matches[0].len:
      raise newException(Exception, "Internal Error: unable to parse `" & matches[0] & "`")
    return Rune(num).toUTF8

proc matchString(ctx: LexContext): Option[string] =
  const CaptureNum = 12
  var matches: array[CaptureNum + 1, string]

  for row in StringMatchers:
    let roughMatch = ctx.input.findBounds(row.roughMatcher, ctx.idx)
    if roughMatch != (-1, 0):
      let match = ctx.input.findBounds(row.matcher, matches, ctx.idx)

      if match != roughMatch:
        raise SyntaxError(msg: $ctx.idx & ": Syntax error, malformed string")

      ctx.idx += match.last - match.first

      if row.interpretEscapes:
        return Some(interpretEscapes(matches[CaptureNum]))

      return Some(matches[CaptureNum])

  return None[string]()

