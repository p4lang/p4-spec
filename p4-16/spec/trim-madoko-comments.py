#! /usr/bin/env python3

import fileinput
import re

for line in fileinput.input():
    match = re.match(r"^// (BEGIN|END):", line)
    if not match:
        print(line, end='')
