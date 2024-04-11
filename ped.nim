import
  docopt,
  std/[hashes, tables, sets, strutils, terminal],
  io, relatives

# Check for stdin
if not isatty(stdin):
  # TODO: Allow for passing pedigree file through stdin
  raise newException(IOError, "Passing though stdin is not implemented.")

let doc = """
For extracting data from pedigree file.

Usage:
  ped relatives <file> <proband> [--degree <int>, -O <output_type>]

Options:
  -h, --help                                 Show this screen.
  -d <int>, --degree <int>                   Filter relatives by number of minimum (parent-child) connections away,
                                             a.k.a, the shortest-path distance.
  -O <output_type>                           Can be "l" for list, "t" for 3-columned TSV, or "p" for PLINK-style TSV     
Subcommands:
  relatives  Find relatives.
"""

var args: Table[string, Value]
try:
  args = docopt(doc)
except DocoptExit:
  quit "Error parsing."

var
  degree: int
  individuals: HashSet[Individual]
  subset: HashSet[Individual]

individuals = read_tsv($args["<file>"])

if args["<proband>"]:
  let proband = individuals[Individual(id: $args["<proband>"])]

  if args["--degree"]:
    degree = to_int(parse_float($args["--degree"]))
    subset = relatives_by_degree(proband, degree)

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
