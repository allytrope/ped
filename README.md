`ped` is a command line tool for filtering pedigree files and converting between pedigree file types.

## Examples
```
# Filter pedigree to only include individuals at most distance 4 from individual "111"
ped pedigree.tsv -p 111 -d 4

# Specify multiple probands as a comma-delimited string
ped pedigree.tsv -p 111,222,333 -d 4

# Change trios file to PLINK-style file
ped pedigree.tsv -Op
```

`ped` will by default return an error if a proband is not in the pedigree. To process anyway, include the flag `--force-probands`. This can be succinctly written as so:
```
ped pedigree.tsv -fp 111,222,333 -d 4
```


Additional uses can be found by combining with other tools:
```
# Count how many individuals are related to proband (including proband itself)
ped pedigree.tsv -p 111 -d 4 -Ol | wc -l

# Find individuals that are not closely related to proband
ped pedigree.tsv -Ol | grep -Fvxf <(ped pedigree.tsv -p 111 -d 4 -Ol)

# Extract only related samples from BCF file
bcftools view input.bcf -S <(ped pedigree.tsv -p 111 -d 4 -Ol) --force-samples
```

## Input pedigree
The input pedigree file should be a tab-delimited file, consisting of three columns in the order: child, sire, and dam. Can be specified as a positional argument or through `stdin`.
Any rows not starting with `#` are interpreted as individuals, so any header or column names should start with `#` or be excluded.

## Probands
Probands are the individuals from whom relatives will be determined using the filtering methods. Only one of the following options for specifying probands can be used. Using one will also require either `-d <int>` or `-r <float>`.

### `-P <probands_file>`
A file containing a list of probands, one per line.
Does not need to be seekable, and so can also take a file through process substitution.

### `-p <probands>`
A comma-delimited string of probands like so `-p 111,222,333`.

## Filtering
Filtering options explain how to filter down a individuals in relation to proband(s). Thus using any of these require either `-P <probands_file>` or `-p <probands>`.

### `-d <int>`
This option filters on relatives with a shortest path of *n* or less on a tree with parent-child edges. This is the shortest, or geodesic, path. This is specified with the option `-d <int>` or in long form `--degree <int>`.

Some example values:
| Value | Relatives |
| --- | --- |
| `0` | Self |
| `1` | Parents, children |
| `2` | Grandparents, grandchildren, siblings |
| ... | ... |

### `-r <float>`
This option keeps only relatives with a coefficient of relationship greater than or equal to the specified float. While `-d <int>` keeps only the shorest path to determine degree, `-r <float>` sums the coefficients of all paths.

Some example coefficients:
| Coefficient | Relatives |
| --- | --- |
| `1` | Self |
| `0.5` | Parents, children, full-siblings |
| `0.25` | Grandparents, grandchildren, half-siblings, aunt/uncle, niece/nephew, double cousin | 
| ... | ... |
| `0` | All blood relatives (not necessarily all in pedigree) |

While a cousin would have a coefficient of `0.125`, a double cousin (being a counsin on both parents' sides) would have the coefficient applied twice and thus be `0.25`.


## Output
There are three output types, all passed to `stdout`. They are specified with the `-O` option as summarized below:

| Option + arg | Output Type | Description |
| --- | --- | --- |
| `-Ol` | list | One individual per line. |
| `-Om` | matrix | Coefficients of relationship as a matrix. |
| `-Op` | PLINK | Plink-style `.ped`. |
| `-Ot` | TSV | Child, sire, and dam with tab-delimited columns. |
| `-Ow` | pairwise | Coefficients of relationship as a pairwise TSV. |

If not specified, the default is the TSV output, which is the same format as the input file.
In this case, each line will be a duo or trio, unless the proband is the only relative.

### `-Om`
*n* x *n* matrix of coefficients of relationship values. First row and first column list the individual ids.
Includes identity of 1.0 along the diagonal.

### `-Ol`
The simplest output; just one individual per row.

### `-Op`
A PLINK-styled TSV will have one row for each individual.
Each row will have five columns: family, child, sire, dam, sex, and affected.
If input is a three-columned TSV (like the result of `-Ot`), this will make up a family id of "1" and affected status as `0`.
Missing entries are filled with `0`.
The sex field uses `1` for males and `2` for females.

### `-Ot`
Lists duos and trios as a TSV. Also condenses rows so that if an individual has no recorded parent, but is the parent of another, it will not have its own row. This means that there will usually be fewer rows than total individuals.
Fields with missing parents are left blank.

### `-Ow`
Lists individuals pairwise with their corresponding coefficients of relationship.
Includes rows for comparing individuals to themselves (which will always be 1.0).

## Installation
The binary can be downloaded from the [release page](https://github.com/allytrope/ped/releases). No dependencies are required this way. 

Otherwise to compile, first download Nim and `nimble install docopt`. 
Then run:
```
nim c --define:release ped.nim
```

`ped` has been tested on Nim v1.6.16.