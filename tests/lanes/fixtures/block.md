# A document with a marked block that sleeps

Prose may say IO.sleep: the lint reads only the code block that the document
marks, as scripts/doc-block.sh does.

<!-- test:slow:start -->
```bend
import Base

def main() -> IO(Unit):
  do IO<Unit>:
    IO.sleep(5)
```
<!-- test:slow:end -->
