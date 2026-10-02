import Base
import ./LAWS.bend as Laws

# Proofs of the laws of bend-telemetry-api
# ========================================
#
# Each `def Laws.<name>` proves `law <name>` of LAWS.bend. A proposition is a
# type and a proof is a definition of that type; `{==}` proves an equality
# whose sides compute to the same term.

def Laws.name():
  {==}

def Laws.context_fields():
  {==}
