import Base
import bend-trace-context@0.2.0.0/trace_context.bend as TC
import 0x0123456789abcdef0123456789abcdef/main.bend as Hashed

# Imports that the lint cannot read, a package of another repository and a
# package by hash: it names them in a note and does not follow them. The hash
# is made up; this file is read as text and never compiled.
def main() -> IO(Unit):
  IO.print("foreign")
