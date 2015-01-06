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
# proc matchBool(ctx: LexContext): Option[bool]
# proc matchInt(ctx: LexContext): Option[int64]
# proc matchFloat(ctx: LexContext): Option[float64]
# proc matchTableHeader(ctx: LexContext): Option[seq[string]]
# proc matchArrTableHeader(ctx: LexContext): Option[seq[string]]
