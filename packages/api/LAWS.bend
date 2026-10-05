import Base
import ./api.bend as Api
import bend-trace-context@0.2.0.0/trace_context.bend as TC

# The laws of bend-telemetry-api
# ==============================
#
# This file is the package's statement of claims. Each `law` below is a
# property the Bend checker must prove for every value it quantifies over,
# or, where it quantifies over nothing, a fact about literal values that the
# checker computes. PROOF.bend proves each law with a def of the same name
# (`law set_get` is proved by `def Laws.set_get`), and
#
#   ./bend packages/api/PROOF.bend --check-only
#
# prints "ALL PROOFS CHECK" only when every law in this file is proved and no
# definition PROOF.bend imports relies on `@unsafe` or foreign code.
# scripts/validate.sh runs that gate. The project owner reviews and owns
# these statements; the proofs may change freely as long as the statements
# hold.
#
# Every law is documented with the same headings:
#
#   Claim        what the law says, in plain words.
#   Requirement  the rule it enforces: a section of the OpenTelemetry
#                specification ("OTel" below: Common, Attribute; Trace SDK,
#                Span limits; OTLP, AnyValue), of W3C Trace Context Level 2
#                ("W3C" below, with section numbers), a decision of the
#                tracing API specification (issue #2, "spec #2") or of the
#                local ADR 0006 that the ticket #4 records.
#   Why          what would go wrong for an adopter without it.
#   Reading      how the Bend statement expresses the claim, when the
#                notation is not obvious.
#   Proof        where the proof lives.
#
# How to read a law
# -----------------
#
#   law name:                  the claim is called `name`.
#     for x: T                 "for every x of type T". A law holds for every
#                              combination of its `for` lines at once.
#     for h: {a == b : T}      a hypothesis: the claim only covers the values
#                              for which a equals b, typically that a check
#                              holds (`{Nat.is_lt(a, b) == True{} : Bool}`).
#     {a == b : T}             the conclusion: a and b are the same value of
#                              type T.
#     P & Q                    both P and Q hold.
#
#   `+x` is a resource annotation: `+x` may be used several times. It never
#   changes what a law means. A law with no `for` line is a fact about the
#   literal values it names, proved by computation: a legitimate law, used
#   where the universal statement is beyond what the checker computes (the
#   checker evaluates Nat in unary, and F32's text is a run-time primitive).
#
# Values that appear in the statements:
#
#   Some{v}, None{}            a present and an absent optional value (Maybe).
#   True{}, False{}            Booleans. Checks such as Nat.is_lt(a, b)
#                              ("a < b") return a Bool.
#   0n, 128n, 1n+n             natural numbers (Nat); `1n+n` is n + 1.
#   42, 4294967295             32-bit words (U32).
#   "text", [a, b], Nil{}      strings, lists and the empty list.
#   List.append(&2, T, a, b)   the list a followed by b. `&2` and the element
#                              type T are arguments Bend requires; they carry
#                              no meaning here.
#   Api.Name                   a definition of the package, from api.bend;
#                              Api.StringValue{t}, Api.Attribute{k, v} and the
#                              other constructors build its values.
#   Api.Recording{p, d}        a recording span with the SDK payload p and the
#                              span data d; Api.NonRecording{c} a non-recording
#                              span with the optional span context c. P is the
#                              payload type, erased (`for -P: Data`).
#
# Definitions made in this file with `def` (`key_among`, `keys_distinct`,
# `cells_fit`, `string_length`, `limited_example`, `limited_event`,
# `known_flags`, `received_pair`, `forwarded`) are independent
# specifications used to state the laws. They are deliberately not taken
# from the package, so each law compares the package with a second, simpler
# description of the rule.
#
# Contents
# --------
#
#   1. Package                name, context_fields
#   2. 64-bit integers        int64_limbs ... int64_text_roundtrip
#   3. Doubles                double_f32, double_text
#   4. Attribute values       standard_arrays ... bytes_literal
#   5. Attributes             empty_attributes ... set_all_fold
#   6. Span limits            default_limits ... truncate_literal
#   7. Timestamps             timestamp_readers ... timestamp_order
#   8. Span context           span_context_remote ... parts_not_forwarded
#   9. Context                context_set_then_read ... context_cleared
#  10. Instrumentation scope  scope_readers
#  11. Span options           default_options, options_set_then_read
#  12. Status                 status_description ... ok_final
#  13. Events and links       event_readers ... event_limits_literal
#  14. Spans                  new_data_readers ... links_bounded

# 1. Package
# ==========

# LAW name
#   Claim: the package answers its own BendHub name.
#   Proof: Laws.name, by computation.
law name:
  {Api.Package.name() == "bend-telemetry-api" : String}

# LAW context_fields
#   Claim: the context fields are those of W3C Trace Context, in injection
#     order.
#   Requirement: #1, decision 8: W3C Trace Context comes from
#     bend-trace-context.
#   Proof: Laws.context_fields, by computation.
law context_fields:
  {Api.TraceContext.fields() == ["traceparent", "tracestate"] : List<&2, String>}

# 2. 64-bit integers
# ==================
#
# Int64 is two U32 limbs read as one two's complement number (ADR 0006). The
# universal laws are those the checker can compute symbolically; the Nat
# constructor and the decimal text are stated on literal cases, including the
# minimum and the maximum values, because the checker evaluates Nat in unary.

# LAW int64_limbs
#   Claim: the limbs of a value built from two limbs are those limbs.
#   Requirement: #4, "readers for the limbs"; ADR 0006, "the limbs constructor
#     is the bridge for anyone who holds one".
#   Why: an exporter that encodes a value as its limbs must get back exactly
#     what a caller handed over.
#   Proof: Laws.int64_limbs, by computation.
law int64_limbs:
  for +high: U32
  for +low: U32
  {Api.Int64.high(Api.Int64.from_limbs(high, low)) == high : U32} &
  {Api.Int64.low(Api.Int64.from_limbs(high, low)) == low : U32}

# LAW int64_u32
#   Claim: a U32 reads back as a non-negative value: its low limb is the
#     word, its high limb is zero and its sign is not negative.
#   Requirement: #4, "a U32 and a Nat read back as non-negative values".
#   Proof: Laws.int64_u32, by computation.
law int64_u32:
  for +word: U32
  {Api.Int64.is_negative(Api.Int64.from_u32(word)) == False{} : Bool} &
  {Api.Int64.high(Api.Int64.from_u32(word)) == 0 : U32} &
  {Api.Int64.low(Api.Int64.from_u32(word)) == word : U32}

# LAW int64_nat
#   Claim: a Nat reads back as a non-negative value whose limbs are its
#     quotient and remainder by 2^32: literal cases around the 16-bit pieces
#     that the conversion uses.
#   Requirement: #4, as int64_u32.
#   Reading: a Nat is unary for the checker, so the cases stay small; at run
#     time the conversion is native up to 2^48 - 1, Base's bound on Nat.
#   Proof: Laws.int64_nat, by computation.
law int64_nat:
  {Api.Int64.is_negative(Api.Int64.from_nat(0n)) == False{} : Bool} &
  {Api.Int64.is_negative(Api.Int64.from_nat(70000n)) == False{} : Bool} &
  {Api.Int64.from_nat(5n) == Api.Int64.from_u32(5) : Api.Int64} &
  {Api.Int64.from_nat(65535n) == Api.Int64.from_u32(65535) : Api.Int64} &
  {Api.Int64.from_nat(65536n) == Api.Int64.from_limbs(0, 65536) : Api.Int64} &
  {Api.Int64.from_nat(70000n) == Api.Int64.from_limbs(0, 70000) : Api.Int64}

# LAW int64_negated
#   Claim: a negated Nat reads back negative, with the two's complement limbs
#     of literal cases: -1 is both limbs all ones, -0 is 0, and -65536 and
#     -70000 borrow through the low limb.
#   Requirement: #4, "a negated Nat reads back negative with the
#     two's-complement limbs of literal cases (-1 is both limbs all ones)".
#   Why: OTLP's protobuf encoding writes the limbs of a negative integer as
#     two's complement; a wrong borrow would change the value on the wire.
#   Proof: Laws.int64_negated, by computation.
law int64_negated:
  {Api.Int64.from_negated_nat(1n) == Api.Int64.from_limbs(4294967295, 4294967295) : Api.Int64} &
  {Api.Int64.is_negative(Api.Int64.from_negated_nat(1n)) == True{} : Bool} &
  {Api.Int64.from_negated_nat(0n) == Api.Int64.from_u32(0) : Api.Int64} &
  {Api.Int64.from_negated_nat(65536n) == Api.Int64.from_limbs(4294967295, 4294901760) : Api.Int64} &
  {Api.Int64.from_negated_nat(70000n) == Api.Int64.from_limbs(4294967295, 4294897296) : Api.Int64}

# LAW int64_show
#   Claim: the decimal text of literal values: zero, the largest U32, 2^32,
#     the maximum, the minimum, -1 and -70000.
#   Requirement: #4, "readers for ... the decimal text"; ADR 0006, "division
#     by ten for decimal text".
#   Why: OTLP's JSON encoding carries a 64-bit integer as decimal text.
#   Proof: Laws.int64_show, by computation.
law int64_show:
  {Api.Int64.show(Api.Int64.from_u32(0)) == "0" : String} &
  {Api.Int64.show(Api.Int64.from_u32(4294967295)) == "4294967295" : String} &
  {Api.Int64.show(Api.Int64.from_limbs(1, 0)) == "4294967296" : String} &
  {Api.Int64.show(Api.Int64.from_limbs(2147483647, 4294967295)) == "9223372036854775807" : String} &
  {Api.Int64.show(Api.Int64.from_limbs(2147483648, 0)) == "-9223372036854775808" : String} &
  {Api.Int64.show(Api.Int64.from_negated_nat(1n)) == "-1" : String} &
  {Api.Int64.show(Api.Int64.from_negated_nat(70000n)) == "-70000" : String}

# LAW int64_read
#   Claim: the values of literal decimal texts, leading zeros included: the
#     same cases as int64_show, read.
#   Requirement: #4, "from decimal text (answering Maybe)".
#   Proof: Laws.int64_read, by computation.
law int64_read:
  {Api.Int64.read("0") == Some{Api.Int64.from_u32(0)} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read("007") == Some{Api.Int64.from_u32(7)} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read("4294967296") == Some{Api.Int64.from_limbs(1, 0)} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read("9223372036854775807") == Some{Api.Int64.from_limbs(2147483647, 4294967295)} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read("-9223372036854775808") == Some{Api.Int64.from_limbs(2147483648, 0)} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read("-1") == Some{Api.Int64.from_limbs(4294967295, 4294967295)} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read("-70000") == Some{Api.Int64.from_negated_nat(70000n)} : Maybe<&2, Api.Int64>}

# LAW int64_read_refuses
#   Claim: texts that are not a 64-bit integer are refused: the empty text,
#     a sign alone, a letter, a plus sign, a space, the values just past the
#     maximum and the minimum, and 2^64.
#   Requirement: #4, as int64_read; spec #2, "Constructors that validate
#     input answer an optional value".
#   Why: a reader that accepted a value past the range would silently wrap.
#   Proof: Laws.int64_read_refuses, by computation.
law int64_read_refuses:
  {Api.Int64.read("") == None{} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read("-") == None{} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read("12a") == None{} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read("+1") == None{} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read(" 1") == None{} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read("9223372036854775808") == None{} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read("-9223372036854775809") == None{} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read("18446744073709551616") == None{} : Maybe<&2, Api.Int64>}

# LAW int64_text_roundtrip
#   Claim: decimal text round-trips in both directions on the maximum and
#     the minimum: reading the text of the value gives the value, and the
#     text of the value read from the text is that text.
#   Requirement: #4, "decimal text round-trips in both directions on literal
#     cases including the minimum and maximum values".
#   Proof: Laws.int64_text_roundtrip, by computation.
law int64_text_roundtrip:
  {Api.Int64.read(Api.Int64.show(Api.Int64.from_limbs(2147483647, 4294967295))) ==
    Some{Api.Int64.from_limbs(2147483647, 4294967295)} : Maybe<&2, Api.Int64>} &
  {Api.Int64.read(Api.Int64.show(Api.Int64.from_limbs(2147483648, 0))) ==
    Some{Api.Int64.from_limbs(2147483648, 0)} : Maybe<&2, Api.Int64>} &
  {Maybe.map(&2, Api.Int64, String, Api.Int64.show, Api.Int64.read("9223372036854775807")) ==
    Some{"9223372036854775807"} : Maybe<&2, String>} &
  {Maybe.map(&2, Api.Int64, String, Api.Int64.show, Api.Int64.read("-9223372036854775808")) ==
    Some{"-9223372036854775808"} : Maybe<&2, String>}

