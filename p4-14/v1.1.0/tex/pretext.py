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

# Scan for these and then bold them
bnf_nonterminals = []

# Scan for these from the BNF, then bold them in code fragments
p4_keywords = []

def bnf_replacements(line):
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

# Line processor for when P4 code is being processed.
def process_code(outfile, line):
    outfile.write(line)

# Call to deposit the accumulated BNF to the output file
def deposit_bnf(outfile, line):
    outfile.write(all_bnf)

# Call to deposit the accumulated P4 keywords
def deposit_keywords(outfile, line):
    outfile.write("\\begin{Verbatim}[commandchars=\\\\\\{\\}]\n")
    for keyword in p4_keywords:
        outfile.write(keyword+"\n")
    outfile.write("\\end{Verbatim}\n")

# Set up appropriate keywords to be bolded in the BNF and P4 listing
# environments, respectively

def set_bnf_lstlisting_keywords(outfile, line):
    outfile.write("""
\\lstdefinestyle{BNFstyle}{
    language=BNF,%%
    frame=single,%%
    backgroundcolor=\\color{bnfgreen},%%
    morekeywords={%s}%%
}
""" % ", ".join(bnf_nonterminals))

def set_p4_lstlisting_keywords(outfile, line):
    outfile.write("""
\\lstdefinestyle{P4style}{
    language=C,%%
    frame=single,%%
    backgroundcolor=\\color{codeblue},%%
    keywords={%s},%%
    basicstyle=\\ttfamily,%%
    aboveskip=3mm,%%
    belowskip=3mm,%%
    fontadjust=true,%%
    keepspaces=true,%%
    keywordstyle=\\bfseries,%%
    captionpos=b,%%
    framerule=0.3pt,%%
    firstnumber=0,%%
    numbersep=1.5mm,%%
    numberstyle=\\tiny,%%
}
""" % ", ".join(p4_keywords))



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
        "add_text" : "%%bnf\n\\begin{lstlisting}[style=BNFstyle]\n",
        "line_processor" : accumulate_bnf,
    },
    "%%endbnf" : {
        #"add_text" : "\end{Verbatim}\n%%endbnf\n",
        "add_text" : "\end{lstlisting}\n%%endbnf\n",
        "line_processor" : None,
    },
    "%%code" : {
        "add_text" : "%%code\n\\begin{lstlisting}[style=P4style]\n",
        "line_processor" : process_code,
    },
    "%%endcode" : {
        "add_text" : "\end{lstlisting}\n%%endcode\n",
        "line_processor" : None,
    },
    "%%bnfsummarystart" : {
        "add_text" : "%%bnf\n\\begin{lstlisting}[style=BNFstyle]\n",
        "line_processor" : None,
    },
    "%%bnfsummary" : {
        "call" : deposit_bnf,
        "line_processor" : None,
    },
    "%%listkeywords" : {
        "call" : deposit_keywords,
        "line_processor" : None,
    },
    "%%set_bnf_lstlisting_keywords" : {
        "call" : set_bnf_lstlisting_keywords,
        "line_processor" : None,
    },
    "%%set_p4_lstlisting_keywords" : {
        "call" : set_p4_lstlisting_keywords,
        "line_processor" : None,
    }
}

def scrape_bnf_nonterminals(input):
    global p4_keywords
    global bnf_nonterminals

    suppressed_keywords = set()

    within_bnf = False
    for line in input:
        key = line.strip()
        if key.startswith("%%not_a_keyword"):
            match = re.match(r"%%not_a_keyword\s+([0-9A-Za-z_]+)", key)
            if match:
                suppressed_keywords.add(match.group(1))
        if not within_bnf:
            if key == "%%bnf" or key == "%%bnfsummarystart":
                within_bnf = True
        else:
            if key == "%%endbnf":
                within_bnf = False
            else:
                match = re.match(r"([0-9A-Za-z_]+)\s*::=", key)
                if match != None:
                    bnf_nonterminals.append(match.group(1))
                
                tokens = re.split(r"\s+",key)
                for token in tokens:
                    if len(token) <= 1:
                        continue
                    if token.endswith("_name"):
                        continue
                    if token.endswith("_text"):
                        continue
                    if re.match(r'[A-Za-z][0-9A-Za-z_]+$', token) == None:
                        continue
                    p4_keywords.append(token)

    p4_keywords = set(p4_keywords) - set(bnf_nonterminals)
    p4_keywords -= suppressed_keywords
    p4_keywords = list(p4_keywords)
    p4_keywords.sort()

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

    # Scan for BNF terminals
    scrape_bnf_nonterminals(input)

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
