import Base
import ./missing.bend as Missing
import Elsewhere

# Imports that the lint cannot follow: a module that does not exist and a form
# it does not know. It fails rather than vouch for code it has not read.
def main() -> IO(Unit):
  IO.print("unreadable")
