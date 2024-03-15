import
  std/[algorithm, options, sequtils, sets, strutils],
  relatives

proc read_csv*(file: string): HashSet[Individual] =
  var individuals: HashSet[Individual]

  var f = open(file, fmRead)
  defer: close(f)
  for line in lines(f):
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
          children: initHashSet[Individual]()
        ))

      if individuals.containsOrIncl(sire_obj.get()):
        # Update obj if already in HashSet
        sire_obj = some(individuals[sire_obj.get()])


    # Create object for dam
    var dam_obj: Option[Individual]
    if dam == "":
      dam_obj = none(Individual)
    else:
      dam_obj = some(Individual(
          id: dam,
          sire: none(Individual),
          dam: none(Individual),
          children: initHashSet[Individual]()
        ))

      if individuals.containsOrIncl(dam_obj.get()):
        # Update obj if already in HashSet
        dam_obj = some(individuals[dam_obj.get()])

    # Create object for child
    let child = Individual(
        id: id,
        sire: sire_obj,
        dam: dam_obj,
        children: initHashSet[Individual]()
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
    var 
      sire_id: string
      dam_id: string
    if indiv.sire.isSome():
      sire_id = indiv.sire.get().id
    else:
      sire_id = ""
    if indiv.dam.isSome():
      dam_id = indiv.dam.get().id
    else:
      dam_id = ""
    #echo &"{indiv.id}\t{sire_id}\t{dam_id}"
    echo indiv.id