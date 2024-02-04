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
        match3 = re.match(r"^%%", line)
        match4 = re.match(r"^~ End P4Grammar", line)
        if match3 or match4:
            break
        lines.append(line)

content = ''.join(lines)

# Temporarily replace the contents of strings (within double quotes,
# and also within single quotes) so that each character is replaced
# with a 2-digit hexadecimal encoding of the character's ASCII value
# (there should be only ASCII character in these files, no Unicode).

# Thus all characters that are "special" such as { } : | ; in the
# syntax of Bison grammars with C++ code in { } will become "not
# special", and we can use very simple regex matching techniques to
# look for these characters, without worrying about string contents.

# Later below we will restore all string contents from hex digits back
# to their original character sequences.

def string2hex(match):
    return '"%s"' % (match.group(0)[1:-1].encode('utf-8').hex())

def hex2string(match):
    return '"%s"' % (bytes.fromhex(match.group(0)[1:-1]).decode("ASCII"))


content = re.sub('l_angle', '"<"', content)
content = re.sub('r_angle', '">"', content)

content = re.sub('"[^"]+"', string2hex, content)
content = re.sub("'[^']+'", string2hex, content)

# Try replacing all balanced sets of curly braces, and whatever is
# between them, with empty strings.

while True:
    next = re.sub(r"\{[^{}]*\}", "", content)
    if next == content:
        break
    content = next

content = re.sub('%empty', '/* empty */', content)

# Remove blank lines that occur in the middle of the definition of a
# non-terminal.  Relies on the following assumptions, which are
# currently true of the file p4parser.ypp:

# + Non-terminals are first non-whitespace character on a line.
# + The ';' ending the definition of a non-terminal is always on a
#   line by itself.

lines = content.split('\n')

for i in range(len(lines)):
    if lines[i][0:1] == '%':
        lines[i] = ''
    # Remove end-of line comments beginning with //
    lines[i] = re.sub(r"//.*$", "", lines[i])
    # Remove comments of the form /* ... */
    lines[i] = re.sub(r"/\*.*\*/", "", lines[i])
    # Remove end-of-line whitespace
    lines[i] = lines[i].rstrip()

content = ' '.join(lines)

# Reformat grammar rules so that each alternative appears on exactly
# one line.
rules = content.split(';')
lines = []
for i in range(len(rules)):
    rule = rules[i].strip()
    if (i == len(rules) - 1) and (rule == ''):
        break
    xs = rule.split(':')
    if len(xs) != 2:
        print("debug:")
        print("i=%d" % (i))
        print("rule=%s" % (rule))
        print("xs=%s" % (xs))
        sys.exit(1)
    nonterminal_name = xs[0].strip()
    alts = xs[1].split('|')
    lines.append('')
    lines.append(nonterminal_name)
    for j in range(len(alts)):
        ln = '    '
        if j == 0:
            ln += ':'
        else:
            ln += '|'
        a = alts[j].strip()
        if a != '':
            ln += (' ' + a)
        lines.append(ln)
    lines.append('    ;')

content = '\n'.join(lines)

# Restore the contents of double-quoted strings from hexadecimal back
# to ASCII.
content = re.sub('"[^"]+"', hex2string, content)

print(content)
