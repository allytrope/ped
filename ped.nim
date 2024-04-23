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
  ped <file> [((-p <probands> | -P <file>) -d <int>)] [options]

Options:
  -h, --help                                 Show this screen.
  -d <int>, --degree <int>                   Filter relatives by number of minimum (parent-child) connections away,
                                             a.k.a, the shortest-path distance.
  -f, --force-probands                       No error if proband is missing from pedigree.
  -O <output_type>                           Can be "l" for list, "t" for 3-columned TSV, or "p" for PLINK-style TSV.
  -p <probands>, --probands <probands>       The probands from which relatives are determined.
  -P <file>, --probands-file <file>          File containing one proband per line.
"""

var args: Table[string, Value]
try:
  args = docopt(doc)
except DocoptExit:
  quit "ERROR: Error parsing."

# Read input file
var individuals = read_tsv($args["<file>"])  # Can't be var, but why?

# Get probands as strings
var proband_strings: seq[string]
if args["--probands"]:
  proband_strings = ($args["--probands"]).split(",")
elif args["--probands-file"]:
  # TODO: Improve on reading file
  proband_strings = readFile($args["--probands-file"]).split("\n")[0..^2]  # Skips last terminating line.

# Find corresponding proband objects
var
  proband: Individual
  probands: seq[Individual]
for indiv in proband_strings:
  try:
    proband = individuals[Individual(id: indiv)]
    probands.add(proband)
  except KeyError:
    if args["--force-probands"]:
      continue
    else:
      quit fmt"ERROR: {indiv} not in pedigree."

# Find relatives
var subset: HashSet[Individual]
if args["--degree"]:
    let degree = to_int(parse_float($args["--degree"]))
    subset = relatives_by_degree(probands, degree)

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
