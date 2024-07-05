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
  hash(edge.child) + hash(edge.parent)

# Equivalence functions
func `==`(indiv1: Individual, indiv2: Individual): bool =
  indiv1.id == indiv2.id
proc cmpIndividuals*(a, b: Individual): int =
  cmp(a.id, b.id)

# Echo functions
proc echo*(indiv: Individual) =
  echo fmt"id: {indiv.id}"

func parents(proband: Individual): HashSet[Individual] =
  #[Return sire and dam of proband.]#
  var parents: HashSet[Individual]
  if proband.sire.isSome():
      parents.incl(proband.sire.get())
  if proband.dam.isSome():
      parents.incl(proband.dam.get())
  return parents

proc ancestors*(proband: Individual): HashSet[Individual] =
  #[Find all ancestors including self.]#
  var individuals = [proband].toHashSet()
  #var individuals: HashSet[Individual]

  proc recursive_ancestors(proband: Individual): HashSet[Individual] =
    if proband.sire.isSome():
      individuals.incl(proband.sire.get())
      discard recursive_ancestors(proband.sire.get())
    if proband.dam.isSome():
      individuals.incl(proband.dam.get())
      discard recursive_ancestors(proband.dam.get())
  
  discard recursive_ancestors(proband)
  return individuals

proc descendants*(proband: Individual): HashSet[Individual] =
  #[Find all descendants including self.]#
  var individuals = [proband].toHashSet()
  #var individuals: HashSet[Individual]
  proc recursive_descendants(proband: Individual): HashSet[Individual] =
    for child in proband.children:
      individuals.incl(child)
      discard recursive_descendants(child)
  
  discard recursive_descendants(proband)
  return individuals

  

# Find descendants
proc relatives_by_degree*(probands: seq[Individual], degree: int): HashSet[Individual] =
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
  for proband in probands:
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

proc filter_relatives*(probands: seq[Individual], min_coefficient: float): HashSet[Individual] =
    #[Filter to only relatives at or above the minimum coefficient.]#
    var relatives: HashSet[Individual]
    for proband in probands:
      let coefficients = relatives_by_relationship(proband, min_coefficient)
      for indiv, coefficient in coefficients:
        if coefficient >= min_coefficient:
          relatives.incl(indiv)
    return relatives

proc find_coefficients*(proband: Individual): OrderedTable[Individual, float] =
  return relatives_by_relationship(proband, 0)
