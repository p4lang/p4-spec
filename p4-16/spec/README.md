This folder contains the sources for generating the official P4-16
specification document.

# Markup version

The markup version uses AsciiDoc (https://asciidoc.org/) format, and
the AsciiDoctor program (https://asciidoctor.org/) to produce HTML and
PDF versions of the documentation. Pre-built versions of the
documentation are available on the
[wiki](https://github.com/p4lang/p4-spec/wiki).

Files:
- `P4-16-spec.adoc` is the main file. It is in AsciiDoc markup.
- `grammar.adoc` is the whole grammar in a single file included at the
  end of the main file. It also includes specially formatted comments
  that AsciiDoctor uses to mark fragments of the grammar for inclusion
  in the specification using `include::` statements.
- Custom syntax highlighting for P4 source code examples in the
  specification are colorized using the Rouge package
  https://github.com/rouge-ruby/rouge
- `resources/figs/*.png` exported figures from the
  `P4-16-draft-spec.pptx`
- `resources/fonts` contains font definitions.
- `resources/theme` contains a P4 logo image for the title page, and
  CSS and YAML files for TODO.
- `Makefile` builds documentation by creating files `P4-16-spec.pdf`
  and `P4-16-spec.html`

## Building

Follow the instructions for various platforms below.

HINT: For *nix builds using make, you can use use `make html` for
quicker turnarounds and `make` for the final PDF output.

### Linux

For an Ubuntu system with a supported version, you may use the bash
script [`install-asciidoctor-linux.sh`](install-asciidoctor-linux.sh)
to install the necessary packages and fonts for you.
