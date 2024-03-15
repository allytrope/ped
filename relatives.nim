#[Procedures related to the subcommand `relatives`.]#

import std/[hashes, options, sets, strformat, tables]

type
  Individual* = ref object
    id*: string
    sire*: Option[Individual]
    dam*: Option[Individual]
    children*: HashSet[Individual]
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

#   # Find descendants
proc relatives_by_degree*(proband: Individual, degree: int): HashSet[Individual] =
  #[Find all relatives within a specified degree of relationship.
  
  Finds relatives with a shortest path less than or equal to `degree` in graph G,
  where edges connect between parent and child.]#
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
