import
  docopt,
  std/[hashes, options, sets, strformat, strutils, tables, terminal],
  io, relatives


let doc = """
For extracting data from pedigree file.

Usage:
  ped <file> [options]
  ped [options]

Options:
  -h, --help                                      Show this screen.
  -a, --ancestors                                 Keep only probands and ancestors (not compatible with -b).
  -b, --descendants                               Keep only probands and descendents (not compatible with -a).         
  -d <int>, --degree <int>                        Filter relatives by number of minimum (parent-child) connections away,
                                                  a.k.a, the shortest-path distance.
  -f, --force-probands                            No error if proband is missing from pedigree.
  -m, --mates                                     Include mates.
  -O <format>                                     Can be "l" for list, "m" for matrix, "p" for PLINK-style TSV,
                                                  "t" for 3-columned TSV, or "w" for pairwise.
  -P <file>, --probands-file <file>               File containing one proband per line.
  -p <probands>, --probands <probands>            The probands from which relatives are determined.
  -r <float>, --relationship-coefficient <float>  Filter relatives by minimum coefficient of relationship.
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
if args["--degree"]:
    let degree = to_int(parse_float($args["--degree"]))
    individuals = individuals.intersection(relatives_by_degree(probands, degree))
if args["--relationship-coefficient"]:
    let coefficient = parse_float($args["--relationship-coefficient"])
    individuals = individuals.intersection(filter_relatives(probands, coefficient))

# Optionally restrict to only ancestors or descendants (including proband(s))
if args["--ancestors"]:
  var combined_ancestors: HashSet[Individual]
  for proband in probands:
    combined_ancestors.incl(proband.ancestors())
  individuals = individuals.intersection(combined_ancestors)
if args["--descendants"]:
  var combined_descendants: HashSet[Individual]
  for proband in probands:
    combined_descendants.incl(proband.descendants())
  individuals = individuals.intersection(combined_descendants)

# Add back mates
if args["--mates"]:
  var mates: HashSet[Individual]
  for individual in individuals:
      try:
        if individual.sire.get() in individuals:
          mates.incl(individual.dam.get())
      except UnpackDefect:
        discard
      try:
        if individual.dam.get() in individuals:
          mates.incl(individual.sire.get())
      except UnpackDefect:
        discard
  individuals = individuals.union(mates)

# Determine output type
case $args["-O"]:
  of "l":
    write_list(individuals)
  of "m":
    write_matrix(individuals)
  of "p":
    write_plink(individuals)
  of "t":
    write_tsv(individuals)
  of "w":
    write_pairwise(individuals)
  else:
    write_tsv(individuals)
