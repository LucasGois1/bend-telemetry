# Proofs: methods
# ===============
#
# The known methods are those the search finds, and no other. PROOF.bend
# proves the laws method_listed and method_unlisted of LAWS.bend with these
# lemmas.
#
# listed_spec identifies the laws' independent search `among` with the
# package's Text.listed by induction on the known methods, so that a
# hypothesis on one becomes a fact about the other. Method.normalize passes
# the result of its search to Method.normalize.of, and `match` cannot inspect
# a computed value, so known_when_listed and other_when_unlisted rewrite that
# result with the hypothesis and let the checker compute the rest.

import Base
import ../LAWS.bend as Laws
import ../core.bend as HttpCore

# The laws' search and the package's agree on every list: both compare the
# method with each name, in order.
law listed_spec:
  for +method: String
  for known: List<&2, String>
  {Laws.among(method, known) == HttpCore.Text.listed(known, method) : Bool}

def listed_spec(method, known):
  match known:
    case Nil{}:
      {==}
    case Con{other, rest}:
      %listed_spec(method, rest) :
        {Bool.or(String.eq(method, other), Laws.among(method, rest)) == Bool.or(String.eq(method, other), _) : Bool}
      {==}

# When the laws' search finds the method, so does the package's.
law listed_true:
  for +known: List<&2, String>
  for +method: String
  for found: {Laws.among(method, known) == True{} : Bool}
  {HttpCore.Text.listed(known, method) == True{} : Bool}

def listed_true(known, method, found):
  Equal.trans(Bool, HttpCore.Text.listed(known, method), Laws.among(method, known), True{},
    Equal.sym(Bool, Laws.among(method, known), HttpCore.Text.listed(known, method), listed_spec(method, known)), found)

# When the laws' search misses the method, so does the package's.
law listed_false:
  for +known: List<&2, String>
  for +method: String
  for missing: {Laws.among(method, known) == False{} : Bool}
  {HttpCore.Text.listed(known, method) == False{} : Bool}

def listed_false(known, method, missing):
  Equal.trans(Bool, HttpCore.Text.listed(known, method), Laws.among(method, known), False{},
    Equal.sym(Bool, Laws.among(method, known), HttpCore.Text.listed(known, method), listed_spec(method, known)), missing)

# A method the search finds is known: the search is rewritten to True{},
# and Method.normalize.of computes.
law known_when_listed:
  for +known: List<&2, String>
  for +method: String
  for found: {Laws.among(method, known) == True{} : Bool}
  {HttpCore.Method.normalize(known, method) == HttpCore.KnownMethod{method} : HttpCore.Method}

def known_when_listed(known, method, found):
  %Equal.sym(Bool, HttpCore.Text.listed(known, method), True{}, listed_true(known, method, found)) :
    {HttpCore.Method.normalize.of(method, _) == HttpCore.KnownMethod{method} : HttpCore.Method}
  {==}

# A method the search misses is `_OTHER` with the method as its original.
law other_when_unlisted:
  for +known: List<&2, String>
  for +method: String
  for missing: {Laws.among(method, known) == False{} : Bool}
  {HttpCore.Method.normalize(known, method) == HttpCore.OtherMethod{method} : HttpCore.Method}

def other_when_unlisted(known, method, missing):
  %Equal.sym(Bool, HttpCore.Text.listed(known, method), False{}, listed_false(known, method, missing)) :
    {HttpCore.Method.normalize.of(method, _) == HttpCore.OtherMethod{method} : HttpCore.Method}
  {==}
