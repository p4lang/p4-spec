# Introduction

This article describes how to run `bison` on the P4_16 language
grammar, as implemented in the open source `p4c` compiler available
at:

 https://github.com/p4lang/p4c

These steps can be useful when trying out variations of the `bison`
grammar, e.g. when working on making extensions to the P4_16 language
syntax for enhancements.

Prerequisites: You have a Linux system with the necessary software
installed required to build `p4c` from source code.

The following sequence of commands can be used to find the particular
`bison` command line arguments that are used while building `p4c`:

```bash
git clone https://github.com/p4lang/p4c
cd p4c
mkdir build
cd build
cmake ..
find . \! -type d | xargs grep bison
```

As of 2023-Aug-20, this is the latest version of `p4c`:

```bash
$ git log -n 1 | cat
commit 40ebd7eed1ff7e744c8f34fd06ce9ce061d8d88f
Author: Hoooao <93057312+Hoooao@users.noreply.github.com>
Date:   Sat Aug 19 16:05:04 2023 -0400
```

And below is the command that is used to run `bison` on the P4_16
grammar used by `p4c`.

Note: Assign a value to the shell variable `P4C` that is the directory
where your copy of the `p4c` git repo is located on your system.

```bash
P4C=$HOME/forks/p4c
mkdir my-temp-dir
cd my-temp-dir
bison \
    -Werror=conflicts-sr \
	-Werror=conflicts-rr \
	-d \
	--verbose \
	-o p4parser.cpp \
	${P4C}/frontends/parsers/p4/p4parser.ypp
```