# 3. Doubles
# ==========
#
# Double holds an F32 (ADR 0006). F32's text is a run-time primitive that the
# checker does not compute, so its laws say that the double adds nothing to
# the F32: the readers give back what the constructors took.

# LAW double_f32
#   Claim: the F32 of a double built from an F32 is that F32.
#   Requirement: #4, "constructors from F32 ... readers for the F32 value".
#   Proof: Laws.double_f32, by computation.
law double_f32:
  for +value: F32
  {Api.Double.to_f32(Api.Double.from_f32(value)) == value : F32}

# LAW double_text
#   Claim: the text of a double is Base's shortest F32 text, and reading a
#     text is Base's F32 reading, wrapped.
#   Requirement: #4, "from decimal text; readers for ... its shortest text".
#   Proof: Laws.double_text, by computation.
law double_text:
  for +value: F32
  for text: String
  {Api.Double.show(Api.Double.from_f32(value)) == F32.show(value) : String} &
  {Api.Double.read(text) == Maybe.map(&2, F32, Api.Double, Api.Double.from_f32, F32.read(text)) : Maybe<&2, Api.Double>}

# 4. Attribute values
# ===================

# LAW standard_arrays
#   Claim: the standard constructors build an array of one primitive kind:
#     each string, Boolean, integer or double becomes that primitive's value,
#     in order, and an empty list an empty array.
#   Requirement: OTel, Common, Attribute: "an array of primitive type values
#     ... homogeneous"; spec #2, "Constructors for the specification's
#     standard values build homogeneous arrays of one primitive type".
#   Why: backends reliably accept these values and may refuse mixed arrays.
#   Proof: Laws.standard_arrays, by computation.
law standard_arrays:
  {Api.AttributeValue.strings(["a", "b"]) == Api.ArrayValue{[Api.StringValue{"a"}, Api.StringValue{"b"}]} : Api.AttributeValue} &
  {Api.AttributeValue.bools([True{}, False{}]) == Api.ArrayValue{[Api.BoolValue{True{}}, Api.BoolValue{False{}}]} : Api.AttributeValue} &
  {Api.AttributeValue.ints([Api.Int64.from_u32(1), Api.Int64.from_negated_nat(2n)]) ==
    Api.ArrayValue{[Api.IntValue{Api.Int64.from_u32(1)}, Api.IntValue{Api.Int64.from_negated_nat(2n)}]} : Api.AttributeValue} &
  {Api.AttributeValue.doubles([Api.Double.from_f32(1.5)]) ==
    Api.ArrayValue{[Api.DoubleValue{Api.Double.from_f32(1.5)}]} : Api.AttributeValue} &
  {Api.AttributeValue.strings(Nil{}) == Api.ArrayValue{Nil{}} : Api.AttributeValue}

# Whether every cell is a byte, from 0 to 255: an ordinary walk over the
# list, written independently of the package's own check.
def cells_fit(cells: List<&2, U32>) -> Bool:
  match cells:
    case Nil{}:
      True{}
    case Con{cell, rest}:
      Bool.and(U32.is_le(cell, 255), cells_fit(rest))

# LAW bytes_accepted
#   Claim: when every cell is a byte, the bytes constructor answers the bytes
#     value of exactly those cells.
#   Requirement: spec #2, "Bytes follow Base's byte convention, a list of
#     cells from 0 to 255".
#   Proof: Laws.bytes_accepted, via proofs/values.bend.
law bytes_accepted:
  for +cells: List<&2, U32>
  for fit: {cells_fit(cells) == True{} : Bool}
  {Api.AttributeValue.bytes(cells) == Some{Api.BytesValue{cells}} : Maybe<&2, Api.AttributeValue>}

# LAW bytes_refused
#   Claim: when a cell is not a byte, the bytes constructor answers None.
#   Requirement: spec #2, "a cell above 255 is refused by the constructor".
#   Why: an exporter encodes each cell as one byte; a larger cell would be
#     silently cut.
#   Proof: Laws.bytes_refused, via proofs/values.bend.
law bytes_refused:
  for +cells: List<&2, U32>
  for over: {cells_fit(cells) == False{} : Bool}
  {Api.AttributeValue.bytes(cells) == None{} : Maybe<&2, Api.AttributeValue>}

# LAW bytes_literal
#   Claim: the bytes constructor on literal cells: the extremes 0 and 255 are
#     accepted, 256 and the largest word are refused, and no cells are bytes.
#   Proof: Laws.bytes_literal, by computation.
law bytes_literal:
  {Api.AttributeValue.bytes([0, 127, 255]) == Some{Api.BytesValue{[0, 127, 255]}} : Maybe<&2, Api.AttributeValue>} &
  {Api.AttributeValue.bytes([256]) == None{} : Maybe<&2, Api.AttributeValue>} &
  {Api.AttributeValue.bytes([1, 4294967295]) == None{} : Maybe<&2, Api.AttributeValue>} &
  {Api.AttributeValue.bytes(Nil{}) == Some{Api.BytesValue{Nil{}}} : Maybe<&2, Api.AttributeValue>}

# 5. Attributes
# =============
#
# An attribute collection keeps insertion order and unique keys (spec #2,
# "Attribute values and attributes"). The laws state what set and get
# promise with no limit; section 6 adds the limits.

# Whether `key` is among `keys`: an ordinary search, comparing the key sought
# with each key of the list.
def key_among(+key: String, keys: List<&2, String>) -> Bool:
  match keys:
    case Nil{}:
      False{}
    case Con{other, rest}:
      Bool.or(String.eq(key, other), key_among(key, rest))

# No two keys are the same: no key appears among the keys after it.
def keys_distinct(keys: List<&2, String>) -> Bool:
  match keys:
    case Nil{}:
      True{}
    case Con{key, +rest}:
      Bool.and(Bool.not(key_among(key, rest)), keys_distinct(rest))

# LAW empty_attributes
#   Claim: the empty collection has no key, no attribute, nothing dropped,
#     and distinct keys.
#   Proof: Laws.empty_attributes, by computation.
law empty_attributes:
  for +key: String
  {Api.Attributes.get(Api.Attributes.empty(), key) == None{} : Maybe<&2, Api.AttributeValue>} &
  {Api.Attributes.count(Api.Attributes.empty()) == 0n : Nat} &
  {Api.Attributes.dropped(Api.Attributes.empty()) == 0n : Nat} &
  {keys_distinct(Api.Attributes.keys(Api.Attributes.empty())) == True{} : Bool}

# LAW set_get
#   Claim: after a key is set to a value, getting the key answers that value,
#     whatever the collection held before.
#   Requirement: OTel, Common, Attribute: "Setting an attribute with the same
#     key as an existing attribute SHOULD overwrite the existing attribute's
#     value"; #4, "set then get answers the value".
#   Why: instrumentation that sets `http.status_code` twice must export the
#     last value.
#   Proof: Laws.set_get, via proofs/attributes.bend.
law set_get:
  for attributes: Api.Attributes
  for +key: String
  for +value: Api.AttributeValue
  {Api.Attributes.get(Api.Attributes.set(attributes, key, value), key) == Some{value} : Maybe<&2, Api.AttributeValue>}

# LAW replace_keeps_count
#   Claim: setting a key the collection has keeps the count.
#   Requirement: #4, "replacing keeps the count and the position"; spec #2,
#     "setting an existing key replaces its value in place".
#   Why: with span limits, a replaced value must not consume the count of a
#     new attribute.
#   Reading: the hypothesis `present` says that the collection has the key.
#   Proof: Laws.replace_keeps_count, via proofs/attributes.bend.
law replace_keeps_count:
  for +attributes: Api.Attributes
  for +key: String
  for value: Api.AttributeValue
  for present: {Api.Attributes.has(attributes, key) == True{} : Bool}
  {Api.Attributes.count(Api.Attributes.set(attributes, key, value)) == Api.Attributes.count(attributes) : Nat}

# LAW replace_keeps_position
#   Claim: setting a key the collection has keeps every key in its place:
#     the list of keys is unchanged.
#   Requirement: as replace_keeps_count.
#   Why: an exporter writes attributes in insertion order; a replaced value
#     must not move its key to the end.
#   Proof: Laws.replace_keeps_position, via proofs/attributes.bend.
law replace_keeps_position:
  for +attributes: Api.Attributes
  for +key: String
  for value: Api.AttributeValue
  for present: {Api.Attributes.has(attributes, key) == True{} : Bool}
  {Api.Attributes.keys(Api.Attributes.set(attributes, key, value)) == Api.Attributes.keys(attributes) : List<&2, String>}

# LAW new_key_last
#   Claim: setting a key the collection does not have appends the attribute
#     after every other, and changes nothing else.
#   Requirement: spec #2, "An attribute collection keeps insertion order".
#   Reading: the hypothesis `absent` says that the collection lacks the key;
#     the list of attributes after the set is the list before followed by the
#     one new attribute.
#   Proof: Laws.new_key_last, via proofs/attributes.bend.
law new_key_last:
  for +attributes: Api.Attributes
  for +key: String
  for +value: Api.AttributeValue
  for absent: {Api.Attributes.has(attributes, key) == False{} : Bool}
  {Api.Attributes.to_list(Api.Attributes.set(attributes, key, value)) ==
    List.append(&2, Api.Attribute, Api.Attributes.to_list(attributes), [Api.Attribute{key, value}]) : List<&2, Api.Attribute>}

# LAW keys_unique
#   Claim: setting a key keeps the keys distinct: a collection built from the
#     empty one by sets never holds a key twice.
#   Requirement: OTel, Common, Attribute: "Attribute keys MUST be unique";
#     #4, "keys are unique".
#   Why: a backend that receives the same key twice may keep either value.
#   Reading: the hypothesis `distinct` says that the keys are distinct before
#     the set, as empty_attributes says of the empty collection; together
#     the two laws cover every collection the operations build.
#   Proof: Laws.keys_unique, via proofs/attributes.bend.
law keys_unique:
  for +attributes: Api.Attributes
  for +key: String
  for +value: Api.AttributeValue
  for distinct: {keys_distinct(Api.Attributes.keys(attributes)) == True{} : Bool}
  {keys_distinct(Api.Attributes.keys(Api.Attributes.set(attributes, key, value))) == True{} : Bool}

# LAW set_keeps_dropped
#   Claim: a set with no limit drops nothing: the dropped count is unchanged.
#   Proof: Laws.set_keeps_dropped, by cases on the collection.
law set_keeps_dropped:
  for +attributes: Api.Attributes
  for key: String
  for value: Api.AttributeValue
  {Api.Attributes.dropped(Api.Attributes.set(attributes, key, value)) == Api.Attributes.dropped(attributes) : Nat}

# LAW set_all_fold
#   Claim: setting several attributes sets them one by one, in order, and
#     setting none changes nothing.
#   Requirement: #4, "set several".
#   Why: a list of attributes behaves exactly as the same sets made one at a
#     time, so every law above applies to each of them.
#   Proof: Laws.set_all_fold, by computation.
law set_all_fold:
  for +attributes: Api.Attributes
  for key: String
  for value: Api.AttributeValue
  for rest: List<&2, Api.Attribute>
  {Api.Attributes.set_all(attributes, Con{Api.Attribute{key, value}, rest}) ==
    Api.Attributes.set_all(Api.Attributes.set(attributes, key, value), rest) : Api.Attributes} &
  {Api.Attributes.set_all(attributes, Nil{}) == attributes : Api.Attributes}

# 6. Span limits
# ==============
#
# Span limits bound what a span keeps (OTel, Trace SDK, Span limits; spec #2,
# "Span limits"). Attributes.set_within is the enforcement for attributes:
# an existing key is always replaced, a new key past the count is dropped
# and counted, and a string past the length limit is truncated.

