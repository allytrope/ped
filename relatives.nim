#[Procedures related to the subcommand `relatives`.]#

import std/[hashes, options, sets, strformat, tables]

type
  Sex* = enum
    male, female, unknown
  Individual* = ref object
    id*: string
    sire*: Option[Individual]
    dam*: Option[Individual]
    children*: HashSet[Individual]
    sex*: Sex
  Edge = ref object
    child, parent: Individual

# Hash functions
func hash(individual: Individual): Hash =
  hash(individual.id)
func hash(edge: Edge): Hash =
  #hash(edge.child) - hash(edge.parent)
  hash([edge.child, edge.parent])

# Equivalence functions
func `==`(indiv1: Individual, indiv2: Individual): bool =
  indiv1.id == indiv2.id
proc cmpIndividuals*(a, b: Individual): int =
  cmp(a.id, b.id)

# Echo functions
proc echo*(indiv: Individual) =
  echo fmt"id: {indiv.id}"

func mates*(proband: Individual): HashSet[Individual] =
  # Return mates
  for child in proband.children:
    if proband.sex == male:
      try:
        result.incl(child.dam.get())
      except UnpackDefect:
        discard
    elif proband.sex == female:
      try:
        result.incl(child.sire.get())
      except UnpackDefect:
        discard

func offspring*(proband: Individual, mate: Individual): HashSet[Individual] =
  ## Offspring that share both individuals as parents
  for child in proband.children:
    if proband.sex == male:
      try:
        if child.dam.get() == mate:
          result.incl(child)
      except UnpackDefect:
        discard
    elif proband.sex == female:
      try:
        if child.sire.get() == mate:
          result.incl(child)
      except UnpackDefect:
        discard

func parents(proband: Individual): HashSet[Individual] =
  #[Return sire and dam of proband.]#
  try:
    result.incl(proband.sire.get())
  except UnpackDefect:
    discard
  try:
    result.incl(proband.dam.get())
  except UnpackDefect:
    discard

# proc founders*(proband: Individual): HashSet[Individual] =
#   #[Find all founders. That is, all ancestors who lack at least one known parent.]#
#   var individuals = [proband].toHashSet()

#   proc recursive_founders(proband: Individual): HashSet[Individual] =
#     if proband.sire.isSome():
#       discard recursive_founders(proband.sire.get())
#     else:
#       individuals.incl(proband)
#     if proband.dam.isSome():
#       discard recursive_founders(proband.sire.get())
#     else:
#       individuals.incl(proband)

#   discard recursive_founders(proband)
#   return individuals

proc ancestors*(proband: Individual): HashSet[Individual] =
  #[Find all ancestors including self.]#
  var individuals = [proband].toHashSet()

  proc recursive_ancestors(proband: Individual): HashSet[Individual] =
    try:
      individuals.incl(proband.sire.get())
      discard recursive_ancestors(proband.sire.get())
    except UnpackDefect:
      discard
    try:
      individuals.incl(proband.dam.get())
      discard recursive_ancestors(proband.dam.get())
    except UnpackDefect:
      discard

  discard recursive_ancestors(proband)
  return individuals

proc descendants*(proband: Individual): HashSet[Individual] =
  #[Find all descendants including self.]#
  var individuals = [proband].toHashSet()

  proc recursive_descendants(proband: Individual): HashSet[Individual] =
    for child in proband.children:
      individuals.incl(child)
      discard recursive_descendants(child)

  discard recursive_descendants(proband)
  return individuals

  

# Find descendants
proc relatives_by_degree*(proband: Individual, degree: int): HashSet[Individual] =
  #[Find all relatives within a specified degree of relationship.
  
  Finds relatives with a shortest path less than or equal to `degree` in graph G,
  where edges connect between parent and child. For example, from a proband,
  it's parent and child are degree 1, while it's grandparent, grandchild,
  and sibling are degree 2.]#
  var relatives: HashSet[Individual]
  var visited_edges: Table[Edge, int]

  proc depth_first_search(proband: Individual, degree: int) =
    #[The recursion lowers the value of degree by 1 on each iteration until reaching 0.]#
    relatives.incl(proband)

    # Return after reaching maximum specified depth.
    if degree <= 0:
      return
    
    # Find ancestors
    if len(proband.parents()) != 0:
      for parent in proband.parents():
        try:
          # Test whether this edge has already been visited from a shorter path
          if degree <= visited_edges[Edge(child: proband, parent: parent)]:
            return
          else:
            visited_edges[Edge(child: proband, parent: parent)] = degree
        except KeyError:
          visited_edges[Edge(child: proband, parent: parent)] = degree
          depth_first_search(parent, degree - 1)

    # Find descendants
    for child in proband.children:
      try:
        # Test whether this edge has already been visited from a shorter path
        if degree <= visited_edges[Edge(child: child, parent: proband)]:
          return
        else:
          visited_edges[Edge(child: child, parent: proband)] = degree
      except KeyError:
        visited_edges[Edge(child: child, parent: proband)] = degree
        depth_first_search(child, degree - 1)
  
  # Begin iterations
  depth_first_search(proband, degree)

  return relatives

