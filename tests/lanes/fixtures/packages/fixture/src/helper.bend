import Base

# Reached through the package's entry module, two imports away from the
# program: the lint follows imports all the way down.
def report() -> IO(Unit):
  do IO<Unit>:
    socket : Result<&1, &1, U32 & String, Socket> <- TCP.connect("127.0.0.1", 4317)
    IO.print("reported")