# LAW default_limits
#   Claim: the default span limits are 128 attributes, 128 events, 128 links,
#     128 attributes per event and per link, and no length limit.
#   Requirement: OTel, Trace SDK, Span limits: the defaults of
#     AttributeCountLimit, EventCountLimit, LinkCountLimit,
#     AttributePerEventCountLimit and AttributePerLinkCountLimit are 128, and
#     AttributeValueLengthLimit has no limit by default.
#   Proof: Laws.default_limits, by computation.
law default_limits:
  {Api.SpanLimits.attribute_count(Api.SpanLimits.default()) == Some{128n} : Maybe<&2, Nat>} &
  {Api.SpanLimits.attribute_value_length(Api.SpanLimits.default()) == None{} : Maybe<&2, Nat>} &
  {Api.SpanLimits.event_count(Api.SpanLimits.default()) == Some{128n} : Maybe<&2, Nat>} &
  {Api.SpanLimits.link_count(Api.SpanLimits.default()) == Some{128n} : Maybe<&2, Nat>} &
  {Api.SpanLimits.attribute_per_event_count(Api.SpanLimits.default()) == Some{128n} : Maybe<&2, Nat>} &
  {Api.SpanLimits.attribute_per_link_count(Api.SpanLimits.default()) == Some{128n} : Maybe<&2, Nat>}

# LAW unlimited_limits
#   Claim: the unlimited span limits limit nothing, and neither do the
#     unlimited attribute limits.
#   Requirement: #4, "an unlimited form".
#   Proof: Laws.unlimited_limits, by computation.
law unlimited_limits:
  {Api.SpanLimits.attribute_count(Api.SpanLimits.unlimited()) == None{} : Maybe<&2, Nat>} &
  {Api.SpanLimits.attribute_value_length(Api.SpanLimits.unlimited()) == None{} : Maybe<&2, Nat>} &
  {Api.SpanLimits.event_count(Api.SpanLimits.unlimited()) == None{} : Maybe<&2, Nat>} &
  {Api.SpanLimits.link_count(Api.SpanLimits.unlimited()) == None{} : Maybe<&2, Nat>} &
  {Api.SpanLimits.attribute_per_event_count(Api.SpanLimits.unlimited()) == None{} : Maybe<&2, Nat>} &
  {Api.SpanLimits.attribute_per_link_count(Api.SpanLimits.unlimited()) == None{} : Maybe<&2, Nat>} &
  {Api.AttributeLimits.unlimited() == Api.AttributeLimits{None{}, None{}} : Api.AttributeLimits}

# LAW derived_limits
#   Claim: the attribute limits of a span, an event and a link take their
#     count from the span's attribute count, the count per event and the
#     count per link, and all three share the value length limit.
#   Requirement: OTel, Trace SDK, Span limits: AttributeValueLengthLimit
#     applies to span, event and link attributes alike, and the counts per
#     event and per link are separate limits.
#   Proof: Laws.derived_limits, by cases on the limits.
law derived_limits:
  for +limits: Api.SpanLimits
  {Api.SpanLimits.span_attributes(limits) ==
    Api.AttributeLimits{Api.SpanLimits.attribute_count(limits), Api.SpanLimits.attribute_value_length(limits)} : Api.AttributeLimits} &
  {Api.SpanLimits.event_attributes(limits) ==
    Api.AttributeLimits{Api.SpanLimits.attribute_per_event_count(limits), Api.SpanLimits.attribute_value_length(limits)} : Api.AttributeLimits} &
  {Api.SpanLimits.link_attributes(limits) ==
    Api.AttributeLimits{Api.SpanLimits.attribute_per_link_count(limits), Api.SpanLimits.attribute_value_length(limits)} : Api.AttributeLimits}

# LAW within_replaces
#   Claim: under any limits, setting a key the collection has is a plain set
#     of the value cut to the length limit: the count does not matter.
#   Requirement: spec #2, "an existing key is always replaced"; OTel, Trace
#     SDK, Span limits: the count limit applies to new attributes.
#   Why: an attribute the span already has must take its new value even
#     when the span is full.
#   Proof: Laws.within_replaces, by rewriting the hypothesis into the
#     enforcement's check.
law within_replaces:
  for +limits: Api.AttributeLimits
  for +attributes: Api.Attributes
  for +key: String
  for +value: Api.AttributeValue
  for present: {Api.Attributes.has(attributes, key) == True{} : Bool}
  {Api.Attributes.set_within(limits, attributes, key, value) ==
    Api.Attributes.set(attributes, key, Api.AttributeValue.truncate(Api.AttributeLimits.length(limits), value)) : Api.Attributes}

# LAW within_unlimited_count
#   Claim: without a count limit, setting under limits is a plain set of the
#     value cut to the length limit, whether or not the key is present.
#   Requirement: #4, "an unlimited form".
#   Proof: Laws.within_unlimited_count, via proofs/limits.bend.
law within_unlimited_count:
  for +length: Maybe<&2, Nat>
  for +attributes: Api.Attributes
  for +key: String
  for +value: Api.AttributeValue
  {Api.Attributes.set_within(Api.AttributeLimits{None{}, length}, attributes, key, value) ==
    Api.Attributes.set(attributes, key, Api.AttributeValue.truncate(length, value)) : Api.Attributes}

# LAW within_adds
#   Claim: while the count is below the limit, setting a new key under limits
#     is a plain set of the value cut to the length limit: the attribute is
#     appended last.
#   Requirement: OTel, Trace SDK, Span limits: attributes are kept until the
#     count limit is reached.
#   Reading: `absent` says the collection lacks the key and `room` that it
#     holds fewer attributes than the limit.
#   Proof: Laws.within_adds, by rewriting both hypotheses into the
#     enforcement's checks.
law within_adds:
  for +limit: Nat
  for +length: Maybe<&2, Nat>
  for +attributes: Api.Attributes
  for +key: String
  for +value: Api.AttributeValue
  for absent: {Api.Attributes.has(attributes, key) == False{} : Bool}
  for room: {Nat.is_lt(Api.Attributes.count(attributes), limit) == True{} : Bool}
  {Api.Attributes.set_within(Api.AttributeLimits{Some{limit}, length}, attributes, key, value) ==
    Api.Attributes.set(attributes, key, Api.AttributeValue.truncate(length, value)) : Api.Attributes}

# LAW within_drops
#   Claim: once the count has reached the limit, setting a new key under
#     limits keeps the attributes as they are and counts one more dropped
#     attribute.
#   Requirement: OTel, Trace SDK, Span limits: "the SDK MUST discard
#     attributes beyond the limit" and the span records the dropped count;
#     #4, "the dropped counter increments once per drop".
#   Why: memory stays bounded while a span is open, and the export tells the
#     operator how much was lost.
#   Proof: Laws.within_drops, by rewriting both hypotheses into the
#     enforcement's checks.
law within_drops:
  for +limit: Nat
  for +length: Maybe<&2, Nat>
  for +attributes: Api.Attributes
  for +key: String
  for +value: Api.AttributeValue
  for absent: {Api.Attributes.has(attributes, key) == False{} : Bool}
  for full: {Nat.is_lt(Api.Attributes.count(attributes), limit) == False{} : Bool}
  {Api.Attributes.to_list(Api.Attributes.set_within(Api.AttributeLimits{Some{limit}, length}, attributes, key, value)) ==
    Api.Attributes.to_list(attributes) : List<&2, Api.Attribute>} &
  {Api.Attributes.dropped(Api.Attributes.set_within(Api.AttributeLimits{Some{limit}, length}, attributes, key, value)) ==
    1n+Api.Attributes.dropped(attributes) : Nat}

# LAW within_bounded
#   Claim: a collection within its count limit stays within it after any set
#     under that limit: the count never exceeds the limit.
#   Requirement: #4, "the count never exceeds the limit".
#   Reading: `bound` says the count is at most the limit before the set;
#     together with empty_attributes, every collection built by sets under
#     the limit stays at most the limit.
#   Proof: Laws.within_bounded, via proofs/limits.bend.
law within_bounded:
  for +limit: Nat
  for +length: Maybe<&2, Nat>
  for +attributes: Api.Attributes
  for +key: String
  for +value: Api.AttributeValue
  for bound: {Nat.is_le(Api.Attributes.count(attributes), limit) == True{} : Bool}
  {Nat.is_le(Api.Attributes.count(Api.Attributes.set_within(Api.AttributeLimits{Some{limit}, length}, attributes, key, value)), limit) ==
    True{} : Bool}

# Four attributes set in order under a limit of two attributes and three
# characters: "a" is cut, "b" fits, "c" is dropped, and "a" is replaced in
# place with its value cut.
def limited_example() -> Api.Attributes:
  Api.Attributes.set_all_within(Api.AttributeLimits{Some{2n}, Some{3n}}, Api.Attributes.empty(),
    [Api.Attribute{"a", Api.StringValue{"hello"}}, Api.Attribute{"b", Api.StringValue{"hi"}},
     Api.Attribute{"c", Api.StringValue{"x"}}, Api.Attribute{"a", Api.StringValue{"world"}}])

# LAW within_literal
#   Claim: limits at work on literal attributes: the collection keeps "a"
#     and "b" in order, "a" with its last value cut to three characters, and
#     counts the one attribute it dropped.
#   Proof: Laws.within_literal, by computation.
law within_literal:
  {Api.Attributes.to_list(limited_example()) ==
    [Api.Attribute{"a", Api.StringValue{"wor"}}, Api.Attribute{"b", Api.StringValue{"hi"}}] : List<&2, Api.Attribute>} &
  {Api.Attributes.dropped(limited_example()) == 1n : Nat}

# LAW set_all_within_fold
#   Claim: setting several attributes under limits sets them one by one, in
#     order, under the same limits, and setting none changes nothing.
#   Proof: Laws.set_all_within_fold, by computation.
law set_all_within_fold:
  for +limits: Api.AttributeLimits
  for +attributes: Api.Attributes
  for key: String
  for value: Api.AttributeValue
  for rest: List<&2, Api.Attribute>
  {Api.Attributes.set_all_within(limits, attributes, Con{Api.Attribute{key, value}, rest}) ==
    Api.Attributes.set_all_within(limits, Api.Attributes.set_within(limits, attributes, key, value), rest) : Api.Attributes} &
  {Api.Attributes.set_all_within(limits, attributes, Nil{}) == attributes : Api.Attributes}

# LAW truncate_none
#   Claim: without a length limit, no value is changed.
#   Requirement: OTel, Trace SDK, Span limits: AttributeValueLengthLimit has
#     no limit by default.
#   Proof: Laws.truncate_none, by computation.
law truncate_none:
  for +value: Api.AttributeValue
  {Api.AttributeValue.truncate(None{}, value) == value : Api.AttributeValue}

# The number of characters of a string value's text, and 0 for any other
# value: the observer through which truncation's length is stated.
def string_length(value: Api.AttributeValue) -> Nat:
  match value:
    case Api.StringValue{text}:
      String.length(text)
    case other:
      0n

# LAW truncate_string
#   Claim: a string longer than the limit is cut to its first `limit`
#     characters, so that truncation yields exactly the limit's length.
#   Requirement: OTel, Trace SDK, Span limits: "Any string attribute value
#     ... longer than the limit MUST be truncated to the limit"; #4,
#     "truncation yields the limit's length".
#   Reading: `longer` says the text has more characters than the limit.
#   Proof: Laws.truncate_string, via proofs/values.bend.
law truncate_string:
  for +limit: Nat
  for +text: String
  for +longer: {Nat.is_lt(limit, String.length(text)) == True{} : Bool}
  {Api.AttributeValue.truncate(Some{limit}, Api.StringValue{text}) == Api.StringValue{String.take(text, limit)} : Api.AttributeValue} &
  {string_length(Api.AttributeValue.truncate(Some{limit}, Api.StringValue{text})) == limit : Nat}

# LAW truncate_keeps_short
#   Claim: a string within the limit is kept whole.
#   Requirement: as truncate_string: only a longer string is cut.
#   Proof: Laws.truncate_keeps_short, via proofs/values.bend.
law truncate_keeps_short:
  for +limit: Nat
  for +text: String
  for fits: {Nat.is_lt(limit, String.length(text)) == False{} : Bool}
  {Api.AttributeValue.truncate(Some{limit}, Api.StringValue{text}) == Api.StringValue{text} : Api.AttributeValue}

# LAW truncate_literal
#   Claim: truncation on literal values: each string of an array is cut and
#     the others kept, an array of mixed values has only its strings cut, an
#     integer is untouched, and a limit of zero leaves an empty string.
#   Requirement: OTel, Trace SDK, Span limits: "any string element of an
#     array attribute value ... MUST be truncated"; other values are not
#     subject to the limit.
#   Proof: Laws.truncate_literal, by computation.
law truncate_literal:
  {Api.AttributeValue.truncate(Some{2n}, Api.AttributeValue.strings(["abc", "de", "f"])) ==
    Api.AttributeValue.strings(["ab", "de", "f"]) : Api.AttributeValue} &
  {Api.AttributeValue.truncate(Some{1n}, Api.ArrayValue{[Api.StringValue{"ab"}, Api.BoolValue{True{}}]}) ==
    Api.ArrayValue{[Api.StringValue{"a"}, Api.BoolValue{True{}}]} : Api.AttributeValue} &
  {Api.AttributeValue.truncate(Some{2n}, Api.IntValue{Api.Int64.from_u32(12345)}) ==
    Api.IntValue{Api.Int64.from_u32(12345)} : Api.AttributeValue} &
  {Api.AttributeValue.truncate(Some{0n}, Api.StringValue{"x"}) == Api.StringValue{""} : Api.AttributeValue}

