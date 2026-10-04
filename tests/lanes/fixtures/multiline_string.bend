import Base

# A string that spans lines hides the names it holds, such as IO.within, but
# not the code after its closing quote.
def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("this string spans lines and says IO.within
before it ends")
    IO.sleep(1)
