`ped` is a command line tool for filtering pedigree files.

An example of filtering a pedigree file by only keeping individuals related to the individual labelled 123 by at most 4 degrees, would look like this:

## Usage
```
# Find individuals at most distance 4 from individual "123"
ped relatives pedigree.tsv 123 -d 4
```

`ped` can be conveniently combined for use with other tools like so:
```
# Count how many individuals are related to proband
ped relatives pedigree.tsv 123 -d 4 | wc -l

# Extract only related samples from VCF file
bcftools view input.vcf -s $(echo $(ped relatives pedigree.tsv 123 -d 4) | sed 's/ /,/g') --force-samples
```

## Output
Output consists of one individual per line.

## Pedigree file
The input pedigree file should be a tab-delimited file, without a header, consisting of three columns in the order: child, sire, and dam.

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