# 7. Timestamps
# =============
#
# A timestamp is whole seconds since the Unix epoch and a nanosecond
# remainder below one second (spec #2, "Timestamp"). The nanosecond
# arithmetic is on U32, which the checker computes, so the normalization is
# stated on literal cases; the readers and the millisecond constructor are
# universal.

# LAW timestamp_readers
#   Claim: when the nanoseconds given are below one second, the readers give
#     back the seconds and the nanoseconds given.
#   Requirement: #4, "round trips of the readers".
#   Reading: `below` says the nanoseconds are below 1000000000; with
#     timestamp_normalized, the other case.
#   Proof: Laws.timestamp_readers, via proofs/timestamps.bend.
law timestamp_readers:
  for +seconds: Nat
  for +nanoseconds: U32
  for +below: {U32.is_lt(nanoseconds, 1000000000) == True{} : Bool}
  {Api.Timestamp.seconds(Api.Timestamp.from_unix(seconds, nanoseconds)) == seconds : Nat} &
  {Api.Timestamp.nanoseconds(Api.Timestamp.from_unix(seconds, nanoseconds)) == nanoseconds : U32}

# LAW timestamp_milliseconds
#   Claim: the timestamp of milliseconds is the timestamp of their whole
#     seconds and of their remainder as nanoseconds.
#   Requirement: #4, "the millisecond constructor equals the split into
#     seconds and nanoseconds"; CONTEXT.md, Timestamp: "at least millisecond
#     precision".
#   Why: the SDK's clock and the API's events count milliseconds; both must
#     land on the same instant as a timestamp given in seconds.
#   Proof: Laws.timestamp_milliseconds, by computation.
law timestamp_milliseconds:
  for +milliseconds: Nat
  {Api.Timestamp.from_milliseconds(milliseconds) ==
    Api.Timestamp.from_unix(Nat.div(milliseconds, 1000n), U32.mul(U32.from_nat(Nat.mod(milliseconds, 1000n)), 1000000)) : Api.Timestamp}

# LAW timestamp_normalized
#   Claim: nanoseconds of a second or more are carried into the seconds, on
#     literal cases: one and a half seconds, exactly one second, the largest
#     U32 (four seconds and a remainder) and the largest remainder that stays.
#   Requirement: #4, "normalizing a remainder of a second or more" and
#     "normalization leaves nanoseconds below one second".
#   Why: an exporter writes the nanoseconds as nine digits after the seconds;
#     a remainder of a second or more would corrupt the instant.
#   Proof: Laws.timestamp_normalized, by computation.
law timestamp_normalized:
  {Api.Timestamp.from_unix(1n, 1500000000) == Api.Timestamp.from_unix(2n, 500000000) : Api.Timestamp} &
  {Api.Timestamp.from_unix(1n, 1000000000) == Api.Timestamp.from_unix(2n, 0) : Api.Timestamp} &
  {Api.Timestamp.seconds(Api.Timestamp.from_unix(0n, 4294967295)) == 4n : Nat} &
  {Api.Timestamp.nanoseconds(Api.Timestamp.from_unix(0n, 4294967295)) == 294967295 : U32} &
  {Api.Timestamp.nanoseconds(Api.Timestamp.from_unix(7n, 999999999)) == 999999999 : U32}

# LAW timestamp_milliseconds_literal
#   Claim: milliseconds round-trip through the readers on literal cases, and
#     the nanoseconds below a millisecond are dropped by the millisecond
#     reader.
#   Requirement: #4, "round trips of the readers".
#   Proof: Laws.timestamp_milliseconds_literal, by computation.
law timestamp_milliseconds_literal:
  {Api.Timestamp.milliseconds(Api.Timestamp.from_milliseconds(1500n)) == 1500n : Nat} &
  {Api.Timestamp.seconds(Api.Timestamp.from_milliseconds(1500n)) == 1n : Nat} &
  {Api.Timestamp.nanoseconds(Api.Timestamp.from_milliseconds(1500n)) == 500000000 : U32} &
  {Api.Timestamp.milliseconds(Api.Timestamp.from_unix(1n, 999999999)) == 1999n : Nat}

# LAW timestamp_self
#   Claim: every timestamp is the same instant as itself.
#   Requirement: #4, "comparison".
#   Proof: Laws.timestamp_self, via proofs/timestamps.bend, from the
#     reflexivity of Nat.cmp and Word.cmp.
law timestamp_self:
  for +timestamp: Api.Timestamp
  {Api.Timestamp.cmp(timestamp, timestamp) == EQ{} : Cmp} &
  {Api.Timestamp.is_eq(timestamp, timestamp) == True{} : Bool}

# LAW timestamp_order
#   Claim: timestamps order by seconds, then by nanoseconds, on literal cases:
#     the same second orders by nanoseconds, a later second is later whatever
#     the nanoseconds, a millisecond timestamp meets one given in seconds,
#     and two spellings of one instant are the same instant.
#   Requirement: #4, "comparison".
#   Proof: Laws.timestamp_order, by computation.
law timestamp_order:
  {Api.Timestamp.cmp(Api.Timestamp.from_unix(1n, 5), Api.Timestamp.from_unix(1n, 6)) == LT{} : Cmp} &
  {Api.Timestamp.cmp(Api.Timestamp.from_unix(2n, 0), Api.Timestamp.from_unix(1n, 999999999)) == GT{} : Cmp} &
  {Api.Timestamp.is_lt(Api.Timestamp.from_milliseconds(1000n), Api.Timestamp.from_unix(1n, 1)) == True{} : Bool} &
  {Api.Timestamp.is_eq(Api.Timestamp.from_unix(1n, 1000000000), Api.Timestamp.from_unix(2n, 0)) == True{} : Bool} &
  {Api.Timestamp.is_ge(Api.Timestamp.from_unix(2n, 0), Api.Timestamp.from_unix(1n, 999999999)) == True{} : Bool} &
  {Api.Timestamp.is_ne(Api.Timestamp.from_unix(1n, 5), Api.Timestamp.from_unix(1n, 6)) == True{} : Bool}

# 8. Span context
# ===============
#
# A span context wraps bend-trace-context's incoming or outgoing context
# (#5). Its trace flags and the remote span context built from parts (#10)
# rest on the pieces that bend-trace-context 0.2.0 added: the flags readers
# of its contexts, a remote context from identifiers and an incoming context
# from a remote context and a tracestate. These laws are universal: the
# proofs open the variant, and the readers compute from the wrapped context;
# the laws on flags are proved by cases on the two flags.

# LAW span_context_remote
#   Claim: a span context built from an incoming context is remote, wraps
#     that incoming context and wraps no outgoing one.
#   Requirement: #5, "the variant tells remote from local".
#   Why: a propagator forwards a received context and never sends it as this
#     participant's own operation; the variant is what tells it.
#   Proof: Laws.span_context_remote, by computation.
law span_context_remote:
  for incoming: TC.IncomingContext
  {Api.SpanContext.is_remote(Api.SpanContext.remote(incoming)) == True{} : Bool} &
  {Api.SpanContext.incoming(Api.SpanContext.remote(incoming)) == Some{incoming} :
    Maybe<&2, TC.IncomingContext>} &
  {Api.SpanContext.outgoing(Api.SpanContext.remote(incoming)) == None{} :
    Maybe<&2, TC.OutgoingContext>}

# LAW span_context_local
#   Claim: a span context built from an outgoing context is local, wraps
#     that outgoing context and wraps no incoming one.
#   Requirement: #5, "the variant tells remote from local".
#   Proof: Laws.span_context_local, by computation.
law span_context_local:
  for outgoing: TC.OutgoingContext
  {Api.SpanContext.is_remote(Api.SpanContext.local(outgoing)) == False{} : Bool} &
  {Api.SpanContext.outgoing(Api.SpanContext.local(outgoing)) == Some{outgoing} :
    Maybe<&2, TC.OutgoingContext>} &
  {Api.SpanContext.incoming(Api.SpanContext.local(outgoing)) == None{} :
    Maybe<&2, TC.IncomingContext>}

# LAW remote_readers
#   Claim: each reader of a remote span context agrees with the field of the
#     wrapped incoming context: the sender's trace, operation and sampled
#     indication, and the tracestate received with them.
#   Requirement: #5, "each reader agrees with the wrapped context's field".
#   Why: a child span continues the trace the sender named, and an exporter
#     writes those identifiers unchanged.
#   Proof: Laws.remote_readers, by computation.
law remote_readers:
  for incoming: TC.IncomingContext
  {Api.SpanContext.trace_id(Api.SpanContext.remote(incoming)) ==
    TC.RemoteContext.trace_id(TC.IncomingContext.context(incoming)) : TC.TraceId} &
  {Api.SpanContext.span_id(Api.SpanContext.remote(incoming)) ==
    TC.RemoteContext.span_id(TC.IncomingContext.context(incoming)) : TC.SpanId} &
  {Api.SpanContext.is_sampled(Api.SpanContext.remote(incoming)) ==
    TC.RemoteContext.is_sampled(TC.IncomingContext.context(incoming)) : Bool} &
  {Api.SpanContext.tracestate(Api.SpanContext.remote(incoming)) ==
    TC.IncomingContext.state(incoming) : TC.TraceState}

# LAW local_readers
#   Claim: each reader of a local span context agrees with the field of the
#     wrapped outgoing context: this participant's trace, operation and
#     sampled indication, and the tracestate it sends.
#   Requirement: #5, "each reader agrees with the wrapped context's field".
#   Proof: Laws.local_readers, by computation.
law local_readers:
  for outgoing: TC.OutgoingContext
  {Api.SpanContext.trace_id(Api.SpanContext.local(outgoing)) ==
    TC.LocalContext.trace_id(TC.OutgoingContext.context(outgoing)) : TC.TraceId} &
  {Api.SpanContext.span_id(Api.SpanContext.local(outgoing)) ==
    TC.LocalContext.span_id(TC.OutgoingContext.context(outgoing)) : TC.SpanId} &
  {Api.SpanContext.is_sampled(Api.SpanContext.local(outgoing)) ==
    TC.LocalContext.is_sampled(TC.OutgoingContext.context(outgoing)) : Bool} &
  {Api.SpanContext.tracestate(Api.SpanContext.local(outgoing)) ==
    TC.OutgoingContext.state(outgoing) : TC.TraceState}

# LAW hex_readers
#   Claim: the hexadecimal readers are the lowercase digits of the
#     identifiers that the value readers answer, for either variant.
#   Requirement: #5, "trace ID and span ID as bend-trace-context values and
#     as lowercase hex"; OTel Trace API, SpanContext: the identifiers are
#     also read as lowercase hexadecimal text.
#   Proof: Laws.hex_readers, by computation.
law hex_readers:
  for context: Api.SpanContext
  {Api.SpanContext.trace_id_hex(context) ==
    TC.TraceId.to_string(Api.SpanContext.trace_id(context)) : String} &
  {Api.SpanContext.span_id_hex(context) ==
    TC.SpanId.to_string(Api.SpanContext.span_id(context)) : String}

# LAW wrapped_flags
#   Claim: the trace flags of a span context are the flags of the wrapped
#     context, for either variant: those of the remote context an incoming
#     context carries, and those of the local context an outgoing one
#     carries.
#   Requirement: #10, "the trace flags reader ... equals the wrapped
#     context's flags for both variants"; spec #2, "trace flags as a number
#     from 0 to 3".
#   Why: an SDK and a propagator read the flags of a span context and of
#     the bend-trace-context value it wraps interchangeably.
#   Proof: Laws.wrapped_flags, by computation.
law wrapped_flags:
  for incoming: TC.IncomingContext
  for outgoing: TC.OutgoingContext
  {Api.SpanContext.trace_flags(Api.SpanContext.remote(incoming)) ==
    TC.RemoteContext.flags(TC.IncomingContext.context(incoming)) : U32} &
  {Api.SpanContext.trace_flags(Api.SpanContext.local(outgoing)) ==
    TC.LocalContext.flags(TC.OutgoingContext.context(outgoing)) : U32}

