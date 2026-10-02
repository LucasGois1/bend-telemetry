import Base
import bend-telemetry-api@0.1.0.0/api.bend as Api

# The independent consumer: an application that depends on the published
# package by its BendHub name and version, as every adopter will. This file
# belongs to the application, not to the package; scripts/test-consumer.sh
# runs it against a clean clone served by the local hub and compares its
# output with expected.txt.

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("package: " ++ Api.Package.name())
    IO.print("fields: " ++ String.join(Api.TraceContext.fields(), ", "))
