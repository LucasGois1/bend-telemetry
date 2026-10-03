# Proofs: timestamps
# ==================
#
# Timestamp.from_unix passes the check that the nanoseconds are below one
# second to Timestamp.from_unix.checked, and `match` cannot inspect a
# computed value, so the reader lemmas rewrite the check with the law's
# hypothesis and let the checker compute. cmp_self reads the two
# reflexivities, of Nat.cmp (proofs/nats.bend) and of Word.cmp
# (proofs/strings.bend), for the seconds and the nanoseconds. PROOF.bend
# proves the laws timestamp_readers and timestamp_self with these.

import Base
import ../api.bend as Api
import ./nats.bend as NatsProof
import ./strings.bend as StringsProof

# The seconds given are read back when the nanoseconds are below one second.
law seconds_kept:
  for +seconds: Nat
  for +nanoseconds: U32
  for below: {U32.is_lt(nanoseconds, 1000000000) == True{} : Bool}
  {Api.Timestamp.seconds(Api.Timestamp.from_unix(seconds, nanoseconds)) == seconds : Nat}

def seconds_kept(seconds, nanoseconds, below):
  %Equal.sym(Bool, U32.is_lt(nanoseconds, 1000000000), True{}, below) :
    {Api.Timestamp.seconds(Api.Timestamp.from_unix.checked(seconds, nanoseconds, _)) == seconds : Nat}
  {==}

# The nanoseconds given are read back when they are below one second.
law nanoseconds_kept:
  for +seconds: Nat
  for +nanoseconds: U32
  for below: {U32.is_lt(nanoseconds, 1000000000) == True{} : Bool}
  {Api.Timestamp.nanoseconds(Api.Timestamp.from_unix(seconds, nanoseconds)) == nanoseconds : U32}

def nanoseconds_kept(seconds, nanoseconds, below):
  %Equal.sym(Bool, U32.is_lt(nanoseconds, 1000000000), True{}, below) :
    {Api.Timestamp.nanoseconds(Api.Timestamp.from_unix.checked(seconds, nanoseconds, _)) == nanoseconds : U32}
  {==}

# Every timestamp compares EQ with itself: its seconds do (NatsProof.cmp_refl)
# and the word of its nanoseconds does (StringsProof.word_cmp_refl).
law cmp_self:
  for +timestamp: Api.Timestamp
  {Api.Timestamp.cmp(timestamp, timestamp) == EQ{} : Cmp}

def cmp_self(timestamp):
  match timestamp:
    case Api.Timestamp{+seconds, U32{+word}}:
      %Equal.sym(Cmp, Nat.cmp(seconds, seconds), EQ{}, NatsProof.cmp_refl(seconds)) :
        {Api.Timestamp.cmp.fin(_, Word.cmp(32n, word, word)) == EQ{} : Cmp}
      %Equal.sym(Cmp, Word.cmp(32n, word, word), EQ{}, StringsProof.word_cmp_refl(32n, word)) :
        {Api.Timestamp.cmp.fin(EQ{}, _) == EQ{} : Cmp}
      {==}

# Every timestamp is the same instant as itself.
law is_eq_self:
  for +timestamp: Api.Timestamp
  {Api.Timestamp.is_eq(timestamp, timestamp) == True{} : Bool}

def is_eq_self(timestamp):
  %Equal.sym(Cmp, Api.Timestamp.cmp(timestamp, timestamp), EQ{}, cmp_self(timestamp)) :
    {Cmp.is_eq(_) == True{} : Bool}
  {==}
