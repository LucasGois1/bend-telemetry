import Base
  import ./sleeper.bend as Sleeper

# Bend accepts an import that is indented, and a module that this program
# imports that way still waits: the lint finds imports at any indentation.
def main() -> IO(Unit):
  Sleeper.nap()
