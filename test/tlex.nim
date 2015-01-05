include lex
import unittest

proc tc(str: string): LexContext =
  return LexContext(input: str, idx: 0)

# proc matchString(ctx: LexContext): Option[string]
suite "string matching":
  test "raw strings":
    check(tc("'\\u1234'").matchString().get == "\\u1234")
  test "unicode":
    check(tc("\"\\u00A5\\u39F4\"").matchString().get == "¥㧴")
    check(tc("\"\\u00010485\"").matchString().get == "𐒅")

# proc matchDateTime(ctx: LexContext): Option[DateTime]
# proc matchBool(ctx: LexContext): Option[bool]
# proc matchInt(ctx: LexContext): Option[int64]
# proc matchFloat(ctx: LexContext): Option[float64]
# proc matchTableHeader(ctx: LexContext): Option[seq[string]]
# proc matchArrTableHeader(ctx: LexContext): Option[seq[string]]
