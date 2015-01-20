include lex
import unittest

proc tc(str: string): LexContext =
  return LexContext(input: str, idx: 0)

# proc matchString(ctx: LexContext): Option[string]
suite "string matching":
  test "raw strings":
    check(tc("'\\u1234'").matchString().get == "\\u1234")
    check(tc("'\\'").matchString().get == "\\")
    check(tc("'\\'").matchString().get == "\\")
  test "escape codes":
    check(tc("\"\\t\"").matchString().get == "\t")
    check(tc("\"\\r\"").matchString().get == "\r")
    check(tc("\"\\n\"").matchString().get == "\l")
  test "multiline":
    check(tc("\"\"\"\l\l\"\"\"").matchString().get == "\l\l")
    check(tc("\"\"\"\r\r\"\"\"").matchString().get == "\r\r")
  test "multiline raw strings":
    check(tc("'''\l\l'''").matchString().get == "\l\l")
    check(tc("'''\r\r'''").matchString().get == "\r\r")
  test "unicode":
    check(tc("\"\\u00A5\\u39F4\"").matchString().get == "¥㧴")
    check(tc("\"\\U00010485\"").matchString().get == "𐒅")
  test "unoffical unicode syntax extentions":
    check(tc("\"\\u10485\"").matchString().get == "𐒅")
    check(tc("\"\\u1BB\"").matchString().get == "ƻ")

  test "syntax errors":
    expect(SyntaxError): discard tc("'\r'").matchString
    expect(SyntaxError): discard tc("\"\l\"").matchString
    expect(SyntaxError): discard tc("'\x01'").matchString
    expect(SyntaxError): discard tc("'\x00'").matchString
    expect(SyntaxError): discard tc("\"\x00\"").matchString

# proc matchDateTime(ctx: LexContext): Option[DateTime]
suite "datetime matching":
  # grabbed from python
  check(tc("1985-04-12T23:20:50.52Z").matchDateTime())
  check(tc("1996-12-19T16:39:57-08:00").matchDateTime())
  check(tc("1996-12-19T16:39:57-08:00").matchDateTime())
  check(tc("1990-12-31T23:59:60Z").matchDateTime())
  check(tc("1990-12-31T15:59:60-08:00").matchDateTime())
  check(tc("2008-04-02T20:00:00Z").matchDateTime())
  check(tc("1970-01-01T00:00:00Z").matchDateTime())
# proc matchBool(ctx: LexContext): Option[bool]
# proc matchInt(ctx: LexContext): Option[int64]
# proc matchFloat(ctx: LexContext): Option[float64]
# proc matchTableHeader(ctx: LexContext): Option[seq[string]]
# proc matchArrTableHeader(ctx: LexContext): Option[seq[string]]
