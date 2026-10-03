import Base

# A module whose definition waits: a program that imports it cannot run under
# node, although the program itself names no such effect.
def nap() -> IO(Unit):
  do IO<Unit>:
    answer : Maybe<&1, Unit> <- IO.within(Unit, 10, IO.pure(Unit, Unit{}))
    IO.print("napped")
