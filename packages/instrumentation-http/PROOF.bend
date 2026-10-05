import Base
import ./LAWS.bend as Laws
import ./core.bend as HttpCore
import bend-telemetry-api@0.1.0.0/api.bend as Api
import ./proofs/methods.bend as MethodsProof

# Proofs of the laws of bend-telemetry-instrumentation-http
# =========================================================
#
# Each `def Laws.<name>(...)` below proves `law <name>` of LAWS.bend. Its
# parameters are the law's `for` lines, in order, and its body is a term
# whose type is the law's conclusion. In Bend a proposition is a type and a
# proof is an ordinary definition of that type: there are no tactics, and
# the checker verifies every step. The checker accepts this file only when
# every law of LAWS.bend has a proof, so
#
#   ./bend packages/instrumentation-http/PROOF.bend --check-only
#
# is the proof gate of the package: it prints "ALL PROOFS CHECK", which Bend
# prints only when no definition this file imports relies on `@unsafe`,
# which would skip the termination check and void the proofs, or on foreign
# code. This file imports core.bend, the pure core, and never host.bend.
# scripts/validate.sh runs it against the local hub, which serves the API
# and the semconv package that the core imports by name.
#
# The notation:
#
#   {==}              reflexivity: both sides compute to the same term. A law
#                     about literal values is proved this way: the checker
#                     computes both sides, strings character by character and
#                     status codes and ports bit by bit.
#   (p, q)            a proof of P & Q from proofs of P and of Q.
#   %e : P            rewrite with an equation e : {a == b : T}. P is the
#                     current goal with `_` where b appears, and the goal
#                     becomes P with a in that place. Equal.sym(T, a, b, e)
#                     turns an equation around. The status laws rewrite the
#                     comparison that a derivation passes to its decision
#                     helper, since `match` cannot inspect a computed value.
#   match x: case     case analysis: each case refines the goal for that
#                     constructor. The configuration laws open the record.
#
# Proof modules:
#
#   proofs/methods.bend    the laws' search identified with the package's,
#                          and the normalization under a hypothesis on it

# 1. Package
# ==========

def Laws.name():
  {==}

# 2. Headers
# ==========

def Laws.header_lookup():
  ({==}, ({==}, ({==}, ({==}, {==}))))

# By computation: the checker builds the map and walks its trie.
def Laws.headers_from_map():
  ({==}, ({==}, {==}))

# 3. Methods
# ==========

def Laws.known_methods_default():
  {==}

def Laws.method_listed(known, method, listed):
  MethodsProof.known_when_listed(known, method, listed)

def Laws.method_unlisted(known, method, unlisted):
  MethodsProof.other_when_unlisted(known, method, unlisted)

def Laws.method_literal():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))))

# By computation: each operation matches the constructor it is applied to.
def Laws.method_attributes(name, original):
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

# 4. Span names
# =============

def Laws.span_name_route(method, route):
  {==}

def Laws.span_name_method(method):
  {==}

def Laws.span_name_other(original, route):
  ({==}, {==})

# 5. Status
# =========

# The comparison is rewritten to False{}: Status.of computes the unset
# status.
def Laws.server_status_low(code, low):
  %Equal.sym(Bool, U32.is_ge(code, 500), False{}, low) : {HttpCore.Status.of(_) == Api.Unset{} : Api.Status}
  {==}

def Laws.server_status_error(code, high):
  %Equal.sym(Bool, U32.is_ge(code, 500), True{}, high) : {HttpCore.Status.of(_) == Api.Error{""} : Api.Status}
  {==}

def Laws.client_status_low(code, low):
  %Equal.sym(Bool, U32.is_ge(code, 400), False{}, low) : {HttpCore.Status.of(_) == Api.Unset{} : Api.Status}
  {==}

def Laws.client_status_error(code, high):
  %Equal.sym(Bool, U32.is_ge(code, 400), True{}, high) : {HttpCore.Status.of(_) == Api.Error{""} : Api.Status}
  {==}

def Laws.client_status_failed(error_type, description):
  {==}

# By computation: the comparisons on the literal codes.
def Laws.status_literal():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))))))))))))

def Laws.server_error_type_low(code, low):
  %Equal.sym(Bool, U32.is_ge(code, 500), False{}, low) : {HttpCore.ErrorType.of(code, _) == None{} : Maybe<&2, String>}
  {==}

def Laws.server_error_type_error(code, high):
  %Equal.sym(Bool, U32.is_ge(code, 500), True{}, high) :
    {HttpCore.ErrorType.of(code, _) == Some{U32.show(code)} : Maybe<&2, String>}
  {==}

def Laws.client_error_type_low(code, low):
  %Equal.sym(Bool, U32.is_ge(code, 400), False{}, low) : {HttpCore.ErrorType.of(code, _) == None{} : Maybe<&2, String>}
  {==}

def Laws.client_error_type_error(code, high):
  %Equal.sym(Bool, U32.is_ge(code, 400), True{}, high) :
    {HttpCore.ErrorType.of(code, _) == Some{U32.show(code)} : Maybe<&2, String>}
  {==}

def Laws.client_error_type_failed(error_type, description):
  {==}

def Laws.error_type_literal():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))

# 6. url.full
# ===========
#
# By computation: the checker cuts and rejoins the literal texts.

def Laws.url_full_credentials():
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

def Laws.url_full_sensitive_keys():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))))

def Laws.url_full_key_without_value():
  ({==}, ({==}, {==}))

def Laws.url_full_prefix_key():
  ({==}, {==})

def Laws.url_full_override():
  ({==}, {==})

# 7. Targets
# ==========

def Laws.target_split():
  ({==}, ({==}, ({==}, {==})))

def Laws.target_query_redacted():
  ({==}, {==})

# 8. Server headers
# =================

def Laws.server_scheme():
  ({==}, ({==}, ({==}, {==})))

def Laws.server_address_port():
  ({==}, ({==}, ({==}, ({==}, {==}))))

def Laws.client_address():
  ({==}, ({==}, ({==}, ({==}, {==}))))

def Laws.user_agent():
  ({==}, {==})

# 9. Client URL
# =============

def Laws.client_server_attributes():
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

# 10. Header capture
# ==================

def Laws.capture_literal():
  ({==}, {==})

# By computation: no name gives no attribute, whatever the headers.
def Laws.capture_nothing(prefix, headers):
  {==}

def Laws.body_size_declared():
  ({==}, ({==}, {==}))

# By computation: no header gives no declared size, and the length stands.
def Laws.body_size_length(length):
  {==}

# 11. Configuration
# =================

def Laws.config_default():
  ({==}, ({==}, ({==}, ({==}, {==}))))

# Opening the record shows that each setter replaces its field and the
# reader answers it, whatever the field held.
def Laws.config_setters_read_back(config, known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes):
  match config:
    case HttpCore.Config{k, s, rq, rs, b}:
      ({==}, ({==}, ({==}, ({==}, {==}))))

def Laws.methods_literal():
  ({==}, ({==}, ({==}, ({==}, {==}))))

def Laws.config_unset_is_default():
  ({==}, {==})

# By computation: the lookup passes over the empty value, so both sides look
# the variable up in the same list.
def Laws.config_empty_is_unset(name, variables):
  {==}

def Laws.config_from_variables_literal():
  ({==}, ({==}, ({==}, {==})))

# 12. Spans
# =========
#
# By computation: the whole derivations on the literal messages.

def Laws.server_request_literal():
  ({==}, {==})

def Laws.server_response_literal():
  ({==}, {==})

def Laws.client_request_literal():
  {==}

def Laws.client_response_literal():
  ({==}, ({==}, {==}))
