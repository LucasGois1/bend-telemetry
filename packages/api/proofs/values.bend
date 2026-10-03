# Proofs: bytes and truncation
# ============================
#
# The bytes constructor accepts exactly the lists whose cells are bytes, and
# truncation cuts exactly the strings longer than the limit. PROOF.bend
# proves the laws bytes_accepted, bytes_refused, truncate_string and
# truncate_keeps_short of LAWS.bend with these lemmas.
#
# fit_spec identifies the laws' independent check cells_fit with the
# package's AttributeValue.bytes.fit by induction, so that a hypothesis on
# one becomes a fact about the other. AttributeValue.bytes passes the result
# of its check to AttributeValue.bytes.checked, and `match` cannot inspect a
# computed value, so accepted and refused rewrite that result with the
# hypothesis and let the checker compute the rest; the truncation lemmas do
# the same with the length comparison that AttributeValue.truncate.string
# passes to AttributeValue.truncate.text.

import Base
import ../LAWS.bend as Laws
import ../api.bend as Api
import ./nats.bend as NatsProof

# The laws' check and the package's agree on every list: both walk the list
# and ask of each cell whether it is at most 255.
law fit_spec:
  for cells: List<&2, U32>
  {Laws.cells_fit(cells) == Api.AttributeValue.bytes.fit(cells) : Bool}

def fit_spec(cells):
  match cells:
    case Nil{}:
      {==}
    case Con{cell, rest}:
      %fit_spec(rest) : {Bool.and(U32.is_le(cell, 255), Laws.cells_fit(rest)) == Bool.and(U32.is_le(cell, 255), _) : Bool}
      {==}

# When the laws' check accepts the cells, so does the package's.
law fit_true:
  for +cells: List<&2, U32>
  for fit: {Laws.cells_fit(cells) == True{} : Bool}
  {Api.AttributeValue.bytes.fit(cells) == True{} : Bool}

def fit_true(cells, fit):
  Equal.trans(Bool, Api.AttributeValue.bytes.fit(cells), Laws.cells_fit(cells), True{},
    Equal.sym(Bool, Laws.cells_fit(cells), Api.AttributeValue.bytes.fit(cells), fit_spec(cells)), fit)

# When the laws' check refuses the cells, so does the package's.
law fit_false:
  for +cells: List<&2, U32>
  for over: {Laws.cells_fit(cells) == False{} : Bool}
  {Api.AttributeValue.bytes.fit(cells) == False{} : Bool}

def fit_false(cells, over):
  Equal.trans(Bool, Api.AttributeValue.bytes.fit(cells), Laws.cells_fit(cells), False{},
    Equal.sym(Bool, Laws.cells_fit(cells), Api.AttributeValue.bytes.fit(cells), fit_spec(cells)), over)

# The bytes constructor answers the cells when they all fit: the check is
# rewritten to True{}, and AttributeValue.bytes.checked computes.
law accepted:
  for +cells: List<&2, U32>
  for fit: {Laws.cells_fit(cells) == True{} : Bool}
  {Api.AttributeValue.bytes(cells) == Some{Api.BytesValue{cells}} : Maybe<&2, Api.AttributeValue>}

def accepted(cells, fit):
  %Equal.sym(Bool, Api.AttributeValue.bytes.fit(cells), True{}, fit_true(cells, fit)) :
    {Api.AttributeValue.bytes.checked(cells, _) == Some{Api.BytesValue{cells}} : Maybe<&2, Api.AttributeValue>}
  {==}

# The bytes constructor answers None when a cell does not fit.
law refused:
  for +cells: List<&2, U32>
  for over: {Laws.cells_fit(cells) == False{} : Bool}
  {Api.AttributeValue.bytes(cells) == None{} : Maybe<&2, Api.AttributeValue>}

def refused(cells, over):
  %Equal.sym(Bool, Api.AttributeValue.bytes.fit(cells), False{}, fit_false(cells, over)) :
    {Api.AttributeValue.bytes.checked(cells, _) == None{} : Maybe<&2, Api.AttributeValue>}
  {==}

# A text longer than the limit is cut to its first `limit` characters.
law cut:
  for +limit: Nat
  for +text: String
  for longer: {Nat.is_lt(limit, String.length(text)) == True{} : Bool}
  {Api.AttributeValue.truncate.string(limit, text) == String.take(text, limit) : String}

def cut(limit, text, longer):
  %Equal.sym(Bool, Nat.is_lt(limit, String.length(text)), True{}, longer) :
    {Api.AttributeValue.truncate.text(limit, text, _) == String.take(text, limit) : String}
  {==}

# A text within the limit is kept.
law kept:
  for +limit: Nat
  for +text: String
  for fits: {Nat.is_lt(limit, String.length(text)) == False{} : Bool}
  {Api.AttributeValue.truncate.string(limit, text) == text : String}

def kept(limit, text, fits):
  %Equal.sym(Bool, Nat.is_lt(limit, String.length(text)), False{}, fits) :
    {Api.AttributeValue.truncate.text(limit, text, _) == text : String}
  {==}

# The string value of a text longer than the limit, truncated, is the
# string value of the first `limit` characters.
law cut_value:
  for +limit: Nat
  for +text: String
  for longer: {Nat.is_lt(limit, String.length(text)) == True{} : Bool}
  {Api.AttributeValue.truncate(Some{limit}, Api.StringValue{text}) == Api.StringValue{String.take(text, limit)} : Api.AttributeValue}

def cut_value(limit, text, longer):
  %Equal.sym(String, Api.AttributeValue.truncate.string(limit, text), String.take(text, limit), cut(limit, text, longer)) :
    {Api.StringValue{_} == Api.StringValue{String.take(text, limit)} : Api.AttributeValue}
  {==}

# That string value has exactly `limit` characters (NatsProof.take_length).
law cut_length:
  for +limit: Nat
  for +text: String
  for +longer: {Nat.is_lt(limit, String.length(text)) == True{} : Bool}
  {Laws.string_length(Api.AttributeValue.truncate(Some{limit}, Api.StringValue{text})) == limit : Nat}

def cut_length(limit, text, longer):
  %Equal.sym(String, Api.AttributeValue.truncate.string(limit, text), String.take(text, limit), cut(limit, text, longer)) :
    {String.length(_) == limit : Nat}
  NatsProof.take_length(text, limit, longer)

# The string value of a text within the limit is kept.
law kept_value:
  for +limit: Nat
  for +text: String
  for fits: {Nat.is_lt(limit, String.length(text)) == False{} : Bool}
  {Api.AttributeValue.truncate(Some{limit}, Api.StringValue{text}) == Api.StringValue{text} : Api.AttributeValue}

def kept_value(limit, text, fits):
  %Equal.sym(String, Api.AttributeValue.truncate.string(limit, text), text, kept(limit, text, fits)) :
    {Api.StringValue{_} == Api.StringValue{text} : Api.AttributeValue}
  {==}