# The trace flags of a sampled indication and a randomness assertion as a
# number: 0, 1 (sampled), 2 (random) or 3 (both), the values of the flag
# bytes 00 to 03 of a traceparent. It is written out literally, as
# bend-trace-context's own laws write it, so that the laws below compare the
# package's number with these four values rather than with bit operations.
def known_flags(sampled: Bool, random: Bool) -> U32:
  match sampled random:
    case False{} False{}:
      0
    case True{} False{}:
      1
    case False{} True{}:
      2
    case True{} True{}:
      3

# LAW local_flags
#   Claim: the trace flags of a local span context are its known flags as a
#     number from 0 to 3, the sampled indication in bit 0 and the trace ID's
#     randomness assertion in bit 1, and they are the flags of the
#     traceparent it emits: the sampled and random-trace-id bits that the
#     codec reads back from that traceparent.
#   Requirement: #10, "flags of a local span context equal the flags of the
#     traceparent it emits"; W3C 3.2.2.5: sampled is bit 0 of the flags and
#     random-trace-id bit 1; OTel, OTLP: Span.flags carries the W3C trace
#     flags in its low byte.
#   Why: an exporter writes the flags into the span it exports while the
#     traceparent carries the same operation to the next service; if they
#     differed, the exported span and the propagated context would disagree.
#   Reading: known_flags gives the number of each pair of flags literally.
#     The second equation reads the two flags back from the emitted
#     traceparent with bend-trace-context's codec readers; its reserved bits
#     are zero, so the number is the value of its whole flag byte.
#   Proof: Laws.local_flags, by cases on both flags.
law local_flags:
  for outgoing: TC.OutgoingContext
  {Api.SpanContext.trace_flags(Api.SpanContext.local(outgoing)) ==
    known_flags(Api.SpanContext.is_sampled(Api.SpanContext.local(outgoing)),
      TC.TraceId.is_random(Api.SpanContext.trace_id(Api.SpanContext.local(outgoing)))) : U32} &
  {Api.SpanContext.trace_flags(Api.SpanContext.local(outgoing)) ==
    known_flags(TC.TraceParentV00.is_sampled(TC.LocalContext.to_traceparent(TC.OutgoingContext.context(outgoing))),
      TC.TraceParentV00.is_random(TC.LocalContext.to_traceparent(TC.OutgoingContext.context(outgoing)))) : U32}

# LAW remote_flags
#   Claim: the trace flags of a remote span context are its known flags as a
#     number from 0 to 3: the sampled indication in bit 0 and the trace ID's
#     randomness assertion in bit 1, however the span context was made,
#     extracted from a message or built from parts.
#   Requirement: #10, "flags of a remote one equal its known flags"; spec #2,
#     "trace flags as a number from 0 to 3"; W3C 3.2.2.5.
#   Why: an SDK exports a remote parent, and a link to a remote span context,
#     with the flags the sender sent; the Booleans stay the canonical form,
#     and the number says no more than they do.
#   Proof: Laws.remote_flags, by cases on both flags.
law remote_flags:
  for incoming: TC.IncomingContext
  {Api.SpanContext.trace_flags(Api.SpanContext.remote(incoming)) ==
    known_flags(Api.SpanContext.is_sampled(Api.SpanContext.remote(incoming)),
      TC.TraceId.is_random(Api.SpanContext.trace_id(Api.SpanContext.remote(incoming)))) : U32}

# LAW flags_bounded
#   Claim: the trace flags of every span context are at most 3: the six
#     reserved bits of the flag byte are never among them.
#   Requirement: spec #2, "trace flags as a number from 0 to 3"; W3C
#     3.2.2.5.3: a participant sets the flags it does not know to zero.
#   Why: an exporter that writes the number into OTLP's Span.flags claims a
#     meaning for every bit it sets; a bit this API does not know would claim
#     one it does not implement.
#   Proof: Laws.flags_bounded, by cases on the variant and on both flags.
law flags_bounded:
  for context: Api.SpanContext
  {U32.is_le(Api.SpanContext.trace_flags(context), 3) == True{} : Bool}

# LAW parts_readers
#   Claim: a remote span context built from parts is remote, its readers
#     answer the parts it was built from, the trace ID, the span ID, the
#     sampled indication and the tracestate, kept as they are, and it wraps
#     the incoming context that bend-trace-context builds from a remote
#     context from those identifiers and the tracestate.
#   Requirement: spec #2, "A remote span context can be built from a trace
#     ID, a span ID, a sampled indication and a tracestate, through
#     bend-trace-context's constructors from parts, for links and for
#     propagators of other formats"; #10, "the readers of a span context
#     built from parts answer the parts".
#   Why: a link to a span of another trace, or a propagator of another
#     format, names exactly the operation whose identifiers it was given; a
#     constructor that rewrote them would name another.
#   Proof: Laws.parts_readers, by computation.
law parts_readers:
  for trace_id: TC.TraceId
  for span_id: TC.SpanId
  for sampled: Bool
  for state: TC.TraceState
  {Api.SpanContext.is_remote(Api.SpanContext.remote_from_parts(trace_id, span_id, sampled, state)) == True{} : Bool} &
  {Api.SpanContext.trace_id(Api.SpanContext.remote_from_parts(trace_id, span_id, sampled, state)) == trace_id : TC.TraceId} &
  {Api.SpanContext.span_id(Api.SpanContext.remote_from_parts(trace_id, span_id, sampled, state)) == span_id : TC.SpanId} &
  {Api.SpanContext.is_sampled(Api.SpanContext.remote_from_parts(trace_id, span_id, sampled, state)) == sampled : Bool} &
  {Api.SpanContext.tracestate(Api.SpanContext.remote_from_parts(trace_id, span_id, sampled, state)) == state : TC.TraceState} &
  {Api.SpanContext.incoming(Api.SpanContext.remote_from_parts(trace_id, span_id, sampled, state)) ==
    Some{TC.IncomingContext.from_remote(TC.RemoteContext.from_ids(trace_id, span_id, sampled), state)} :
    Maybe<&2, TC.IncomingContext>}

# LAW parts_flags
#   Claim: the trace flags of a remote span context built from parts are the
#     known flags of its parts: the sampled indication it was given in bit 0,
#     and in bit 1 the trace ID's own randomness assertion, which a parsed
#     identifier lacks unless the caller asserts it.
#   Requirement: as parts_readers; W3C 3.2.2.5.2: only a participant that
#     knows a trace ID to be random asserts random-trace-id for it.
#   Why: a constructor that set random-trace-id by itself would assert what
#     nobody asserted, and a sampler that trusts the flag would read
#     randomness into identifiers that have none.
#   Proof: Laws.parts_flags, by cases on both flags.
law parts_flags:
  for trace_id: TC.TraceId
  for span_id: TC.SpanId
  for sampled: Bool
  for state: TC.TraceState
  {Api.SpanContext.trace_flags(Api.SpanContext.remote_from_parts(trace_id, span_id, sampled, state)) ==
    known_flags(sampled, TC.TraceId.is_random(trace_id)) : U32}

# What a propagator finds to forward in a span context: the received pair of
# the incoming context a remote span context wraps, and None{} for a local
# span context, which was received in no message.
def received_pair(found: Maybe<&2, TC.IncomingContext>) -> Maybe<&2, TC.ReceivedPair>:
  match found:
    case Some{incoming}:
      TC.IncomingContext.received(incoming)
    case None{}:
      None{}

# What forwarding a span context into a carrier answers: bend-trace-context's
# answer for the incoming context a remote span context wraps, and None{} for
# a local span context, which has nothing received to forward.
def forwarded(limits: TC.Limits, found: Maybe<&2, TC.IncomingContext>, carrier: List<&2, TC.Header>) ->
  Maybe<&2, Result<&2, &2, TC.ForwardError, List<&2, TC.Header>>>:
  match found:
    case Some{incoming}:
      Some{TC.Context.forward(limits, incoming, carrier)}
    case None{}:
      None{}

# LAW parts_not_forwarded
#   Claim: a remote span context built from parts keeps no received pair,
#     and forwarding it through bend-trace-context answers nothing to
#     forward, whatever the parts, the limits and the carrier.
#   Requirement: spec #2, "It has no received pair and cannot be forwarded
#     as if it had arrived in a message"; W3C 3.4: only a received pair is
#     forwarded unchanged.
#   Why: a relay must never send a traceparent written again from parts with
#     a tracestate of its choosing; a service that holds a span context built
#     from parts continues it with a child or injects its own operation.
#   Reading: received_pair and forwarded, above, apply bend-trace-context's
#     readers and forwarding to the incoming context a span context wraps.
#   Proof: Laws.parts_not_forwarded, by computation.
law parts_not_forwarded:
  for trace_id: TC.TraceId
  for span_id: TC.SpanId
  for sampled: Bool
  for state: TC.TraceState
  for limits: TC.Limits
  for carrier: List<&2, TC.Header>
  {received_pair(Api.SpanContext.incoming(Api.SpanContext.remote_from_parts(trace_id, span_id, sampled, state))) ==
    None{} : Maybe<&2, TC.ReceivedPair>} &
  {forwarded(limits, Api.SpanContext.incoming(Api.SpanContext.remote_from_parts(trace_id, span_id, sampled, state)),
    carrier) == Some{Fail{TC.NothingToForward{}}} : Maybe<&2, Result<&2, &2, TC.ForwardError, List<&2, TC.Header>>>}

# 9. Context
# ==========
#
# The context is a closed record over an optional span context (#5). The
# proofs open the record: the laws hold whatever it held before.

# LAW context_set_then_read
#   Claim: reading a context after setting a span context answers that span
#     context, whatever the context held before.
#   Requirement: #5, "read after set answers the span context".
#   Why: a span started from the context takes that span context as its
#     parent, and no other.
#   Proof: Laws.context_set_then_read, by opening the record.
law context_set_then_read:
  for context: Api.Context
  for span_context: Api.SpanContext
  {Api.Context.span_context(Api.Context.set_span_context(context, span_context)) ==
    Some{span_context} : Maybe<&2, Api.SpanContext>}

# LAW context_empty
#   Claim: the empty context holds no span context.
#   Requirement: #5, "the empty context and a cleared context read none".
#   Why: a span started from the empty context begins a new trace.
#   Proof: Laws.context_empty, by computation.
law context_empty:
  {Api.Context.span_context(Api.Context.empty()) == None{} : Maybe<&2, Api.SpanContext>}

# LAW context_cleared
#   Claim: a cleared context holds no span context, whatever it held before.
#   Requirement: #5, "the empty context and a cleared context read none".
#   Proof: Laws.context_cleared, by opening the record.
law context_cleared:
  for context: Api.Context
  {Api.Context.span_context(Api.Context.clear_span_context(context)) == None{} :
    Maybe<&2, Api.SpanContext>}

# 10. Instrumentation scope
# =========================
#
# The instrumentation scope is a record of the name, the optional version,
# the optional schema URL and the attributes of the instrumentation that
# created a span (#6). Its constructor builds it; the readers answer the
# fields.

# LAW scope_readers
#   Claim: each reader of an instrumentation scope answers the field it was
#     built with.
#   Requirement: OTel Trace API, Get a Tracer: the scope is the name, the
#     version, the schema URL and the attributes of the instrumentation; #6,
#     "the instrumentation scope record (name, optional version, optional
#     schema URL, attributes)".
#   Why: an exporter writes the scope beside every span of a tracer; a
#     reader that answered another field would misname the instrumentation.
#   Proof: Laws.scope_readers, by computation.
law scope_readers:
  for +name: String
  for +version: Maybe<&2, String>
  for +schema_url: Maybe<&2, String>
  for +attributes: Api.Attributes
  {Api.InstrumentationScope.name(Api.InstrumentationScope{name, version, schema_url, attributes}) == name : String} &
  {Api.InstrumentationScope.version(Api.InstrumentationScope{name, version, schema_url, attributes}) == version : Maybe<&2, String>} &
  {Api.InstrumentationScope.schema_url(Api.InstrumentationScope{name, version, schema_url, attributes}) == schema_url : Maybe<&2, String>} &
  {Api.InstrumentationScope.attributes(Api.InstrumentationScope{name, version, schema_url, attributes}) == attributes : Api.Attributes}

# 11. Span options
# ================
#
# The start options are a closed record (#6): the kind, the initial
# attributes and links, an optional start timestamp and the root indication.
# The proofs open the record: the laws hold whatever it held before.

