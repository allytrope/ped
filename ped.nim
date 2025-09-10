import
  docopt,
  std/[enumerate, hashes, options, sets, strformat, strutils, tables, terminal],
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
  -I <format>                                     Input format; can "p" for PLINK-style TSV or by default a 3-columned TSV
  -m, --mates                                     Include mates.
  -n, --intersection                              Find intersection of filterings on each proband (as opposed to the union).
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

# Find and read input file
var
  individuals: HashSet[Individual]
  filename: string
  f: File
block read:
  if args["<file>"]:
    filename = $args["<file>"]
    f = open(filename, fmRead)
  elif not isatty(stdin):
    f = stdin
  else:
    raise newException(IOError, "Must pass pedigree file as either positional argument or through stdin.")
  defer: close(f)
  # First check if `-I` is specified
  if args["-I"]:
    case $args["-I"]:
      of "h":
        individuals = read_headered(f)
      of "p":
        individuals = read_plink(f)
      of "t":
        individuals = read_tsv(f)
      else:
        individuals = read_tsv(f)
  # Second check file suffix
  elif args["<file>"]:
    case filename.split(".")[^1]:
      of "fam":
        individuals = read_plink(f)
      of "ped":
        individuals = read_plink(f)
      of "trios":
        individuals = read_tsv(f)
      else:
        individuals = read_headered(f)
  # Otherwise, assume headered TSV
  else:
    individuals = read_headered(f)

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
      #quit fmt"ERROR: {indiv} not in pedigree."
      raise newException(Exception, fmt"ERROR: {indiv} not in pedigree.")

# Determine whether to take union or intersection of probands' relatives
var set_operation = union[Individual]
if args["--intersection"]:
  set_operation = intersection[Individual]

### Subsetting generalizations
proc subset_kin(kin: proc) =
  #[Find either union or intersection of relatives using a specific filtering method.]#
  var combined_kin: HashSet[Individual]
  for idx, proband in enumerate(probands):
    if idx == 0:
      combined_kin.incl(proband.kin())
    else:
      combined_kin = combined_kin.set_operation(proband.kin())
  individuals = individuals.intersection(combined_kin)
proc subset_kin(kin: proc, coefficient: float) =
  #[Find either union or intersection of relatives using a specific filtering method.]#
  var combined_kin: HashSet[Individual]
  for idx, proband in enumerate(probands):
    if idx == 0:
      combined_kin.incl(kin(proband, coefficient))
    else:
      combined_kin = combined_kin.set_operation(kin(proband, coefficient))
  individuals = individuals.intersection(combined_kin)
proc subset_kin(kin: proc, coefficient: int) =
  #[Find either union or intersection of relatives using a specific filtering method.]#
  var combined_kin: HashSet[Individual]
  for idx, proband in enumerate(probands):
    if idx == 0:
      combined_kin.incl(kin(proband, coefficient))
    else:
      combined_kin = combined_kin.set_operation(kin(proband, coefficient))
  individuals = individuals.intersection(combined_kin)

# Find relatives by filtering method
if args["--degree"]:
  let degree = to_int(parse_float($args["--degree"]))
  subset_kin(relatives_by_degree, degree)
if args["--relationship-coefficient"]:
  let coefficient = parse_float($args["--relationship-coefficient"])
  subset_kin(filter_relatives, coefficient)

# Restrict to only ancestors or descendants (including proband(s))
if args["--ancestors"]:
  subset_kin(ancestors)
if args["--descendants"]:
  subset_kin(descendants)

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
