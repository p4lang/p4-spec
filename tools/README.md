# Introduction

This directory contains some documentation on how HTML and PDF
versions of the P4.org specifications are generated and published on
the P4.org web site.


## Released versions of specifications

Since new released versions of P4.org specifications are typically
released about once per year, or less often, all of the released
versions are generated, and copied to separate files on the P4.org web
server.

This includes the latest released versions in the first section of
this page that has links to specifications: https://p4.org/specs/ It
also includes all of the links in the "Archives" section at the end of
that page.


## Working draft versions of specifications

We only publish the most recent HTML and PDF draft version of
specifications, generated from the latest commit in the appropriate
specification repository.  If someone wants an older version, they can
check out any older version of the specification soruces they wish,
and then follow the published instructions for how to generate HTML
and PDF from the source,
e.g. [here](https://github.com/p4lang/p4-spec/tree/main/p4-16/spec#building).


### Working draft versions of specifications, generated from AsciiDoc source

The details of this are still to be decided.  Ideally they should be
documnted here after those decisions have been made.


### Working draft versions of specifications, generated from Madoko source (historical interest only as of 2024)

As of the switch from Madoko to AsciiDoc as the source format used to
maintain P4.org specifications, in late 2024, this section is
primarily of historical interest.  It is documented here as an aid to
those involved in making the changes required to cause that
transition.

On the specifications page [here](https://p4.org/specs/), there are
links labeled "working draft", both HTML and PDF links, for most of
the specifications.

As of 2024-Nov-13, these working draft links point to the URLs shown
below.

+ P4_16 Language Specification
  + HTML: https://p4.org/p4-spec/docs/p4-16-working-draft.html
    + loads the file at URL https://raw.githubusercontent.com/p4lang/p4-spec/gh-pages/docs/P4-16-working-spec.html
  + PDF: https://p4.org/p4-spec/docs/p4-16-working-draft-pdf.html
    + loads the file at URL https://raw.githubusercontent.com/p4lang/p4-spec/gh-pages/docs/P4-16-working-spec.pdf
+ P4Runtime specification
  + HTML: https://p4.org/p4-spec/docs/p4runtime-spec-working-draft-html-version.html
    + loads the file at URL https://raw.githubusercontent.com/p4lang/p4runtime/gh-pages/spec/main/P4Runtime-Spec.html
  + PDF: https://p4.org/p4-spec/docs/p4runtime-spec-working-draft-pdf-version.html
    + loads the file at URL https://raw.githubusercontent.com/p4lang/p4runtime/gh-pages/spec/main/P4Runtime-Spec.pdf
+ P4_16 Portable NIC Architecture (PNA)
  + HTML: https://p4.org/p4-spec/docs/pna-working-draft-html-version.html
    + loads the file at URL https://raw.githubusercontent.com/p4lang/pna/gh-pages/docs/PNA-working-draft.html
  + PDF: https://p4.org/p4-spec/docs/pna-working-draft-pdf-version.html
    + loads the file at URL https://raw.githubusercontent.com/p4lang/pna/gh-pages/docs/PNA-working-draft.pdf
+ P4_16 Portable Switch Architecture (PSA)
  + HTML: https://p4.org/p4-spec/docs/psa-working-draft-html-version.html
    + loads the file at URL https://raw.githubusercontent.com/p4lang/p4-spec/gh-pages/docs/PSA.html
  + PDF: https://p4.org/p4-spec/docs/psa-working-draft-pdf-version.html
    + loads the file at URL https://raw.githubusercontent.com/p4lang/p4-spec/gh-pages/docs/PSA.pdf

Continue reading for the meaning of the "loads the file at URL" links.

Each of the HTML and PDF links is to a small HTML file stored on the
P4.org web server.  By entering this command:

```bash
curl -O https://p4.org/p4-spec/docs/p4-16-working-draft.html
```

You can get a copy of the HTML file at that URL.  Its contents are
shown below.

```html
<!DOCTYPE html>
<html>
<head>
<script>
const url = "https://raw.githubusercontent.com/p4lang/p4-spec/gh-pages/docs/P4-16-working-spec.html";  
const req = new XMLHttpRequest();
req.open("GET", url, true);
req.onload = (_) => {
    const doc = document.open("text/html", "replace");
    doc.write( req.response );
    doc.close();
};
req.send(null)
</script>
</head>
<body></body>
</html>
```

When someone uses a web browser to follow the working draft HTML link
for the P4_16 Language Specification, first it loads the small HTML
file from the P4.org server.  Then the JavaScript code between the
`<script>` and `</script>` tags is executed by the browser, which
loads the file from the URL
https://raw.githubusercontent.com/p4lang/p4-spec/gh-pages/docs/P4-16-working-spec.html
and displays it in the browser as HTML.  The HTML loaded by the
JavaScript code replaces the small page loaded from the P4.org web
server.

This was done in order to allow automated Github actions of the
repository https://github.com/p4lang/p4-spec to automatically generate
an HTML file from the Madoko source code, and store this HTML file
where it can be retrieved from the URL
https://raw.githubusercontent.com/p4lang/p4-spec/gh-pages/docs/P4-16-working-spec.html

Every time a commit is made to the Madoko source for the P4_16
language specification, this Github action runs, and stores the newly
generated HTML output at that URL.  An advantage of this arrangement
is that *no* files on the P4.org web server need to change on each
commit.  Even so, people browsing the P4.org specifications page and
clicking on the working draft links will see the latest generated
version.

When transitioning from HTML and PDF generated from Madoko sources, to
HTML and PDF generated from AsciiDoc sources, it seems reasonable to
expect that we might wish to change the "load the file at URL" URLs,
by editing the small HTML files stored on the P4.org server, _once_.
We do not wish to do so many times, but once is reasonable during such
a rare event as the Madoko to AsciiDoc transition.