# LAW default_options
#   Claim: the default options ask for an internal span with no initial
#     attributes or links, no start timestamp, and a parent taken from the
#     context.
#   Requirement: OTel Trace API, Span creation: the kind defaults to
#     INTERNAL, and a span is a child of the context's span unless the caller
#     asks for a root; spec #2, "kind (internal by default) ... a root
#     indication that ignores the parent in the context".
#   Proof: Laws.default_options, by computation.
law default_options:
  {Api.SpanOptions.kind(Api.SpanOptions.default()) == Api.Internal{} : Api.SpanKind} &
  {Api.SpanOptions.attributes(Api.SpanOptions.default()) == Nil{} : List<&2, Api.Attribute>} &
  {Api.SpanOptions.links(Api.SpanOptions.default()) == Nil{} : List<&2, Api.Link>} &
  {Api.SpanOptions.start_timestamp(Api.SpanOptions.default()) == None{} : Maybe<&2, Api.Timestamp>} &
  {Api.SpanOptions.is_root(Api.SpanOptions.default()) == False{} : Bool}

# LAW options_set_then_read
#   Claim: an option set on any options is what its reader answers.
#   Requirement: #6, "Start options: kind (internal by default), initial
#     attributes, links, an optional start timestamp and a root indication".
#   Proof: Laws.options_set_then_read, by opening the record.
law options_set_then_read:
  for +options: Api.SpanOptions
  for kind: Api.SpanKind
  for attributes: List<&2, Api.Attribute>
  for links: List<&2, Api.Link>
  for timestamp: Api.Timestamp
  for root: Bool
  {Api.SpanOptions.kind(Api.SpanOptions.with_kind(options, kind)) == kind : Api.SpanKind} &
  {Api.SpanOptions.attributes(Api.SpanOptions.with_attributes(options, attributes)) == attributes : List<&2, Api.Attribute>} &
  {Api.SpanOptions.links(Api.SpanOptions.with_links(options, links)) == links : List<&2, Api.Link>} &
  {Api.SpanOptions.start_timestamp(Api.SpanOptions.with_start_timestamp(options, timestamp)) ==
    Some{timestamp} : Maybe<&2, Api.Timestamp>} &
  {Api.SpanOptions.is_root(Api.SpanOptions.with_root(options, root)) == root : Bool}

# 12. Status
# ==========
#
# A status is unset, ok, or error with a description (#6). Status.after is
# the transition that setting a status makes, and ok is final.

# LAW status_description
#   Claim: only the error status has a description: the unset and the ok
#     status answer none, and an error answers the description it was built
#     with.
#   Requirement: OTel Trace API, Set Status: the description "MUST only be
#     used with the Error StatusCode value"; spec #2, "a description exists
#     only in the error variant".
#   Why: a backend shows the description as the reason of a failure; one
#     attached to a successful span would mislead.
#   Proof: Laws.status_description, by computation.
law status_description:
  for +description: String
  {Api.Status.description(Api.Unset{}) == None{} : Maybe<&2, String>} &
  {Api.Status.description(Api.Ok{}) == None{} : Maybe<&2, String>} &
  {Api.Status.description(Api.Error{description}) == Some{description} : Maybe<&2, String>}

# LAW status_after
#   Claim: a status set over the unset status or over an error is the new
#     status; a status set over ok leaves ok.
#   Requirement: OTel Trace API, Set Status: "Only the value of the last call
#     will be recorded" and, of Ok, "any further attempts to change it SHOULD
#     be ignored"; spec #2, "ok is final; a later status is ignored".
#   Why: an operator who marked a span as validated must not see it turned
#     back into an error by a later, lower-level call.
#   Proof: Laws.status_after, by computation.
law status_after:
  for +status: Api.Status
  for description: String
  {Api.Status.after(Api.Unset{}, status) == status : Api.Status} &
  {Api.Status.after(Api.Error{description}, status) == status : Api.Status} &
  {Api.Status.after(Api.Ok{}, status) == Api.Ok{} : Api.Status}

# LAW status_set
#   Claim: the status of a recording span after a set is the transition of
#     the status it had by the status set.
#   Requirement: as status_after.
#   Proof: Laws.status_set, by opening the record.
law status_set:
  for +data: Api.SpanData
  for +status: Api.Status
  {Api.SpanData.status(Api.SpanData.set_status(data, status)) ==
    Api.Status.after(Api.SpanData.status(data), status) : Api.Status}

# LAW ok_final
#   Claim: once ok is set on any span, setting any status leaves the span as
#     it was.
#   Requirement: as status_after; #6, "ok is final".
#   Reading: the law holds for a recording and for a non-recording span
#     alike: on a non-recording span both sides are the span itself.
#   Proof: Laws.ok_final, by cases on the span and on its status.
law ok_final:
  for -P: Data
  for +span: Api.Span<P>
  for status: Api.Status
  {Api.Span.set_status(P, Api.Span.set_status(P, span, Api.Ok{}), status) ==
    Api.Span.set_status(P, span, Api.Ok{}) : Api.Span<P>}

# 13. Events and links
# ====================
#
# An event is a named record with attributes and a time, which is an
# explicit timestamp or an offset from the span's start reading; a link is
# a span context with attributes (#6). The attributes of each carry their
# own dropped count, and a span re-enforces its limits on them when it adds
# them (section 14).

# LAW event_readers
#   Claim: each reader of an event answers what it was built with: the name,
#     the attributes as a collection, and the time, an explicit timestamp for
#     SpanEvent.at and an offset in milliseconds for SpanEvent.at_offset.
#   Requirement: OTel Trace API, Add Events: an event has a name, a timestamp
#     and attributes; spec #2, "An event therefore carries either an explicit
#     timestamp or an offset in milliseconds".
#   Proof: Laws.event_readers, by computation.
law event_readers:
  for +name: String
  for +attributes: List<&2, Api.Attribute>
  for +timestamp: Api.Timestamp
  for +milliseconds: Nat
  {Api.SpanEvent.name(Api.SpanEvent.at(name, attributes, timestamp)) == name : String} &
  {Api.SpanEvent.attributes(Api.SpanEvent.at(name, attributes, timestamp)) == Api.Attributes.from_list(attributes) : Api.Attributes} &
  {Api.SpanEvent.time(Api.SpanEvent.at(name, attributes, timestamp)) == Api.AtTimestamp{timestamp} : Api.EventTime} &
  {Api.SpanEvent.name(Api.SpanEvent.at_offset(name, attributes, milliseconds)) == name : String} &
  {Api.SpanEvent.attributes(Api.SpanEvent.at_offset(name, attributes, milliseconds)) ==
    Api.Attributes.from_list(attributes) : Api.Attributes} &
  {Api.SpanEvent.time(Api.SpanEvent.at_offset(name, attributes, milliseconds)) == Api.AtOffset{milliseconds} : Api.EventTime}

# LAW link_readers
#   Claim: each reader of a link answers what it was built with: the span
#     context linked to and the attributes as a collection.
#   Requirement: OTel Trace API, Span creation: a link is a span context with
#     attributes; CONTEXT.md, Link.
#   Proof: Laws.link_readers, by computation.
law link_readers:
  for +span_context: Api.SpanContext
  for +attributes: List<&2, Api.Attribute>
  {Api.Link.span_context(Api.Link.to(span_context, attributes)) == span_context : Api.SpanContext} &
  {Api.Link.attributes(Api.Link.to(span_context, attributes)) == Api.Attributes.from_list(attributes) : Api.Attributes}

# LAW exception_event
#   Claim: the exception event is named `exception`, carries the type under
#     `exception.type` and the message under `exception.message`, both as
#     strings, and happens at the timestamp given.
#   Requirement: OTel Trace API, Record Exception: the event is named
#     `exception` and carries the semantic conventions' `exception.type` and
#     `exception.message`; spec #2, "an event named `exception` with the
#     attributes `exception.type` and `exception.message`, both strings
#     given by the caller".
#   Why: backends show an error under these names and no other.
#   Proof: Laws.exception_event, by computation.
law exception_event:
  for +type_name: String
  for +message: String
  for +timestamp: Api.Timestamp
  {Api.SpanEvent.name(Api.SpanEvent.exception(type_name, message, timestamp)) == "exception" : String} &
  {Api.Attributes.get(Api.SpanEvent.attributes(Api.SpanEvent.exception(type_name, message, timestamp)), "exception.type") ==
    Some{Api.StringValue{type_name}} : Maybe<&2, Api.AttributeValue>} &
  {Api.Attributes.get(Api.SpanEvent.attributes(Api.SpanEvent.exception(type_name, message, timestamp)), "exception.message") ==
    Some{Api.StringValue{message}} : Maybe<&2, Api.AttributeValue>} &
  {Api.SpanEvent.time(Api.SpanEvent.exception(type_name, message, timestamp)) == Api.AtTimestamp{timestamp} : Api.EventTime}

# LAW exception_with_event
#   Claim: the exception event with extra attributes is the event named
#     `exception` whose attributes are the type and the message followed by
#     the extra attributes, in that order; the plain exception event is the
#     same with no extra attributes.
#   Requirement: OTel Trace API, Record Exception: "additional attributes"
#     may be passed with the exception; spec #2, "A variant takes extra
#     attributes".
#   Reading: the extra attributes follow the two standard ones, so an extra
#     attribute with a standard key replaces the standard value in place.
#   Proof: Laws.exception_with_event, by computation.
law exception_with_event:
  for +type_name: String
  for +message: String
  for +extras: List<&2, Api.Attribute>
  for +timestamp: Api.Timestamp
  {Api.SpanEvent.exception_with(type_name, message, extras, timestamp) ==
    Api.SpanEvent.at("exception", Con{Api.Attribute{"exception.type", Api.StringValue{type_name}},
      Con{Api.Attribute{"exception.message", Api.StringValue{message}}, extras}}, timestamp) : Api.SpanEvent} &
  {Api.SpanEvent.exception(type_name, message, timestamp) ==
    Api.SpanEvent.exception_with(type_name, message, Nil{}, timestamp) : Api.SpanEvent}

# LAW attributes_within
#   Claim: a collection re-enforced under limits is its attributes set again,
#     in order, under the limits, starting from no attributes and the count
#     it had already dropped.
#   Requirement: OTel Trace SDK, Span limits: the limits on the attributes
#     of an event and of a link apply to the attributes the span stores;
#     spec #2, "Every operation enforces the limits as it runs".
#   Why: a fork builds its events with no limits in sight; the owner's span
#     must store them within its limits, counting what it drops on top of
#     what the fork dropped.
#   Proof: Laws.attributes_within, by opening the collection.
law attributes_within:
  for +limits: Api.AttributeLimits
  for +attributes: Api.Attributes
  {Api.Attributes.within(limits, attributes) ==
    Api.Attributes.set_all_within(limits, Api.Attributes{Nil{}, Api.Attributes.dropped(attributes)},
      Api.Attributes.to_list(attributes)) : Api.Attributes}

# LAW within_event_and_link
#   Claim: an event or a link within limits keeps its name, time and span
#     context, and has its attributes re-enforced under the limits.
#   Requirement: as attributes_within.
#   Proof: Laws.within_event_and_link, by computation.
law within_event_and_link:
  for +limits: Api.AttributeLimits
  for name: String
  for +attributes: Api.Attributes
  for time: Api.EventTime
  for span_context: Api.SpanContext
  {Api.SpanEvent.within(limits, Api.SpanEvent{name, attributes, time}) ==
    Api.SpanEvent{name, Api.Attributes.within(limits, attributes), time} : Api.SpanEvent} &
  {Api.Link.within(limits, Api.Link{span_context, attributes}) ==
    Api.Link{span_context, Api.Attributes.within(limits, attributes)} : Api.Link}

# An event of two attributes within a limit of one attribute and three
# characters: the first is kept, cut, and the second is dropped.
def limited_event() -> Api.SpanEvent:
  Api.SpanEvent.within(Api.AttributeLimits{Some{1n}, Some{3n}},
    Api.SpanEvent.at("cache.miss", [Api.Attribute{"cache.key", Api.StringValue{"user:42"}},
      Api.Attribute{"cache.hit", Api.BoolValue{False{}}}], Api.Timestamp.from_milliseconds(1500n)))

