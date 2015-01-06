## INCLUDED IN lex.nim

import re, option, unicode
from parseutils import parseHex

const StringLitUtil = """
(?(DEFINE)
  (?<escaped>
    \\" | \\\\ | \\\/ | \\b |
    \\f | \\n  | \\r  | \\t |
    \\[uU] [0-9a-zA-Z]{2,8} |
  )
  (?<newline> [\n\r])

  (?<basic_unescaped>     [\x20-\x21\x23-\x5B\x5D-\xFF] )
  (?<basic_char>          (?&basic_unescaped) | (?&escaped) )
  (?<dumb_basic_char>     \\\\|\\"|[^"] )

  (?<ml_basic_unescaped>  [\x20-\x5B\x5D-\xFF] )
  (?<ml_basic_body>       (?!" " ")(?:(?&ml_basic_unescaped) |
                          \\? [\n\r]|
                          (?&escaped)))
  (?<dumb_ml_basic_body>  (?!" " ")(?: (?&dumb_basic_char) | "))

  (?<literal_char>        [\x09\x20-\x26\x28-\xFF])
  (?<dumb_literal_char>   [^'])

  (?<ml_literal_body>      [\x09\x20-\xFF] | (?&newline))
  (?<dumb_ml_literal_body> (?!''')[\s\S])
)

"""

let
  BasicStringLit = re("""
# Basic String
^"( (?&basic_char)* )"
""" & StringLitUtil)

  MultilineStringLit = re("""
# Multiline String
^" " "( (?&ml_basic_body)* )" " "
""" & StringLitUtil)


  LiteralStringLit = re("""
# Literal String
^'( (?&literal_char)* )'
""" & StringLitUtil)

  MultilineLiteralStringLit = re("""
# Multiline Literal String
^'''( (?&ml_literal_body)* )'''
""" & StringLitUtil)


  DumbMultilineStringLit = re("""
# Dumb Multiline String
^" " "( (?&dumb_ml_basic_body)* )" " "
""" & StringLitUtil)

  DumbBasicStringLit = re("""
# Dumb Basic String
^"( (?&dumb_basic_char)* )"
""" & StringLitUtil)


  DumbLiteralStringLit = re("""
# Dumb Literal String
^'( (?&dumb_literal_char)* )'
""" & StringLitUtil)

  DumbMultilineLiteralStringLit = re("""
# Dumb Multiline Literal String
^'''( (?&dumb_ml_literal_body)* )'''
""" & StringLitUtil)

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

let UnicodeEscape = re"\\[uU]([0-9a-zA-Z]{2,8})"

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
  var matches: array[1, string]

  for row in StringMatchers:
    let roughMatch = ctx.input.findBounds(row.roughMatcher, ctx.idx)
    if roughMatch != (-1, 0):
      let match = ctx.input.findBounds(row.matcher, matches, ctx.idx)

      if match != roughMatch:
        raise SyntaxError(msg: $ctx.idx & ": Syntax error, malformed string")

      ctx.idx += match.last - match.first

      if row.interpretEscapes:
        return Some(interpretEscapes(matches[0]))

      return Some(matches[0])

  return None[string]()

