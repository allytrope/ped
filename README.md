`ped` is a command line tool for filtering pedigree files and converting between pedigree file types.

## Usage
```
# Filter pedigree to only include individuals at most distance 4 from individual "111"
ped pedigree.tsv -p 111 -d 4

# Specify multiple probands as a comma-delimited string
ped pedigree.tsv -p 111,222,333 -d 4
```

`ped` will by default return an error if a proband is not in the pedigree. To process anyway, include the flag `--force-probands`. This can be succinctly written as so:
```
ped pedigree.tsv -fp 111,222,333 -d 4
```


`ped` can be conveniently combined for use with other tools like so:
```
# Count how many individuals are related to proband (including proband itself)
ped pedigree.tsv -p 111 -d 4 -Ol | wc -l

# Extract only related samples from BCF file
bcftools view input.bcf -S <(ped pedigree.tsv -p 111 -d 4 -Ol) --force-samples
```

## Input
The input pedigree file should be a tab-delimited file, consisting of three columns in the order: child, sire, and dam. Can be specified as a positional argument or through `stdin`.
Any rows starting with `#` are skipped.

## Output
There are three output types, all passed to `stdout`. They are specified with the `-O` option as summarized below:

| Option + arg | Output Type | Description |
| --- | --- | --- |
| `-Ol` | list | One individual per line. |
| `-Op` | PLINK | Plink-style `.ped`. |
| `-Ot` | TSV | Child, sire, and dam with tab-delimited columns. |

If not specified, the default is the TSV output, which is the same format as the input file.
In this case, each line will be a duo or trio, unless the proband is the only relative (when `-d 0`).

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

## Filtering methods
Currently, the only filtering option is by filtering on relatives with a shortest path of *n* or less on a tree with parent-child edges. This is the shortest, or geodesic, path. This is specified with the option `-d <int>` or in long form `--degree <int>`.

## Installation
The binary can be downloaded from the [release page](https://github.com/allytrope/ped/releases). No dependencies are required this way. 

Otherwise to compile, first download Nim and `nimble install docopt`. 
Then run:
```
nim c --define:release ped.nim
```

`ped` has been verified to work on Nim v1.6.16.