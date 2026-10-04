import Base
import ./LAWS.bend as Laws
import ./sdk.bend as Sdk
import bend-telemetry-api@0.1.0.0/api.bend as Api
import ./proofs/bools.bend as BoolsProof
import ./proofs/config.bend as ConfigProof
import ./proofs/percent.bend as PercentProof

# Proofs of the laws of bend-telemetry-sdk
# ========================================
#
# Each `def Laws.<name>(...)` below proves `law <name>` of LAWS.bend. Its
# parameters are the law's `for` lines, in order, and its body is a term
# whose type is the law's conclusion. In Bend a proposition is a type and a
# proof is an ordinary definition of that type: there are no tactics, and
# the checker verifies every step. The checker accepts this file only when
# every law of LAWS.bend has a proof, so
#
#   ./bend packages/sdk/PROOF.bend --check-only
#
# is the proof gate of the package: it prints "ALL PROOFS CHECK", which Bend
# prints only when no definition this file imports relies on `@unsafe`,
# which would skip the termination check and void the proofs, or on foreign
# code. This file imports sdk.bend, the pure core, and never host.bend.
# scripts/validate.sh runs it against the local hub, which serves the API
# that the core imports by name.
#
# The notation:
#
#   {==}              reflexivity: both sides compute to the same term. A law
#                     about literal values is proved this way: the checker
#                     computes both sides.
#   (p, q)            a proof of P & Q from proofs of P and of Q.
#   %e : P            rewrite with an equation e : {a == b : T}. P is the
#                     current goal with `_` where b appears, and the goal
#                     becomes P with a in that place. Equal.sym(T, a, b, e)
#                     turns an equation around.
#   match x: case     case analysis: each case refines the goal for that
#                     constructor. The laws quantify over configurations,
#                     and the proofs open them to reach the fields.
#
# Proof modules:
#
#   proofs/bools.bend      general lemmas on Bool
#   proofs/config.bend     the setters on any configuration, and the one
#                          diagnostic of an invalid Boolean
#   proofs/percent.bend    a text without a percent sign decodes to itself

# 1. Package
# ==========

def Laws.name():
  {==}

# 2. Defaults
# ===========

# By computation: each reader opens the record Config.default builds.
def Laws.config_default():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))))))))))

def Laws.batch_default():
  ({==}, ({==}, ({==}, {==})))

def Laws.resource_empty(attributes, schema_url):
  ({==}, ({==}, ({==}, {==})))

# 3. Setters
# ==========

# Opening the record shows that each setter replaces its field and the
# reader answers it, whatever the field held.
def Laws.setters_read_back(config, disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg,
  processors, batch, span_limits, exporter, shutdown_timeout, threshold_precision):
  match config:
    case Sdk.Config{d, l, r, sn, ra, s, sa, p, b, sl, e, o, st, tp}:
      ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))))))))

def Laws.batch_setters_read_back(options, queue_size, schedule_delay, export_timeout, batch_size):
  match options:
    case Sdk.BatchOptions{q, d, t, b}:
      ({==}, ({==}, ({==}, {==})))

def Laws.otlp_value_set():
  ({==}, ({==}, {==}))

# The setters' laws, applied to the configuration the environment produced
# (proofs/config.bend).
def Laws.programmatic_wins(variables, disabled, sampler, span_limits):
  (ConfigProof.disabled_reads(Sdk.Configured.config(Sdk.Config.from_variables(variables)), disabled),
    (ConfigProof.sampler_reads(Sdk.Configured.config(Sdk.Config.from_variables(variables)), sampler),
      ConfigProof.span_limits_reads(Sdk.Configured.config(Sdk.Config.from_variables(variables)), span_limits)))

# 4. Diagnostics
# ==============

# By cases: each level's rank is at least itself.
def Laws.level_reflexive(level):
  match level:
    case Sdk.Debug{}:
      {==}
    case Sdk.Info{}:
      {==}
    case Sdk.Warn{}:
      {==}
    case Sdk.Error{}:
      {==}

def Laws.level_order():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))))

def Laws.level_text():
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

def Laws.diagnostic_readers(level, component, message):
  ({==}, ({==}, {==}))

def Laws.diagnostic_show():
  {==}

# 5. Parsing
# ==========
#
# By computation: the checker lowercases and compares the literal texts,
# and reads the small integers in unary.

def Laws.bool_literal():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))))))))

def Laws.count_literal():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))))))))))))))

def Laws.size_literal():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))))

def Laws.duration_literal():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))

def Laws.timeout_literal():
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

def Laws.level_literal():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))))

def Laws.sampler_literal():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))))))

def Laws.exporter_literal():
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

def Laws.text_kept(text):
  {==}

# 6. Environment
# ==============

def Laws.variable_names():
  ({==}, ({==}, ({==}, {==})))

def Laws.unset_is_default():
  {==}

# By computation: the lookup of every variable passes over the empty value,
# so both sides apply the same variables to the same defaults.
def Laws.empty_is_unset(name, variables):
  {==}

def Laws.environment_literal():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))))))))

def Laws.invalid_boolean_once(text, reason, present, invalid):
  ConfigProof.invalid_boolean_once(text, reason, present, invalid)

def Laws.invalid_literal():
  ({==}, {==})

def Laws.specific_limits_win():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))

def Laws.otlp_kept():
  ({==}, {==})

# 7. Percent decoding
# ===================

def Laws.decode_plain(text, plain):
  PercentProof.plain(text, plain)

def Laws.decode_literal():
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

def Laws.decode_multibyte():
  ({==}, ({==}, ({==}, {==})))

def Laws.decode_refuses():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))))))))))
