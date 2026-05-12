#! /usr/bin/env python3

# SPDX-FileCopyrightText: 2024 The P4 Language Consortium
#
# SPDX-License-Identifier: Apache-2.0

import fileinput
import re

for line in fileinput.input():
    match = re.match(r"^// (tag|end)::", line)
    if not match:
        print(line, end='')
