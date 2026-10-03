import Base

# Environment reads under node. An unset variable loads bun:ffi whatever the
# program does with the failed result, so a read needs a guaranteed value:
# the first is unguarded, the second claims a guarantee without saying who
# gives it, and only the third states one. A guarantee covers an environment
# read and nothing else: the sleep that follows is flagged all the same.
def main() -> IO(Unit):
  do IO<Unit>:
    first : Result<&1, &1, U32 & String, String> <- IO.get_env("OTEL_SERVICE_NAME")
    second : Result<&1, &1, U32 & String, String> <- IO.get_env("HOME") # lanes: guaranteed by
    third : Result<&1, &1, U32 & String, String> <- IO.get_env("NODE_JOB") # lanes: guaranteed by the node job, which exports NODE_JOB
    IO.sleep(1) # lanes: guaranteed by the node job, which has no clock to give
    IO.print("read")
