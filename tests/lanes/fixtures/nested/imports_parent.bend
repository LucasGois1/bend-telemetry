import Base
import ../sleeper.bend as Sleeper

# A module that this program imports from the directory above waits: the lint
# follows imports that go up with `..` as well.
def main() -> IO(Unit):
  Sleeper.nap()
