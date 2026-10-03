import Base
import bend-telemetry-fixture@0.1.0.0/fixture.bend as Fixture

# A program that imports a package of this repository by its BendHub name: the
# lint follows it into the package's directory, which the test names with
# --packages. The package lives beside this file, under packages/fixture/.
def main() -> IO(Unit):
  Fixture.run_tool()
