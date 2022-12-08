#! /usr/bin/env python3

import os, sys
import fileinput
import re
import argparse

parser = argparse.ArgumentParser(description="""
Program to trim C++ code and various other things from a Bison grammar
file like this one for the open source p4c compiler:

    https://github.com/p4lang/p4c/blob/main/frontends/parsers/p4/p4parser.ypp

to make the resulting output file easier to compare against a
grammar.mdk file from the P4_16 language specification repository here:

    https://github.com/p4lang/p4-spec/blob/main/p4-16/spec/grammar.mdk
""")
parser.add_argument('-c', '--remove-comments', action='store_true')
parser.add_argument('filename')
args = parser.parse_known_args()[0]

# Read the entire file in as one big string.

lines = []
keep = False
for line in fileinput.input(files=(args.filename)):
    match1 = re.match(r"^program\s*:", line)
    match2 = re.match(r"^p4program", line)
    if match1 or match2:
        keep = True
        #print("First line kept:\n%s" % (line))
    if keep:
        lines.append(line)

content = ''.join(lines)

# Temporarily replace all occurrences of "{" and "}" (with the double
# quotes there) with a string that does not exist anywhere else in the
# file (I checked manually in 2022-Dec that this was true at that time
# -- adjust the temporary replacement strings if necessary later).
# The plan is that soon below we will replace the temporary
# substitutions back with their original form, but we will take
# advantage of the fact that there are no occurrences of { or } inside
# of "quoted strings" to do simpler string manipulations in this
# program.

#content = re.sub(pattern, replacement, content)
content = re.sub('"{"', '"leftbrace"', content)
content = re.sub('"}"', '"rightbrace"', content)

# Try replacing all balanced sets of curly braces, and whatever is
# between them, with empty strings.

while True:
    next = re.sub(r"\{[^{}]*\}", "", content)
    if next == content:
        break
    content = next

# Change curly brackes in strings back
content = re.sub('"leftbrace"', '"{"', content)
content = re.sub('"rightbrace"', '"}"', content)

content = re.sub('%empty', '/* empty */', content)
content = re.sub('l_angle', '"<"', content)
content = re.sub('r_angle', '">"', content)

# Remove blank lines that occur in the middle of the definition of a
# non-terminal.  Relies on the following assumptions, which are
# currently true of the file p4parser.ypp:

# + Non-terminals are first non-whitespace character on a line.
# + The ';' ending the definition of a non-terminal is always on a
#   line by itself.

lines = content.split('\n')

for i in range(len(lines)):
    if args.remove_comments:
        # Remove end-of line comments beginning with //
        lines[i] = re.sub(r"//.*$", "", lines[i])
        # Remove comments of the form /* ... */
        lines[i] = re.sub(r"/\*.*\*/", "", lines[i])
    # Remove end-of-line whitespace
    lines[i] = lines[i].rstrip()

lines2 = []

# Remove completely blank lines in the middle of the definition of a
# nonterminal.
i = 0
while i < len(lines):
    nonterminal = re.match(r"^[a-zA-Z]", lines[i])
    lines2.append(lines[i])
    i += 1
    if nonterminal:
        while i < len(lines):
            end_of_defn = re.match(r"^\s+;", lines[i])
            if end_of_defn:
                lines2.append(lines[i])
                i += 1
                break
            else:
                blank = re.match(r"^\s*$", lines[i])
                if not blank:
                    lines2.append(lines[i])
                i += 1

content = '\n'.join(lines2)
print(content)
