`ped` is a command line tool for filtering pedigree files.

## Usage
```
# Filter pedigree to only include individuals at most distance 4 from individual "123"
ped relatives pedigree.tsv 123 -d 4
```

`ped` can be conveniently combined for use with other tools like so:
```
# Count how many individuals are related to proband (including proband itself)
ped relatives pedigree.tsv 123 -d 4 -Ol | wc -l

# Extract only related samples from VCF file
bcftools view input.vcf -s $(echo $(ped relatives pedigree.tsv 123 -d 4 -Ol) | sed 's/ /,/g') --force-samples
```

## Input
The input pedigree file should be a tab-delimited file, consisting of three columns in the order: child, sire, and dam.
Any rows starting with `#` are skipped.

## Output
There are two options for output. They are specified with the `-O` option.

| Option + arg | Output Type | Description |
| --- | --- | --- |
| -O l | list | One individual per line. |
| -O t | TSV | Child, sire, and dam with tab-delimited columns. |

If not specified, the default is the TSV output, which is the same format as the input file.
In this case, each line will be a duo or trio, unless the proband is the only relateive (when `-d 0`).

## Filtering methods
Currently, the only filtering option is by filtering on relatives with a shortest path of *n* or less on a tree with parent-child edges. This is the shortest, or geodesic, path. This is specified with the option `-d <int>` or in long form `--degree <int>`.

## Installation
The binary can be downloaded from the [release page](https://github.com/allytrope/ped/releases). No dependencies are required this way. 

Otherwise to compile yourself, you'll need to `nimble install docopt`. 
Then run:
```
nim c --define:release ped.nim
```

`ped` has been verified to work on Nim v1.6.16.