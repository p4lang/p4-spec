#!/usr/bin/env python
#
# This is a preprocessing script that takes as input a file (or list
# of files), # in tex, and produces a tex file according to the 
# following rules.
#
# The input file is processed line-by-line
#
# Lines starting with comment_string (%%ptcomment) are removed
#
# Lines matching entries in the process_tags dictionary below
# will be processed by adding additional text, and/or calling
# a one-time function, and/or installing a processor function
# which is applied to lines from the input until the function
# is changed.
#
# There are two main objects managed by pretext for P4 right now:
# BNF: Typeset and accumulate BNF for P4
# Code listings: Typeset code listings
#
# For both, little or no escaping should be necessary in the
# .pt file; this means if you change, say, from \Verbatim to 
# \lstlisting, you need to change the line processor for the
# mode appropriately.
#

import sys
import re
import argparse

# This is the function (pointer) that is called for each line
# Commands in the file may update this pointer.
global line_processor
line_processor = None

# P4 specific: This variable accumulates all BNF text
global all_bnf
all_bnf = ""

# Processing BNF:
#   First, simple replacements
#   Second, word identification and wrapping

def wrap_in_command(line, start, length, command="textbf"):
    """
    Add \command{ ... } starting at pos start and of given length 
    """
    result = line[:start] + "\\" + command + "{"
    result += line[start:start+length] + "}"
    result += line[start+length:]
    return result

# These just get replaced according to the key/value of the dict.
# USING lstlisting these should not be replaced.
bnf_bracket_replacements = { # Replace these first
#    "{"   : "\\{",
#    "}"   : "\\}",
}

# These are replaced directly (no word edge check)
bnf_simple_replacements = {
    '"*"' : '"@\\textbf{*}@"',
    '"+"' : '"@\\textbf{+}@"',
    '"-"' : '"@\\textbf{-}@"',
    '"["' : '"@\\textbf{[}@"',
    '"]"' : '"@\\textbf{]}@"',
    '"|"' : '"@\\textbf{|}@"',
    "'"   : "@\\textbf{'}@",
    "."   : "@\\textbf{.}@",
    '<<' : '"@\\textbf{<{}<{}}@"',
    '>>' : '"@\\textbf{>{}>{}}@"',
}

# These are checked for being words
bnf_terminals = [
    "_", "<<", ">>", "\&", "\^", "\~", "-", ">", ">=", "==", 
    "<=", "<", "!=",
    "a", "A", "b", "B", "c", "C", "d", "D", "e", "E", "f", "F",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "0b", "0B", "0x", "0X",
    "action",
    "action_profile",
    "action_selector",
    "algorithm",
    "and",
    "apply",
    "attributes",
    "bytes",
    "calculated_field",
    "control",
    "counter",
    "current",
    "default",
    "direct",
    "drop",
    "else",
    "false",
    "field_list",
    "field_list_calculation",
    "fields",
    "header",
    "header_type",
    "hit",
    "if",
    "input",
    "instance_count",
    "last",
    "latest",
    "layout",
    "length",
    "mask",
    "max_length",
    "metadata",
    "meter",
    "min_width",
    "miss",
    "or",
    "output_width",
    "packets",
    "parse_error",
    "parser",
    "parser_drop",
    "parser_exception",
    "parser_value_set",
    "payload",
    "primitive_action",
    "register",
    "result",
    "return",
    "saturating",
    "select",
    "signed",
    "static",
    "table",
    "true",
    "type",
    "update",
    "valid",
    "verify",
    "width",
]

def bnf_replacements(line):
    for s, r in bnf_bracket_replacements.iteritems():
        line = line.replace(s, r)
    for s, r in bnf_simple_replacements.iteritems():
        line = line.replace(s, r)
    for k in bnf_terminals:
        exp = "\\b" + k + "\\b"
        new = "@\\\\textbf{" + k + "}@"
        new = new.replace("_", "\\_")
        (line, _) = re.subn(exp, new, line)
    return line

# Line processor for when BNF is being processed.
def accumulate_bnf(outfile, line):
    global all_bnf
    # Escape _
    #line = line.replace("_", "\_")
    #line = line.replace("{", "\{")
    #line = line.replace("}", "\}")
    # TODO: Fix terminal _
    line = bnf_replacements(line)
    outfile.write(line)
    all_bnf += line

# Call to deposit the accumulated BNF to the output file
def deposit_bnf(outfile, line):
    outfile.write(all_bnf)
    
# These are the tags that are processed from the input; 
# Each tag must appear alone on an input line
#
# Legal keys in the dictionary associated with each tag:
#   keep_line: Copy this line to the output file before any other processing
#   call: Call this function
#   add_text: Write this to the output file
#   line_processor: Update the line processor to this function
#
# The keys are processed in the order shown.

global process_tags
process_tags = {
    "%%bnf" : {
        #"add_text" : "%%bnf\n\\begin{Verbatim}[commandchars=\\\\\{\}]\n",
        "add_text" : "%%bnf\n\\begin{lstlisting}[frame=single,backgroundcolor=\color{bnfgreen},escapechar=\\@]\n",
        "line_processor" : accumulate_bnf,
    },
    "%%endbnf" : {
        #"add_text" : "\end{Verbatim}\n%%endbnf\n",
        "add_text" : "\end{lstlisting}\n%%endbnf\n",
        "line_processor" : None,
    },
    "%%code" : {
        "add_text" : "%%code\n\\begin{lstlisting}[keywords={},frame=single,escapechar=\@]\n",
        "line_processor" : None,
    },
    "%%endcode" : {
        "add_text" : "\end{lstlisting}\n%%endcode\n",
        "line_processor" : None,
    },
    "%%bnfsummarystart" : {
        "add_text" : "%%bnf\n\\begin{lstlisting}[frame=single,backgroundcolor=\color{bnfgreen},escapechar=\\@]\n",
        "line_processor" : None,
    },
    "%%bnfsummary" : {
        "call" : deposit_bnf,
        "line_processor" : None,
    },
}

# Lines starting with this are removed from the input
global comment_string
comment_string = "%%ptcomment"

#
# The main processor
#

if __name__ == "__main__":
    input = []

    parser = argparse.ArgumentParser(description='P4 tex preprocessor',
                        usage="%(prog)s source [source...] [--output dest]")
    parser.add_argument('sources', metavar='source', type=str, nargs='+',
                       help='a source file to include in the processing')
    parser.add_argument('-o', '--output', action='store', type=str,
                        help="The output file to generate")
    args = parser.parse_args()

    # Output to file or stdout based on argument output
    if args.output:
        outfile = open(args.output, "w")
    else:
        outfile = sys.stdout

    # Gather all input into an array of lines
    for fname in args.sources:
        with open(fname, "r") as infile:
            input.extend(infile.readlines())

    # Process line by line
    for line in input:
        key = line.strip()
        if key.startswith(comment_string):
            continue
        if key in process_tags.keys():
            # input line is a tag; update state
            info = process_tags[key]

            if "keep_line" in info.keys() and info["keep_line"]:
                outfile.write(line)
            if "call" in info.keys():
                info["call"](outfile, line)
            if "add_text" in info.keys():
                outfile.write(info["add_text"])
            if "line_processor" in info.keys():
                line_processor = info["line_processor"]
        else: # Process line according to current state
            if line_processor is None: # Default prints out the line
                outfile.write(line)
            else: # Otherwise, call the line processor
                line_processor(outfile, line)