proc relatives_by_relationship*(proband: Individual, min_coefficient: float): OrderedTable[Individual, float] =
  #[Find all relatives within a specified coefficient of relationship.
  
  Finds relatives based on the estimated genetic similarity. For example, from a proband,
  it's parent, child, and sibling are 0.5, while it's grandparent, grandchild,
  and sibling are 0.25. This does not take into account identical siblings.]#

  #var coefficients: Table[Individual, float]
  var coefficients: OrderedTable[Individual, float]
  #var coefficients = newTable[Individual, float]

  proc descendant_coefficients(indiv: Individual, path: seq[Individual], coefficient: float) =
    #[The recursion keeps track of the coefficient of relationship based on how far away from proband.
    Each time a path to an individual is found, that path's coefficient is added to the coefficient for that indiviual.]#

    for child in indiv.children:
      if child notin path:
        if child notin coefficients:
          # Set initial coefficient to 0
          coefficients[child] = 0
        var extended_path = path
        extended_path.add(child)
        # Add path's coefficient
        coefficients[child] += coefficient
        descendant_coefficients(child, extended_path, coefficient / 2)

  proc relative_coefficients(indiv: Individual, path: seq[Individual], coefficient: float) =
    #[Traverse up the tree, calling proc descendant_coefficients in the process.]#
    var extended_path = path
    extended_path.add(indiv)
    if indiv notin coefficients:
      coefficients[indiv] = 0
    coefficients[indiv] += coefficient
    
    # Offspring
    descendant_coefficients(indiv, extended_path, coefficient / 2)

    # Sire
    if indiv.sire.isSome():
      relative_coefficients(indiv.sire.get(), extended_path, coefficient / 2)

    # Dam
    if indiv.dam.isSome():
      relative_coefficients(indiv.dam.get(), extended_path, coefficient / 2)

  #var relatives: HashSet[Individual]
  # Iterate through probands
  #for proband in probands:

  # Set proband to coefficient of 1 and then populate with coefficients of the remaining individuals
  coefficients = {proband: 1.0}.toOrderedTable
  relative_coefficients(proband, @[], 1.0)

  # Set proband back to 1 (to reset modification)
  coefficients[proband] = 1

  return coefficients

proc filter_relatives*(proband: Individual, min_coefficient: float): HashSet[Individual] =
    #[Filter to only relatives at or above the minimum coefficient.]#
    var relatives: HashSet[Individual]
    let coefficients = relatives_by_relationship(proband, min_coefficient)
    for indiv, coefficient in coefficients:
      if coefficient >= min_coefficient:
        relatives.incl(indiv)
    return relatives

proc find_coefficients*(proband: Individual): OrderedTable[Individual, float] =
  return relatives_by_relationship(proband, 0)

proc blood_neighbors(indiv: Individual, allowed: HashSet[Individual]): seq[Individual] =
  #[Return allowed parent/child neighbors for an individual.]#
  var relatives: seq[Individual]
  for parent in parents(indiv):
    if parent in allowed:
      relatives.add(parent)
  for child in indiv.children:
    if child in allowed:
      relatives.add(child)
  return relatives

proc blood_relatives*(probands: seq[Individual]): HashSet[Individual] =
  #[Return all individuals who are blood relatives of any proband, including the probands themselves.]#
  var relatives = initHashSet[Individual]()
  for proband in probands:
    for indiv in ancestors(proband):
      relatives.incl(indiv)
    for indiv in descendants(proband):
      relatives.incl(indiv)
  return relatives

proc parent_offspring_paths*(start, goal: Individual, allowed: HashSet[Individual], max_paths: int = 0): seq[seq[Individual]] =
  #[Enumerate parent-offspring paths between two individuals, ordered by path length, optionally limiting the number of paths returned.]#
  var
    paths: seq[seq[Individual]]
    queue = @[@[start]]
    i = 0
  while i < queue.len:
    let path = queue[i]
    i.inc
    let last = path[^1]
    if last == goal:
      paths.add(path)
      if max_paths > 0 and paths.len >= max_paths:
        break
      continue
    for neighbor in blood_neighbors(last, allowed):
      if neighbor notin path:
        queue.add(path & @[neighbor])
  return paths

proc connecting_blood_relatives*(probands: seq[Individual], max_paths_per_pair: int = 0): HashSet[Individual] =
  #[Find individuals forming parent-offspring paths connecting probands.
    Only parent-child edges among blood relatives are traversed. When
    `max_paths_per_pair` is positive, only the first N paths from shortest
    to longest are kept for each pair of probands.]#
  var connected = initHashSet[Individual]()
  if probands.len == 0:
    return connected

  for proband in probands:
    connected.incl(proband)

  let allowed = blood_relatives(probands)
  for i in 0 ..< probands.len:
    for j in i + 1 ..< probands.len:
      let start = probands[i]
      let goal = probands[j]
      let paths = parent_offspring_paths(start, goal, allowed, max_paths_per_pair)
      for path in paths:
        for indiv in path:
          connected.incl(indiv)
  return connected
