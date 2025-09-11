import
  std/[algorithm, enumerate, options, sequtils, sets, strformat, strutils, sugar, tables],
  relatives


type
  MissingFieldError = object of CatchableError  # TODO: Is "catchable" the correct term?
  InconsistentSexError = object of ValueError

proc read_file(file: File, fields: openArray[string], empty: string, header: bool): HashSet[Individual] =
  #[Generalized text file reader for reading pedigree data.]#
  var
    column2index: Table[string, int]
    individuals: HashSet[Individual]
    parent_objs: array[2, Option[Individual]]

  # Parse fields argument if not empty
  if fields.len() > 0:
    # Search for mandatory fields
    for field in ["id", "sire", "dam"]:
      column2index[field] = fields.find(field)
      if column2index[field] == -1:
        raise newException(MissingFieldError, fmt"The '{field}' field is required.")
    # Search for optional fields
    for field in ["sex"]:
      if fields.find(field) != -1:
        column2index[field] = fields.find(field)
  # Parse header (if present)
  elif header == true:
    # Lowercase conversions
    let header_key = {
      "id": "id",
      "indiv": "id",
      "individual": "id",      
      "proband": "id",
      "child": "id",
      "offspring": "id",
      "sire": "sire",
      "father": "sire",
      "pat": "sire",
      "paternal": "sire",
      "dam": "dam",
      "mother": "dam",
      "mat": "dam",
      "maternal": "dam",
      "sex": "sex",
    }.toTable
    # Map headers to fields
    # Skip comments prior to header
    for line in lines(file):
      if line.startsWith("#"):
        continue
      else:
        for idx, column_name in enumerate(line.split("\t")):
          try:
            column2index[header_key[column_name.toLower()]] = idx
          except:
            continue
        break
    # Verify that mandatory fields are present
    for field in ["id", "sire", "dam"]:
      try:
        discard column2index[field]
      except KeyError:
        raise newException(MissingFieldError, fmt"The '{field}' field is required.")
  
  # Read the rest of the file
  for line in lines(file):
    # Skip any other commented lines
    if line.startsWith("#"):
      continue
    let
      split = line.split("\t")    
      id = split[column2index["id"]]
      sire = split[column2index["sire"]]
      dam = split[column2index["dam"]]
    var sex: Sex
    # Assign sex
    if column2index.hasKey("sex"):
      let input_sex = split[column2index["sex"]].toLower()
      case input_sex:
      of "male", "m", "1":
        sex = male
      of "female", "f", "2":
        sex = female
      of "unknown", "unk", "u", "0", "-9", "":
        sex = unknown
      else:
        raise newException(ValueError, &"The sex '{input_sex}' cannot be interpreted.")
    else:
      sex = unknown

    # Create parental objects
    for (idx, parent, parent_sex) in [(0, sire, male), (1, dam, female)]:
      var parent_obj: Option[Individual]
      if parent == empty:
        parent_obj = none(Individual)
      else:
        parent_obj = some(Individual(
            id: parent,
            sire: none(Individual),
            dam: none(Individual),
            children: initHashSet[Individual](),
            sex: parent_sex
          ))

        if individuals.contains(parent_obj.get()):
          # Update sex if already in HashSet or error if inconsistent
          if individuals[parent_obj.get()].sex == unknown:
            individuals[parent_obj.get()].sex = parent_sex
          else:
            if individuals[parent_obj.get()].sex != parent_sex:
              raise newException(InconsistentSexError, fmt"Individual {individuals[parent_obj.get()].id} appears as both male and female.")
          parent_obj = some(individuals[parent_obj.get()])
        else:
          individuals.incl(parent_obj.get())
      parent_objs[idx] = parent_obj

    # Create object for child
    let child = Individual(
        id: id,
        sire: parent_objs[0],
        dam: parent_objs[1],
        children: initHashSet[Individual](),
        sex: sex
    )
    # Update existing record
    if child in individuals:
      individuals[child].sire = parent_objs[0]
      individuals[child].dam = parent_objs[1]
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

proc read_headered*(file: File): HashSet[Individual] =
  #[Read a 3-column TSV of trios.]#
  return read_file(file = file, fields = @[], empty = "", header=true)

proc read_trios*(file: File): HashSet[Individual] =
  #[Read a 3-column TSV of trios.]#
  return read_file(file = file, fields = @["id", "sire", "dam"], empty = "", header=false)

proc read_plink*(file: File): HashSet[Individual] =
  #[Read a PLINK-style TSV.]#
  return read_file(file = file, fields = @["fam", "id", "sire", "dam", "sex", "aff"], empty = "0", header=false)

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
    if indiv.dam.isSome():
      if indiv.dam.get() in sequence:
        dam_id = indiv.dam.get().id
    case indiv.sex:
    of male:
      sex = "1"
    of female:
      sex = "2"
    else:
      sex = "0"

    echo &"{family}\t{indiv.id}\t{sire_id}\t{dam_id}\t{sex}\t{affected}"

proc write_trios*(individuals: HashSet[Individual]) =
  #[Write individuals to TSV.]#

  # Print only proband if it is the only relative.
  if len(individuals) == 1:
    for indiv in individuals:
      echo &"{indiv.id}\t\t"
    return

  let sequence = individuals.toSeq().sorted(cmp=cmpIndividuals)

  for indiv in sequence:
    var 
      sire_id: string
      dam_id: string
    if indiv.sire.isSome():
      if indiv.sire.get() notin sequence:
        sire_id = ""
      else:
        sire_id = indiv.sire.get().id
    else:
      sire_id = ""
    if indiv.dam.isSome():
      if indiv.dam.get() notin sequence:
        dam_id = ""
      else:
        dam_id = indiv.dam.get().id
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
        