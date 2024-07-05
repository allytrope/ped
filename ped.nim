import
  docopt,
  std/[hashes, tables, sets, strformat, strutils, terminal],
  io, relatives


let doc = """
For extracting data from pedigree file.

Usage:
  ped <file> [options]
  ped [options]

Options:
  -h, --help                                      Show this screen.
  -a, --ancestors                                 Keep only probands and ancestors (invalid to -a).
  -b, --descendants                               Keep only probands and descendents.         
  -d <int>, --degree <int>                        Filter relatives by number of minimum (parent-child) connections away,
                                                  a.k.a, the shortest-path distance.
  -f, --force-probands                            No error if proband is missing from pedigree.
  -O <format>                                     Can be "l" for list, "m" for matrix, "p" for PLINK-style TSV,
                                                  "t" for 3-columned TSV, or "w" for pairwise.
  -P <file>, --probands-file <file>               File containing one proband per line.
  -p <probands>, --probands <probands>            The probands from which relatives are determined.
  -r <float>, --relationship-coefficient <float>  Filter relatives by minium coefficient of relationship.
"""

var args: Table[string, Value]
try:
  args = docopt(doc)
except DocoptExit:
  quit "ERROR: Error parsing."

# Validate some options
if args["--ancestors"] and args["--descendants"]:
  raise newException(Exception, "`-a` and `-b` are mutally exclusive.")
if args["--probands"] and args["--probands-file"]:
  raise newException(Exception, "`-p` and `-P` are mutally exclusive.")
if args["--force-probands"] and not (args["--probands"] or args["--probands-file"]):
  raise newException(Exception, "`-f` requires either `-p` or `-P`.")

# Read input file
var individuals: HashSet[Individual]
if args["<file>"]:
  # This IOError is being raised unnecessarily during process substitution
  # # Verify that there is no stdin
  # if not isatty(stdin):
  #   raise newException(IOError, "Can't pass pedigree file through both positional argument and stdin.")
  let f = open($args["<file>"], fmRead)
  defer: close(f)
  individuals = read_tsv(f)
elif not isatty(stdin):
  individuals = read_tsv(stdin)
else:
  raise newException(IOError, "Must pass pedigree file as either positional argument or through stdin.")

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

# Find relatives by filtering method
var subset: HashSet[Individual]
if args["--degree"]:
    let degree = to_int(parse_float($args["--degree"]))
    subset = relatives_by_degree(probands, degree)
elif args["--relationship-coefficient"]:
    let coefficient = parse_float($args["--relationship-coefficient"])
    subset = filter_relatives(probands, coefficient)
else:
  subset = individuals

# Optionally restrict to only ancestors or descendants (including proband(s))
if args["--ancestors"]:
  var combined_ancestors: HashSet[Individual]
  for proband in probands:
    combined_ancestors.incl(proband.ancestors())
  subset = subset.intersection(combined_ancestors)
if args["--descendants"]:
  var combined_descendants: HashSet[Individual]
  for proband in probands:
    combined_descendants.incl(proband.descendants())
  subset = subset.intersection(combined_descendants)

# Determine output type
case $args["-O"]:
  of "l":
    write_list(subset)
  of "m":
    write_matrix(subset)
  of "p":
    write_plink(subset)
  of "t":
    write_tsv(subset)
  of "w":
    write_pairwise(subset)
  else:
    write_tsv(subset)
