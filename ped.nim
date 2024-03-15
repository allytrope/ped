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
  ped relatives <file> <proband> [--degree <int>]

Options:
  -h, --help                                 Show this screen.
  -d <int>, --degree <int>                   Filter relatives by number of minimum (parent-child) connections away,
                                             a.k.a, the shortest-path distance.

Subcommands:
  relatives  Find relatives.
"""

var args: Table[string, Value]
try:
  args = docopt(doc)
except DocoptExit:
  quit "Error parsing."

var individuals: HashSet[Individual]
individuals = read_csv($args["<file>"])

if args["<proband>"]:
  let proband = individuals[Individual(id: $args["<proband>"])]

  if args["--degree"]:
    let degree = to_int(parse_float($args["--degree"]))
    let relatives = relatives_by_degree(proband, degree)
    write_list(relatives)