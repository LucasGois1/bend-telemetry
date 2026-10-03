import Base

# Names that look like effects but are not uses of one. This comment says
# IO.sleep, Process.run, TCP.connect and IO.get_env, and the lint ignores it.
def label() -> String:
  "IO.sleep waits # and this is no comment"

def poem() -> String:
  "A string may span lines: this one mentions IO.sleep,
and then # File.open, and ends here."

def separator() -> Char:
  '#'

def Semconv.File.size() -> String:
  "file.size"

def Semconv.Process.run() -> String:
  "process.run"

def IO.sleep_ms(ms: U32) -> String:
  "IO.sleep_ms"

def File.reads() -> String:
  "File.reads"

def File.read.go() -> String:
  "File.read.go"

def lookalikes() -> List<&2, String>:
  [Semconv.File.size(), Semconv.Process.run(), IO.sleep_ms(1), File.reads(), File.read.go()] # IO.within
