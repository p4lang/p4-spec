#! /bin/bash

# SPDX-FileCopyrightText: 2026 Andy Fingerhut
#
# SPDX-License-Identifier: Apache-2.0

# This is a simple Bash script that demonstrates one way to add
# copyright and license information for files using the `reuse
# annotate` command.
#
# https://reuse.software/

# Comments in this file also document the source where I learned of
# the copyright and license information of the font files in this
# repository.

set -x

# Source for copyright holder and license information about the Luxi
# Mono font:
# https://www.fontsquirrel.com/fonts/luxi-mono

COPYRIGHT_HOLDER="Bigelow & Holmes Inc."
YEAR="2001"

for filename in p4-16/spec/resources/fonts/LuxiMono/*.ttf
do
    reuse annotate -c "${COPYRIGHT_HOLDER}" -l "LicenseRef-Luxi-font-license" -y ${YEAR} --fallback-dot-license "${filename}"
done

# Source for copyright holder and license information about the Open
# Sans font:
# https://fonts.google.com/specimen/Open+Sans/license

COPYRIGHT_HOLDER="The Open Sans Project Authors"
YEAR="2020"

for filename in p4-16/spec/resources/fonts/OpenSans/*.ttf
do
    reuse annotate -c "${COPYRIGHT_HOLDER}" -l "OFL-1.1" -y "${YEAR}" --fallback-dot-license "${filename}"
done

# Source for copyright holder and license information about the Utopia
# font:
# https://mirror.math.princeton.edu/pub/CTAN/fonts/utopia/LICENSE-utopia.txt#:~:text=%2D%2DKarl%20Berry%2C%20TUG%20President%2C%20on%20behalf%20of,copyrights%2C%20to%20use%2C%20reproduce%2C%20display%20and%20distribute

COPYRIGHT_HOLDER="Adobe Systems Incorporated"
YEAR1="1989"
YEAR2="1991"

for filename in p4-16/spec/resources/fonts/Utopia/*.ttf
do
    reuse annotate -c "${COPYRIGHT_HOLDER}" -l "LicenseRef-Utopia-font-license" -y "${YEAR1},${YEAR2}" --fallback-dot-license "${filename}"
done