# LAW event_limits_literal
#   Claim: limits at work on a literal event: it keeps `cache.key` cut to
#     three characters, counts the one attribute it dropped, and keeps its
#     name and time.
#   Proof: Laws.event_limits_literal, by computation.
law event_limits_literal:
  {Api.Attributes.to_list(Api.SpanEvent.attributes(limited_event())) ==
    [Api.Attribute{"cache.key", Api.StringValue{"use"}}] : List<&2, Api.Attribute>} &
  {Api.Attributes.dropped(Api.SpanEvent.attributes(limited_event())) == 1n : Nat} &
  {Api.SpanEvent.name(limited_event()) == "cache.miss" : String} &
  {Api.SpanEvent.time(limited_event()) == Api.AtTimestamp{Api.Timestamp.from_milliseconds(1500n)} : Api.EventTime}

# 14. Spans
# =========
#
# A span is a recording span, Api.Recording{payload, data}, or a
# non-recording span, Api.NonRecording{span_context} (#6). Every operation
# of a recording span is an operation on its data with the payload passed
# through untouched (recording_delegates), and every operation of a
# non-recording span is the identity (non_recording_identity). The rules of
# the data are stated on SpanData: the attributes follow the collection's
# rules under the span's limits, events and links are appended while their
# counts leave room and dropped and counted once they do not, and the
# readers answer what the data was built with.

