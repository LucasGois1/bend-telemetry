import Base

# A def of the program's own whose body imports a C and a JavaScript file:
# foreign code, which the lint does not read and says so. This file is read as
# text and never compiled; the files it names do not exist.
def Clock.tick() -> IO(U32):
  import "./clock.c"
  import "./clock.js"

def main() -> IO(Unit):
  IO.print("tick")
