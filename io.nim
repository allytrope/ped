import
  std/[algorithm, options, sequtils, sets, strformat, strutils, sugar, tables],
  relatives


type
  MissingFieldError = object of CatchableError  # Is "catchable" the correct term?
  InconsistentSexError = object of ValueError

proc read_file(file: File, fields: openArray[string], empty: string): HashSet[Individual] =
  #[Generalized text file reader for reading pedigree data.]#
  var
    individuals: HashSet[Individual]
    id_idx: int
    sire_idx: int
    dam_idx: int
    sex_idx: int

  # Find fields for each variable in input file. Otherwise, assign the empty value.
  #for value in ["id", ]

  id_idx = fields.find("id")
  if id_idx == -1:
    raise newException(MissingFieldError, "The 'id' field is required.")
  sire_idx = fields.find("sire")
  if sire_idx == -1:
    raise newException(MissingFieldError, "The 'sire' field is required.")
  dam_idx = fields.find("dam")
  if dam_idx == -1:
    raise newException(MissingFieldError, "The 'dam' field is required.")
  sex_idx = fields.find("sex")

  # try:
  #   aff_idx = fields.find("aff")
  # except KeyError:
  #   aff_idx = nil

  for line in lines(file):
    if line.startsWith("#"):
      continue
    let
      split = line.split("\t")    
      id = split[id_idx]
      sire = split[sire_idx]
      dam = split[dam_idx]
    var sex: Sex
    # Assign sex
    if sex_idx != -1:
      if split[sex_idx] in ["male", "Male", "1"]:
        sex = male
      elif split[sex_idx] in ["female", "Female", "2"]:
        sex = female
      else:
        sex = unknown
    else:
      sex = unknown

    # Create object for sire
    var sire_obj: Option[Individual]
    if sire == empty:
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
        # Update sex if already in HashSet or error if inconsistent
        case individuals[sire_obj.get()].sex:
          of unknown:
            individuals[sire_obj.get()].sex = male
          of female:
            raise newException(InconsistentSexError, fmt"Individual {individuals[sire_obj.get()].id} appears as both male and female.")
          else:
            discard
        sire_obj = some(individuals[sire_obj.get()])
      else:
        individuals.incl(sire_obj.get())

    # Create object for dam
    var dam_obj: Option[Individual]
    if dam == empty:
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
        # Update sex if already in HashSet or error if inconsistent
        case individuals[dam_obj.get()].sex:
          of unknown:
            individuals[dam_obj.get()].sex = female
          of male:
            raise newException(InconsistentSexError, fmt"Individual {individuals[dam_obj.get()].id} appears as both male and female.")
          else:
            discard
        dam_obj = some(individuals[dam_obj.get()])
      else:
        individuals.incl(dam_obj.get())

    # Create object for child
    let child = Individual(
        id: id,
        sire: sire_obj,
        dam: dam_obj,
        children: initHashSet[Individual](),
        sex: sex
    )
    # Update existing record
    if child in individuals:
      individuals[child].sire = sire_obj
      individuals[child].dam = dam_obj
    # Check for inconsistency with sex
      # if (individuals[child].sex != unknown) and (individuals[child].sex != sex):
      #   raise newException(InconsistentSexError, fmt"Individual {child.id} appears as both male and female.")
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

proc read_tsv*(file: File): HashSet[Individual] =
  #[Read a 3-column TSV of trios.]#
  return read_file(file = file, fields = @["id", "sire", "dam"], empty = "")

proc read_plink*(file: File): HashSet[Individual] =
  #[Read a PLINK-style TSV.]#
  return read_file(file = file, fields = @["fam", "id", "sire", "dam", "sex", "aff"], empty = "0")

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

    # When parents are missing and is already listed as a parent of another, don't include
    if sire_id == "" and dam_id == "":
      block singleton:
        for individual in individuals:
          try:
            if individual.sire.get() == indiv:
              break singleton
          except UnpackDefect:
            discard
          try:
            if individual.dam.get() == indiv:
              break singleton
          except UnpackDefect:
            discard
        echo &"{indiv.id}\t\t"
    else:
      echo &"{indiv.id}\t{sire_id}\t{dam_id}"
      included_individuals.incl(indiv)

proc write_matrix*(individuals: HashSet[Individual]) =
  #[Write relationship coefficients as a matrix.]#
  let sorted_individuals = individuals.toSeq().sorted(cmp=cmpIndividuals)

  # Write header row
  let header = sorted_individuals.map(indiv => indiv.id).join("\t")
  echo &"\t{header}"

  for indiv in sorted_individuals:
    var coefficients = find_coefficients(indiv)

    # Fill in all missing pairs
    for indiv2 in sorted_individuals:
      try:
        discard coefficients[indiv2]
      except KeyError:
        # Report value as 0
        coefficients[indiv2] = 0
    let row = sorted_individuals.map(indiv => coefficients[indiv]).join("\t")
    echo &"{indiv.id}\t{row}"

proc write_pairwise*(individuals: HashSet[Individual]) =
  #[Write relationship coefficients as a pairwise TSV.]#
  let sorted_individuals = individuals.toSeq().sorted(cmp=cmpIndividuals)
  for indiv in sorted_individuals:
    var coefficients = find_coefficients(indiv)
    for indiv2 in sorted_individuals:
      try:
        echo &"{indiv.id}\t{indiv2.id}\t{coefficients[indiv2]}"
      except KeyError:
        # Report value as 0
        echo &"{indiv.id}\t{indiv2.id}\t0"
        