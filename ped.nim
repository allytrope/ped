import
  docopt,
  std/[hashes, tables, sets, strformat, strutils, terminal],
  io, relatives

# Check for stdin
if not isatty(stdin):
  # TODO: Allow for passing pedigree file through stdin
  raise newException(IOError, "Passing though stdin is not implemented.")

let doc = """
For extracting data from pedigree file.

Usage:
  ped <file> [options]

Options:
  -h, --help                                 Show this screen.
  -d <int>, --degree <int>                   Filter relatives by number of minimum (parent-child) connections away,
                                             a.k.a, the shortest-path distance.
  -f, --force-probands                       No error if proband is missing from pedigree.
  -O <output_type>                           Can be "l" for list, "t" for 3-columned TSV, or "p" for PLINK-style TSV.
  -p <probands>, --probands <probands>       The probands from which relatives are determined.
"""

var args: Table[string, Value]
try:
  args = docopt(doc)
except DocoptExit:
  quit "ERROR: Error parsing."

var
  degree: int
  individuals: HashSet[Individual]
  subset: HashSet[Individual]

individuals = read_tsv($args["<file>"])

if args["--probands"]:
  if not args["--degree"]:
    quit "ERROR: Must specify '--degree <int>' when using '--probands <probands>'."

  var
    proband: Individual
    probands: seq[Individual]
  for indiv in ($args["--probands"]).split(","):
    try:
      proband = individuals[Individual(id: indiv)]
      probands.add(proband)
    except KeyError:
      if args["--force-probands"]:
        continue
      else:
        quit fmt"ERROR: {indiv} not in pedigree."
  degree = to_int(parse_float($args["--degree"]))
  subset = relatives_by_degree(probands, degree)
else:
  if args["--degree"]:
    quit "ERROR: Must specify '--probands <indiv>' when using '--degree <int>'."
  subset = individuals

# Determine output type
case $args["-O"]:
  of "l":
    write_list(subset)
  of "p":
    write_plink(subset)
  of "t":
    write_tsv(subset)
  else:
    write_tsv(subset)
