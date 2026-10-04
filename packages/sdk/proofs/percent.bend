# Proofs: percent decoding
# ========================
#
# A text without a percent sign decodes to itself (law decode_plain). The
# decoder scans the text from its end into pieces and assembles the pieces
# from their end: scan_plain shows that a text without a percent sign scans
# into its characters as raw pieces, by induction on the text, taking the
# hypothesis apart character by character with the lemmas of
# proofs/bools.bend; assemble_plain shows that raw pieces assemble into
# their characters with nothing pending, by induction on the text; plain
# composes the two through Percent.decode.

import Base
import ../LAWS.bend as Laws
import ../sdk.bend as Sdk
import ./bools.bend as BoolsProof

# The characters of a text, each kept as it is.
def raw_pieces(text: String) -> List<&2, Sdk.Piece>:
  match text:
    case SNil{}:
      Nil{}
    case SCon{char, rest}:
      Con{Sdk.RawPiece{char}, raw_pieces(rest)}

# A text without a percent sign scans into its characters.
law scan_plain:
  for text: String
  for +plain: {Laws.has_percent(text) == False{} : Bool}
  {Sdk.Percent.scan(text) == Some{raw_pieces(text)} : Maybe<&2, List<&2, Sdk.Piece>>}

# The first character is not a percent sign (or_left_false), so the step
# keeps it; the rest has none either (or_right_false), so by induction it
# scans into its raw pieces.
def scan_plain(text, plain):
  match text:
    case SNil{}:
      {==}
    case SCon{+char, +rest}:
      %Equal.sym(Bool, Char.is_eq(char, '%'), False{},
        BoolsProof.or_left_false(Char.is_eq(char, '%'), Laws.has_percent(rest), plain)) :
        {Sdk.Percent.scan.step(char, Sdk.Percent.scan(rest), _) == Some{Con{Sdk.RawPiece{char}, raw_pieces(rest)}} :
          Maybe<&2, List<&2, Sdk.Piece>>}
      %Equal.sym(Maybe<&2, List<&2, Sdk.Piece>>, Sdk.Percent.scan(rest), Some{raw_pieces(rest)},
        scan_plain(rest, BoolsProof.or_right_false(Char.is_eq(char, '%'), Laws.has_percent(rest), plain))) :
        {Sdk.Percent.scan.step(char, _, False{}) == Some{Con{Sdk.RawPiece{char}, raw_pieces(rest)}} :
          Maybe<&2, List<&2, Sdk.Piece>>}
      {==}

# Raw pieces assemble into their characters, with no continuation byte
# pending.
law assemble_plain:
  for text: String
  {Sdk.Percent.assemble(raw_pieces(text)) == Some{Sdk.Decoding{text, Nil{}}} : Maybe<&2, Sdk.Decoding>}

def assemble_plain(text):
  match text:
    case SNil{}:
      {==}
    case SCon{char, +rest}:
      %Equal.sym(Maybe<&2, Sdk.Decoding>, Sdk.Percent.assemble(raw_pieces(rest)), Some{Sdk.Decoding{rest, Nil{}}},
        assemble_plain(rest)) :
        {Sdk.Percent.assemble.piece(Sdk.RawPiece{char}, _) == Some{Sdk.Decoding{SCon{char, rest}, Nil{}}} : Maybe<&2, Sdk.Decoding>}
      {==}

# A text without a percent sign decodes to itself.
law plain:
  for +text: String
  for plain: {Laws.has_percent(text) == False{} : Bool}
  {Sdk.Percent.decode(text) == Some{text} : Maybe<&2, String>}

def plain(text, plain):
  %Equal.sym(Maybe<&2, List<&2, Sdk.Piece>>, Sdk.Percent.scan(text), Some{raw_pieces(text)}, scan_plain(text, plain)) :
    {Sdk.Percent.decode.finish(Sdk.Percent.decode.assembled(_)) == Some{text} : Maybe<&2, String>}
  %Equal.sym(Maybe<&2, Sdk.Decoding>, Sdk.Percent.assemble(raw_pieces(text)), Some{Sdk.Decoding{text, Nil{}}},
    assemble_plain(text)) :
    {Sdk.Percent.decode.finish(_) == Some{text} : Maybe<&2, String>}
  {==}
