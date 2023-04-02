# Notes on drawing files

The web site:

+ https://draw.io

which may redirect to:

+ https://app.diagrams.net

has a free web application for editing figures, similar in style to
Visio, Omnigraffle, and the drawing capabilities of Powerpoint.

If you use it to create a drawing, it is good to save the source file
of the drawing.  I believe the default format used is called an
"mxfile", which looks a lot like an XML file with a particular schema.

To include an image in a Madoko document, PNG format is a reasonable
choice.  To create a PNG file of a drawing, select the menu item

+ File -> Export As -> PNG...

Another window appears when you choose that item.  It includes several
options, one of which is "Include a copy of my diagram" with a check
box before it.  I have found that at least on an Ubuntu 20.04 Linux
system with Madoko and TeX software installed using the
`setup-for-ubuntu-linux.sh` script, if you create a PNG file with that
box checked, running TeX will fail with an error message.
