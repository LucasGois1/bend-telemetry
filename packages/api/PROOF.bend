import Base
import ./LAWS.bend as Laws
import ./api.bend as Api

# Proofs of the laws of bend-telemetry-api
# ========================================
#
# Each `def Laws.<name>` proves `law <name>` of LAWS.bend. A proposition is a
# type and a proof is a definition of that type; `{==}` proves an equality
# whose sides compute to the same term, a tuple proves a conjunction, and
# `match` refines the goal for each constructor of a value the law
# quantifies over.

# Package
# -------

def Laws.name():
  {==}

def Laws.context_fields():
  {==}

# Span context
# ------------

# By computation: each reader matches the constructor it is applied to.
def Laws.span_context_remote(incoming):
  ({==}, ({==}, {==}))

def Laws.span_context_local(outgoing):
  ({==}, ({==}, {==}))

def Laws.remote_readers(incoming):
  ({==}, ({==}, ({==}, {==})))

def Laws.local_readers(outgoing):
  ({==}, ({==}, ({==}, {==})))

# By computation: each hexadecimal reader is defined as the digits of the
# value reader.
def Laws.hex_readers(context):
  ({==}, {==})

# Context
# -------

# Opening the record shows that setting replaces its span context, whatever
# it was.
def Laws.context_set_then_read(context, span_context):
  match context:
    case Api.Context{previous}:
      {==}

def Laws.context_empty():
  {==}

# Opening the record shows that clearing removes its span context, whatever
# it was.
def Laws.context_cleared(context):
  match context:
    case Api.Context{previous}:
      {==}
