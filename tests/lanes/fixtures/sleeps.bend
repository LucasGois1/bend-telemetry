import Base

# A program listed for node that sleeps: the lane lint must refuse it. Node
# has no bun:ffi, which IO.sleep loads, so this program fails there with
# "Cannot find module 'bun:ffi'" after printing its first line.
def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("before")
    IO.sleep(10)
    IO.print("after")
