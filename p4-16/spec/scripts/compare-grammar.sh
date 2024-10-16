#! /bin/bash

THIS_SCRIPT_FILE_MAYBE_RELATIVE="$0"
THIS_SCRIPT_DIR_MAYBE_RELATIVE="${THIS_SCRIPT_FILE_MAYBE_RELATIVE%/*}"
THIS_SCRIPT_DIR_ABSOLUTE=`readlink -f "${THIS_SCRIPT_DIR_MAYBE_RELATIVE}"`

usage() {
    1>&2 echo "usage: $0 <spec grammar.adoc file> <p4c p4parser.ypp file>"
    1>&2 echo ""
    1>&2 echo "Sample command line:"
    1>&2 echo ""
    1>&2 echo "    $0 ../grammar.adoc \$HOME/p4c/frontends/parsers/p4/p4parser.ypp"
    1>&2 echo ""
    1>&2 echo "Program to trim C++ code and various other things from"
    1>&2 echo "a Bison grammar file like this one for the open source"
    1>&2 echo "p4c compiler:"
    1>&2 echo ""
    1>&2 echo "    https://github.com/p4lang/p4c/blob/main/frontends/parsers/p4/p4parser.ypp"
    1>&2 echo ""

    1>&2 echo "to make the resulting output file easier to compare"
    1>&2 echo "against a grammar.adoc file from the P4_16 language"
    1>&2 echo "specification repository here:"
    1>&2 echo ""
    1>&2 echo "    https://github.com/p4lang/p4-spec/blob/main/p4-16/spec/grammar.adoc"
}

if [ $# -ne 2 ]
then
    usage
    exit 1
fi

GRAMMAR_ADOC_FILE="$1"
P4PARSER_YPP_FILE="$2"

if [ ! -r "${GRAMMAR_ADOC_FILE}" ]
then
    1>&2 echo "Cannot open file for reading: ${GRAMMAR_ADOC_FILE}"
    exit 1
fi

if [ ! -r "${P4PARSER_YPP_FILE}" ]
then
    1>&2 echo "Cannot open file for reading: ${P4PARSER_YPP_FILE}"
    exit 1
fi

TRIMMED_GRAMMAR_FILE="trimmed-grammar-file.txt"
"${THIS_SCRIPT_DIR_ABSOLUTE}/trim-p4-grammar-file.py" ${OPTS} "${GRAMMAR_ADOC_FILE}" > "${TRIMMED_GRAMMAR_FILE}"
TRIMMED_PARSER_FILE="trimmed-p4parser-file.txt"
"${THIS_SCRIPT_DIR_ABSOLUTE}/trim-p4-grammar-file.py" ${OPTS} "${P4PARSER_YPP_FILE}" > "${TRIMMED_PARSER_FILE}"

echo "File names to compare:"
echo "\"${TRIMMED_GRAMMAR_FILE}\" \"${TRIMMED_PARSER_FILE}\""

echo ""
echo "Command to use emacs ediff-files feature to view the differences:"
echo "emacs --eval \"(ediff-files \\\"${TRIMMED_GRAMMAR_FILE}\\\" \\\"${TRIMMED_PARSER_FILE}\\\")\""

echo ""
echo "Command to use tkdiff to view the differences:"
echo "tkdiff \"${TRIMMED_GRAMMAR_FILE}\" \"${TRIMMED_PARSER_FILE}\""

echo ""
echo "For either of the above methods, you can press the 'n' key to advance"
echo "to the next 'hunk' of difference between the files, or 'p' to go back"
echo "to the previous hunk."
echo ""
echo "For the emacs ediff-files method, if you type the '#' character twice"
echo "in a row, it puts ediff-files in a mode where hunks that differ only"
echo "in white space, even across multiple lines, are skipped over"
echo "automatically."
