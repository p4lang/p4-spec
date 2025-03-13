# Comparing the specification `grammar.mdk` file against `p4c`'s grammar

Assuming you have a local copy of a clone of the p4lang/p4c repository
in your home directory, you can run this command within the scripts
directory to compare the spec's grammar.mdk file against that p4c
repo's version of the grammar:

```bash
./compare-grammar.sh ../grammar.adoc $HOME/p4c/frontends/parsers/p4/p4parser.ypp
```
