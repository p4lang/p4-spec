# Markup version

The markup version uses Madoko (https://www.madoko.net) to produce
HTML and PDF versions of the documentation. Pre-built versions of the
documentation are available on the
[wiki](https://github.com/p4lang/p4-spec/wiki).


Files:
- ```P4-16-draft-spec.mdk``` is the main file. It's markup, with two custom
  environments: P4Example (code examples) and P4Grammar (grammar
  fragments).
- ```grammar.mdk``` is the whole grammar in a single file included at
  the end of the main file. TODO: the intent is to include grammar
  fragments from this file in the different sections using the INCLUDE
  directive with labeled fragments. I didn't yet find a nice way to
  discard the labels and have this work satisfactorily.
- ```p4.json``` is providing custom syntax highlighting for P4. It is a rip
  off from the cpp.json provided by Madoko (the "extend" clause does
  not work, my version of Madoko asks for a "tokenizer" to be
  defined). Style customization for each token can be done using CSS
  style attributes (see token.keyword in line 20 of ```P4-16-draft-spec.mdk```).
- ```figs/*.png``` exported figures from the P4-16-draft-spec.pptx
- ```Makefile``` builds documentation in the build subdirectory

## Building
We use the [local
installation](http://research.microsoft.com/en-us/um/people/daan/madoko/doc/reference.html#sec-installation-and-usage)
method. For Mac OS, I installed node.js using Homebrew and then Madoko
using npm:
```
brew install node.js
npm install madoko -g
```
Note that to build the PDF you need a functional TeX version innstalled.
