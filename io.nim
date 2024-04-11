import
  std/[algorithm, options, sequtils, sets, strformat, strutils],
  relatives

proc read_tsv*(file: string): HashSet[Individual] =
  #[Read from 3-columned TSV, where the columns are in the order child, sire, and dam.]#
  var individuals: HashSet[Individual]

  var f = open(file, fmRead)
  defer: close(f)
  for line in lines(f):
    if line.startsWith("#"):
      continue
    let split = line.split("\t")
    let id = split[0]
    let sire = split[1]
    let dam = split[2]

    # Create object for sire
    var sire_obj: Option[Individual]
    if sire == "":
      sire_obj = none(Individual)
    else:
      sire_obj = some(Individual(
          id: sire,
          sire: none(Individual),
          dam: none(Individual),
          children: initHashSet[Individual](),
          sex: male
        ))

      if individuals.contains(sire_obj.get()):
        # Update sex if already in HashSet
        individuals[sire_obj.get()].sex = male
        sire_obj = some(individuals[sire_obj.get()])
      else:
        individuals.incl(sire_obj.get())

    # Create object for dam
    var dam_obj: Option[Individual]
    if dam == "":
      dam_obj = none(Individual)
    else:
      dam_obj = some(Individual(
          id: dam,
          sire: none(Individual),
          dam: none(Individual),
          children: initHashSet[Individual](),
          sex: female
        ))

      if individuals.contains(dam_obj.get()):
        # Update sex if already in HashSet
        individuals[dam_obj.get()].sex = female
        dam_obj = some(individuals[dam_obj.get()])
      else:
        individuals.incl(dam_obj.get())

    # Create object for child
    let child = Individual(
        id: id,
        sire: sire_obj,
        dam: dam_obj,
        children: initHashSet[Individual](),
        sex: unknown
    )
    # Update existing record
    if child in individuals:
      individuals[child].sire = sire_obj
      individuals[child].dam = dam_obj
    # Else add new record
    else:
      individuals.incl(child)

  # Add children to records
  for individual in individuals:
    if individual.sire.isSome:
      individuals[individual.sire.get()].children.incl(individual)
    if individual.dam.isSome:
      individuals[individual.dam.get()].children.incl(individual)

  return individuals

proc write_list*(individuals: HashSet[Individual]) =
  #[Write individuals, one individual per line.]#
  let sequence = individuals.toSeq().sorted(cmp=cmpIndividuals)

  for indiv in sequence:
    echo indiv.id

proc write_plink*(individuals: HashSet[Individual]) =
  #[Write individuals to PLINK-style TSV.
  
  Has five columns: family, child, sire, dam, sex, and affected status.
  Family and affected status, however, are constant.]#

  let sequence = individuals.toSeq().sorted(cmp=cmpIndividuals)
  var included_individuals: HashSet[Individual]

  # Set all animals to same family with unknown affected status
  let
    family = "1"
    affected = "0"

  var
    sire_id: string
    dam_id: string
    sex: string

  for indiv in sequence:
    # Set parents and sex as missing initially
    sire_id = "0"
    dam_id = "0"
    sex = "0"

    if indiv.sire.isSome():
      if indiv.sire.get() in sequence:
        sire_id = indiv.sire.get().id
        included_individuals.incl(indiv.sire.get())
    if indiv.dam.isSome():
      if indiv.dam.get() in sequence:
        dam_id = indiv.dam.get().id
        included_individuals.incl(indiv.dam.get())
    case indiv.sex:
      of male:
        sex = "1"
      of female:
        sex = "2"
      else:
        sex = "0"

    echo &"{family}\t{indiv.id}\t{sire_id}\t{dam_id}\t{sex}\t{affected}"
    included_individuals.incl(indiv)

proc write_tsv*(individuals: HashSet[Individual]) =
  #[Write individuals to TSV.]#

  # Print only proband if it is the only relative.
  if len(individuals) == 1:
    for indiv in individuals:
      echo &"{indiv.id}\t\t"
    return

  let sequence = individuals.toSeq().sorted(cmp=cmpIndividuals)
  var included_individuals: HashSet[Individual]

  for indiv in sequence:
    var 
      sire_id: string
      dam_id: string
    if indiv.sire.isSome():
      if indiv.sire.get() notin sequence:
        sire_id = ""
      else:
        sire_id = indiv.sire.get().id
        included_individuals.incl(indiv.sire.get())
    else:
      sire_id = ""
    if indiv.dam.isSome():
      if indiv.dam.get() notin sequence:
        dam_id = ""
      else:
        dam_id = indiv.dam.get().id
        included_individuals.incl(indiv.dam.get())
    else:
      dam_id = ""

    # Remove if parents are missing and is already listed as a parent of another
    if sire_id == "" and dam_id == "":
      discard
    else:
      echo &"{indiv.id}\t{sire_id}\t{dam_id}"
      included_individuals.incl(indiv)