# LAW new_data_readers
#   Claim: each reader of new span data answers the field it was built with:
#     the scope, the span context, the parent, the name, the kind, the start
#     timestamp, the start reading, the sampled indication and the limits;
#     the data starts with no attributes, no events, no links, nothing
#     dropped and the unset status.
#   Requirement: OTel Trace API, Span: a span starts with the unset status
#     and no events; #6, "readers answer the fields set at construction".
#   Proof: Laws.new_data_readers, by computation.
law new_data_readers:
  for +scope: Api.InstrumentationScope
  for +span_context: Api.SpanContext
  for +parent: Maybe<&2, Api.SpanContext>
  for +name: String
  for +kind: Api.SpanKind
  for +start_timestamp: Api.Timestamp
  for +start_reading: Nat
  for +sampled: Bool
  for +limits: Api.SpanLimits
  {Api.SpanData.scope(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == scope : Api.InstrumentationScope} &
  {Api.SpanData.span_context(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == span_context : Api.SpanContext} &
  {Api.SpanData.parent(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == parent : Maybe<&2, Api.SpanContext>} &
  {Api.SpanData.name(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == name : String} &
  {Api.SpanData.kind(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == kind : Api.SpanKind} &
  {Api.SpanData.start_timestamp(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == start_timestamp : Api.Timestamp} &
  {Api.SpanData.start_reading(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == start_reading : Nat} &
  {Api.SpanData.is_sampled(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == sampled : Bool} &
  {Api.SpanData.attributes(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == Api.Attributes.empty() : Api.Attributes} &
  {Api.SpanData.events(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == Nil{} : List<&2, Api.SpanEvent>} &
  {Api.SpanData.dropped_events(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == 0n : Nat} &
  {Api.SpanData.links(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == Nil{} : List<&2, Api.Link>} &
  {Api.SpanData.dropped_links(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == 0n : Nat} &
  {Api.SpanData.status(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == Api.Unset{} : Api.Status} &
  {Api.SpanData.limits(Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == limits : Api.SpanLimits}

# LAW recording_readers
#   Claim: a recording span built from parts is recording, has the span
#     context and the name it was built with, and its data is the new data
#     of those parts.
#   Requirement: #6, "Readers on a copy: whether the span is recording, its
#     span context, its name, and its data for tests and for SDKs".
#   Why: instrumentation reads the span context to inject it or link to it,
#     and skips expensive attributes when a span is not recording.
#   Proof: Laws.recording_readers, by computation.
law recording_readers:
  for -P: Data
  for +payload: P
  for +scope: Api.InstrumentationScope
  for +span_context: Api.SpanContext
  for +parent: Maybe<&2, Api.SpanContext>
  for +name: String
  for +kind: Api.SpanKind
  for +start_timestamp: Api.Timestamp
  for +start_reading: Nat
  for +sampled: Bool
  for +limits: Api.SpanLimits
  {Api.Span.is_recording(P, Api.Span.recording(P, payload, scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) == True{} : Bool} &
  {Api.Span.span_context(P, Api.Span.recording(P, payload, scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) ==
    Some{span_context} : Maybe<&2, Api.SpanContext>} &
  {Api.Span.name(P, Api.Span.recording(P, payload, scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) ==
    Some{name} : Maybe<&2, String>} &
  {Api.Span.data(P, Api.Span.recording(P, payload, scope, span_context, parent, name, kind, start_timestamp, start_reading,
    sampled, limits)) ==
    Some{Api.SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading,
      sampled, limits)} : Maybe<&2, Api.SpanData>}

# LAW non_recording_readers
#   Claim: a non-recording span is not recording, carries the optional span
#     context it was built with, and has no name and no data.
#   Requirement: spec #2, "A non-recording span holds only an optional span
#     context"; CONTEXT.md, Non-recording span: "it carries its parent's span
#     context so that propagation continues".
#   Proof: Laws.non_recording_readers, by computation.
law non_recording_readers:
  for -P: Data
  for +span_context: Maybe<&2, Api.SpanContext>
  {Api.Span.is_recording(P, Api.Span.non_recording(P, span_context)) == False{} : Bool} &
  {Api.Span.span_context(P, Api.Span.non_recording(P, span_context)) == span_context : Maybe<&2, Api.SpanContext>} &
  {Api.Span.name(P, Api.Span.non_recording(P, span_context)) == None{} : Maybe<&2, String>} &
  {Api.Span.data(P, Api.Span.non_recording(P, span_context)) == None{} : Maybe<&2, Api.SpanData>}

# LAW recording_delegates
#   Claim: each operation on a recording span is that operation on its data,
#     with the payload passed through untouched.
#   Requirement: spec #2, "store my configuration as a `Data` payload ... in
#     each recording span, so that ending a span needs nothing but the span";
#     #6, "the API never inspects the payload".
#   Why: the SDK finds at the end exactly the payload it stored at the start,
#     whatever instrumentation recorded in between.
#   Proof: Laws.recording_delegates, by computation.
law recording_delegates:
  for -P: Data
  for +payload: P
  for +data: Api.SpanData
  for +key: String
  for +value: Api.AttributeValue
  for +entries: List<&2, Api.Attribute>
  for +link: Api.Link
  for +links: List<&2, Api.Link>
  for +status: Api.Status
  for +name: String
  for +event: Api.SpanEvent
  for +events: List<&2, Api.SpanEvent>
  {Api.Span.set_attribute(P, Api.Recording{payload, data}, key, value) ==
    Api.Recording{payload, Api.SpanData.set_attribute(data, key, value)} : Api.Span<P>} &
  {Api.Span.set_attributes(P, Api.Recording{payload, data}, entries) ==
    Api.Recording{payload, Api.SpanData.set_attributes(data, entries)} : Api.Span<P>} &
  {Api.Span.add_link(P, Api.Recording{payload, data}, link) == Api.Recording{payload, Api.SpanData.add_link(data, link)} : Api.Span<P>} &
  {Api.Span.add_links(P, Api.Recording{payload, data}, links) ==
    Api.Recording{payload, Api.SpanData.add_links(data, links)} : Api.Span<P>} &
  {Api.Span.set_status(P, Api.Recording{payload, data}, status) ==
    Api.Recording{payload, Api.SpanData.set_status(data, status)} : Api.Span<P>} &
  {Api.Span.update_name(P, Api.Recording{payload, data}, name) ==
    Api.Recording{payload, Api.SpanData.update_name(data, name)} : Api.Span<P>} &
  {Api.Span.add_event(P, Api.Recording{payload, data}, event) ==
    Api.Recording{payload, Api.SpanData.add_event(data, event)} : Api.Span<P>} &
  {Api.Span.add_events(P, Api.Recording{payload, data}, events) ==
    Api.Recording{payload, Api.SpanData.add_events(data, events)} : Api.Span<P>}

# LAW non_recording_identity
#   Claim: every operation on a non-recording span answers the span
#     unchanged: setting an attribute or several, adding a link or several,
#     setting the status, updating the name, adding an event, an event at a
#     timestamp or several events, and recording an exception with or
#     without extra attributes.
#   Requirement: OTel Trace API, Span, IsRecording: a span that is not
#     recording accepts the operations and records nothing; spec #2, "On a
#     non-recording span each is the identity"; CONTEXT.md, Non-recording
#     span.
#   Why: instrumentation has one code path whether or not an SDK records.
#   Proof: Laws.non_recording_identity, by computation.
law non_recording_identity:
  for -P: Data
  for +span_context: Maybe<&2, Api.SpanContext>
  for key: String
  for value: Api.AttributeValue
  for entries: List<&2, Api.Attribute>
  for link: Api.Link
  for links: List<&2, Api.Link>
  for status: Api.Status
  for name: String
  for event: Api.SpanEvent
  for events: List<&2, Api.SpanEvent>
  for event_name: String
  for attributes: List<&2, Api.Attribute>
  for +timestamp: Api.Timestamp
  for +type_name: String
  for +message: String
  for extras: List<&2, Api.Attribute>
  {Api.Span.set_attribute(P, Api.Span.non_recording(P, span_context), key, value) ==
    Api.Span.non_recording(P, span_context) : Api.Span<P>} &
  {Api.Span.set_attributes(P, Api.Span.non_recording(P, span_context), entries) == Api.Span.non_recording(P, span_context) : Api.Span<P>} &
  {Api.Span.add_link(P, Api.Span.non_recording(P, span_context), link) == Api.Span.non_recording(P, span_context) : Api.Span<P>} &
  {Api.Span.add_links(P, Api.Span.non_recording(P, span_context), links) == Api.Span.non_recording(P, span_context) : Api.Span<P>} &
  {Api.Span.set_status(P, Api.Span.non_recording(P, span_context), status) == Api.Span.non_recording(P, span_context) : Api.Span<P>} &
  {Api.Span.update_name(P, Api.Span.non_recording(P, span_context), name) == Api.Span.non_recording(P, span_context) : Api.Span<P>} &
  {Api.Span.add_event(P, Api.Span.non_recording(P, span_context), event) == Api.Span.non_recording(P, span_context) : Api.Span<P>} &
  {Api.Span.add_event_at(P, Api.Span.non_recording(P, span_context), event_name, attributes, timestamp) ==
    Api.Span.non_recording(P, span_context) : Api.Span<P>} &
  {Api.Span.add_events(P, Api.Span.non_recording(P, span_context), events) == Api.Span.non_recording(P, span_context) : Api.Span<P>} &
  {Api.Span.record_exception(P, Api.Span.non_recording(P, span_context), type_name, message, timestamp) ==
    Api.Span.non_recording(P, span_context) : Api.Span<P>} &
  {Api.Span.record_exception_with(P, Api.Span.non_recording(P, span_context), type_name, message, extras, timestamp) ==
    Api.Span.non_recording(P, span_context) : Api.Span<P>}

# LAW span_attribute_rules
#   Claim: setting an attribute on span data sets it on the span's
#     attributes under the span's attribute limits, and setting several sets
#     them all under those limits: the rules of the collection (sections 5
#     and 6) are the rules of the span.
#   Requirement: OTel Trace API, Set Attributes, and Trace SDK, Span limits:
#     the span's attributes follow the attribute rules under the span's
#     limits; #6, "attribute rules on the span match the collection's".
#   Why: every law of the collection, from unique keys to the dropped count,
#     holds of a span's attributes without being restated.
#   Proof: Laws.span_attribute_rules, by opening the record.
law span_attribute_rules:
  for +data: Api.SpanData
  for +key: String
  for +value: Api.AttributeValue
  for +entries: List<&2, Api.Attribute>
  {Api.SpanData.attributes(Api.SpanData.set_attribute(data, key, value)) ==
    Api.Attributes.set_within(Api.SpanLimits.span_attributes(Api.SpanData.limits(data)),
      Api.SpanData.attributes(data), key, value) : Api.Attributes} &
  {Api.SpanData.attributes(Api.SpanData.set_attributes(data, entries)) ==
    Api.Attributes.set_all_within(Api.SpanLimits.span_attributes(Api.SpanData.limits(data)),
      Api.SpanData.attributes(data), entries) : Api.Attributes}

# LAW set_attributes_fold
#   Claim: setting several attributes on a span sets them one by one, in
#     order, and setting none changes nothing.
#   Requirement: #6, "set one attribute, set several".
#   Proof: Laws.set_attributes_fold, by opening the span and its data.
law set_attributes_fold:
  for -P: Data
  for +span: Api.Span<P>
  for +key: String
  for +value: Api.AttributeValue
  for rest: List<&2, Api.Attribute>
  {Api.Span.set_attributes(P, span, Con{Api.Attribute{key, value}, rest}) ==
    Api.Span.set_attributes(P, Api.Span.set_attribute(P, span, key, value), rest) : Api.Span<P>} &
  {Api.Span.set_attributes(P, span, Nil{}) == span : Api.Span<P>}

# LAW update_name_replaces
#   Claim: after a name update, the name of the data is the new name, and
#     the name of the recording span is the new name.
#   Requirement: OTel Trace API, UpdateName: "Updates the Span name";
#     #6, "update name replaces".
#   Why: a server span named after the method is renamed after the route
#     once the route is known, and the export carries the route.
#   Proof: Laws.update_name_replaces, by opening the record.
law update_name_replaces:
  for -P: Data
  for payload: P
  for +data: Api.SpanData
  for +name: String
  {Api.SpanData.name(Api.SpanData.update_name(data, name)) == name : String} &
  {Api.Span.name(P, Api.Span.update_name(P, Api.Recording{payload, data}, name)) == Some{name} : Maybe<&2, String>}

# LAW event_added
#   Claim: while the events are fewer than the event count limit, adding an
#     event appends it after the others, with its attributes re-enforced
#     under the event attribute limits, and drops nothing.
#   Requirement: OTel Trace SDK, Span limits: events are kept until
#     EventCountLimit is reached, each with at most
#     AttributePerEventCountLimit attributes; spec #2, "an event or a link
#     past its count is dropped and counted".
#   Reading: `limited` says the span's limits hold an event count `limit`,
#     and `room` that the span holds fewer events than it.
#   Proof: Laws.event_added, by rewriting both hypotheses into the span's
#     check.
law event_added:
  for +limit: Nat
  for +data: Api.SpanData
  for +event: Api.SpanEvent
  for limited: {Api.SpanLimits.event_count(Api.SpanData.limits(data)) == Some{limit} : Maybe<&2, Nat>}
  for room: {Nat.is_lt(List.length(&2, Api.SpanEvent, Api.SpanData.events(data)), limit) == True{} : Bool}
  {Api.SpanData.events(Api.SpanData.add_event(data, event)) ==
    List.append(&2, Api.SpanEvent, Api.SpanData.events(data),
      [Api.SpanEvent.within(Api.SpanLimits.event_attributes(Api.SpanData.limits(data)), event)]) : List<&2, Api.SpanEvent>} &
  {Api.SpanData.dropped_events(Api.SpanData.add_event(data, event)) == Api.SpanData.dropped_events(data) : Nat}

# LAW event_dropped
#   Claim: once the events have reached the event count limit, adding an
#     event keeps the events as they are and counts one more dropped event.
#   Requirement: as event_added; OTel Trace SDK, Span limits: the span
#     records how many events it dropped.
#   Why: memory stays bounded while a span is open, and the export tells the
#     operator how much was lost.
#   Proof: Laws.event_dropped, by rewriting both hypotheses into the span's
#     check.
law event_dropped:
  for +limit: Nat
  for +data: Api.SpanData
  for +event: Api.SpanEvent
  for limited: {Api.SpanLimits.event_count(Api.SpanData.limits(data)) == Some{limit} : Maybe<&2, Nat>}
  for full: {Nat.is_lt(List.length(&2, Api.SpanEvent, Api.SpanData.events(data)), limit) == False{} : Bool}
  {Api.SpanData.events(Api.SpanData.add_event(data, event)) == Api.SpanData.events(data) : List<&2, Api.SpanEvent>} &
  {Api.SpanData.dropped_events(Api.SpanData.add_event(data, event)) == 1n+Api.SpanData.dropped_events(data) : Nat}

# LAW event_unlimited
#   Claim: without an event count limit, adding an event always appends it,
#     with its attributes re-enforced under the event attribute limits.
#   Requirement: #4, "an unlimited form".
#   Proof: Laws.event_unlimited, by rewriting the hypothesis into the span's
#     check.
law event_unlimited:
  for +data: Api.SpanData
  for +event: Api.SpanEvent
  for unlimited: {Api.SpanLimits.event_count(Api.SpanData.limits(data)) == None{} : Maybe<&2, Nat>}
  {Api.SpanData.events(Api.SpanData.add_event(data, event)) ==
    List.append(&2, Api.SpanEvent, Api.SpanData.events(data),
      [Api.SpanEvent.within(Api.SpanLimits.event_attributes(Api.SpanData.limits(data)), event)]) : List<&2, Api.SpanEvent>} &
  {Api.SpanData.dropped_events(Api.SpanData.add_event(data, event)) == Api.SpanData.dropped_events(data) : Nat}

# LAW events_bounded
#   Claim: span data within its event count limit stays within it after any
#     event is added: the count of events never exceeds the limit.
#   Requirement: OTel Trace SDK, Span limits: events past EventCountLimit
#     are discarded, so a span never holds more than the limit.
#   Reading: `bound` says the events are at most the limit before the add;
#     together with new_data_readers, every span built by adds under the
#     limit stays at most the limit.
#   Proof: Laws.events_bounded, via proofs/spans.bend.
law events_bounded:
  for +limit: Nat
  for +data: Api.SpanData
  for +event: Api.SpanEvent
  for limited: {Api.SpanLimits.event_count(Api.SpanData.limits(data)) == Some{limit} : Maybe<&2, Nat>}
  for bound: {Nat.is_le(List.length(&2, Api.SpanEvent, Api.SpanData.events(data)), limit) == True{} : Bool}
  {Nat.is_le(List.length(&2, Api.SpanEvent, Api.SpanData.events(Api.SpanData.add_event(data, event))), limit) == True{} : Bool}

# LAW add_events_fold
#   Claim: adding a list of events adds them one by one, in order, and
#     adding none changes nothing.
#   Requirement: spec #2, "event lists add as a fold of single events"; #6,
#     "adding a list of events equals folding single additions".
#   Why: a fork's observations, returned as data, are recorded exactly as if
#     the owner had added each of them.
#   Proof: Laws.add_events_fold, by cases on the span.
law add_events_fold:
  for -P: Data
  for +span: Api.Span<P>
  for +event: Api.SpanEvent
  for rest: List<&2, Api.SpanEvent>
  {Api.Span.add_events(P, span, Con{event, rest}) == Api.Span.add_events(P, Api.Span.add_event(P, span, event), rest) : Api.Span<P>} &
  {Api.Span.add_events(P, span, Nil{}) == span : Api.Span<P>}

# LAW event_shorthands
#   Claim: adding an event at a timestamp adds the event SpanEvent.at builds,
#     and recording an exception, with or without extra attributes, adds the
#     exception event.
#   Requirement: OTel Trace API, Record Exception: recording an exception is
#     adding an event; #6, "record an exception with an explicit timestamp".
#   Why: every law about events, from the limits to the fold, holds of a
#     recorded exception.
#   Proof: Laws.event_shorthands, by computation.
law event_shorthands:
  for -P: Data
  for +span: Api.Span<P>
  for +name: String
  for +attributes: List<&2, Api.Attribute>
  for +timestamp: Api.Timestamp
  for +type_name: String
  for +message: String
  for +extras: List<&2, Api.Attribute>
  {Api.Span.add_event_at(P, span, name, attributes, timestamp) ==
    Api.Span.add_event(P, span, Api.SpanEvent.at(name, attributes, timestamp)) : Api.Span<P>} &
  {Api.Span.record_exception(P, span, type_name, message, timestamp) ==
    Api.Span.add_event(P, span, Api.SpanEvent.exception(type_name, message, timestamp)) : Api.Span<P>} &
  {Api.Span.record_exception_with(P, span, type_name, message, extras, timestamp) ==
    Api.Span.add_event(P, span, Api.SpanEvent.exception_with(type_name, message, extras, timestamp)) : Api.Span<P>}

# LAW link_added
#   Claim: while the links are fewer than the link count limit, adding a
#     link appends it after the others, with its attributes re-enforced
#     under the link attribute limits, and drops nothing.
#   Requirement: OTel Trace SDK, Span limits: links are kept until
#     LinkCountLimit is reached, each with at most
#     AttributePerLinkCountLimit attributes; spec #2, as event_added.
#   Proof: Laws.link_added, by rewriting both hypotheses into the span's
#     check.
law link_added:
  for +limit: Nat
  for +data: Api.SpanData
  for +link: Api.Link
  for limited: {Api.SpanLimits.link_count(Api.SpanData.limits(data)) == Some{limit} : Maybe<&2, Nat>}
  for room: {Nat.is_lt(List.length(&2, Api.Link, Api.SpanData.links(data)), limit) == True{} : Bool}
  {Api.SpanData.links(Api.SpanData.add_link(data, link)) ==
    List.append(&2, Api.Link, Api.SpanData.links(data),
      [Api.Link.within(Api.SpanLimits.link_attributes(Api.SpanData.limits(data)), link)]) : List<&2, Api.Link>} &
  {Api.SpanData.dropped_links(Api.SpanData.add_link(data, link)) == Api.SpanData.dropped_links(data) : Nat}

# LAW link_dropped
#   Claim: once the links have reached the link count limit, adding a link
#     keeps the links as they are and counts one more dropped link.
#   Requirement: as link_added; OTel Trace SDK, Span limits: the span
#     records how many links it dropped.
#   Proof: Laws.link_dropped, by rewriting both hypotheses into the span's
#     check.
law link_dropped:
  for +limit: Nat
  for +data: Api.SpanData
  for +link: Api.Link
  for limited: {Api.SpanLimits.link_count(Api.SpanData.limits(data)) == Some{limit} : Maybe<&2, Nat>}
  for full: {Nat.is_lt(List.length(&2, Api.Link, Api.SpanData.links(data)), limit) == False{} : Bool}
  {Api.SpanData.links(Api.SpanData.add_link(data, link)) == Api.SpanData.links(data) : List<&2, Api.Link>} &
  {Api.SpanData.dropped_links(Api.SpanData.add_link(data, link)) == 1n+Api.SpanData.dropped_links(data) : Nat}

# LAW link_unlimited
#   Claim: without a link count limit, adding a link always appends it, with
#     its attributes re-enforced under the link attribute limits.
#   Requirement: #4, "an unlimited form".
#   Proof: Laws.link_unlimited, by rewriting the hypothesis into the span's
#     check.
law link_unlimited:
  for +data: Api.SpanData
  for +link: Api.Link
  for unlimited: {Api.SpanLimits.link_count(Api.SpanData.limits(data)) == None{} : Maybe<&2, Nat>}
  {Api.SpanData.links(Api.SpanData.add_link(data, link)) ==
    List.append(&2, Api.Link, Api.SpanData.links(data),
      [Api.Link.within(Api.SpanLimits.link_attributes(Api.SpanData.limits(data)), link)]) : List<&2, Api.Link>} &
  {Api.SpanData.dropped_links(Api.SpanData.add_link(data, link)) == Api.SpanData.dropped_links(data) : Nat}

# LAW add_links_fold
#   Claim: adding a list of links adds them one by one, in order, and adding
#     none changes nothing.
#   Requirement: #6, "add a link"; spec #2, the start options' links.
#   Why: an SDK adds the links of the start options exactly as if the owner
#     had added each of them.
#   Proof: Laws.add_links_fold, by cases on the span.
law add_links_fold:
  for -P: Data
  for +span: Api.Span<P>
  for +link: Api.Link
  for rest: List<&2, Api.Link>
  {Api.Span.add_links(P, span, Con{link, rest}) == Api.Span.add_links(P, Api.Span.add_link(P, span, link), rest) : Api.Span<P>} &
  {Api.Span.add_links(P, span, Nil{}) == span : Api.Span<P>}

# LAW links_bounded
#   Claim: span data within its link count limit stays within it after any
#     link is added: the count of links never exceeds the limit.
#   Requirement: OTel Trace SDK, Span limits: links past LinkCountLimit are
#     discarded, so a span never holds more than the limit.
#   Proof: Laws.links_bounded, via proofs/spans.bend.
law links_bounded:
  for +limit: Nat
  for +data: Api.SpanData
  for +link: Api.Link
  for limited: {Api.SpanLimits.link_count(Api.SpanData.limits(data)) == Some{limit} : Maybe<&2, Nat>}
  for bound: {Nat.is_le(List.length(&2, Api.Link, Api.SpanData.links(data)), limit) == True{} : Bool}
  {Nat.is_le(List.length(&2, Api.Link, Api.SpanData.links(Api.SpanData.add_link(data, link))), limit) == True{} : Bool}
