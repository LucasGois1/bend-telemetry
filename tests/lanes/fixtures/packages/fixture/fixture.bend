# A package of the fixtures: bend-telemetry-fixture, whose entry module starts a
# process and imports a helper by a relative path.
import Base
import ./src/helper.bend as Helper

def run_tool() -> IO(Unit):
  do IO<Unit>:
    outcome : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("true", Nil{}, "", 1, 1000)
    Helper.report()
