import Base
import ./sleeper.bend as Sleeper

# A program that names no effect that waits itself but imports a module that
# does: the lint follows relative imports.
def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("before")
    Sleeper.nap()
