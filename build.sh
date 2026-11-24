#!/bin/sh
# Baut GEOLOS.GEO mit dem SDK pcgeos-1-sdk-v2. Aufruf:
#   SDK=/pfad/zu/pcgeos-1-sdk-v2 ./build.sh
set -e
cd "$(dirname "$0")"
HERE=$(pwd)
SDK=${SDK:-$HERE/../pcgeos-1-sdk-v2}
export SDK
python3 tools/gen_help.py >/dev/null
(cd icon && python3 build_monikers.py >/dev/null)
(cd "$SDK" && perl sdk.pl build --project "$HERE/app" >/dev/null)
mkdir -p out
perl tools/postbuild.pl "$SDK/build/geolos/geolos.geo" out/GEOLOS.GEO icon 560 420
# Test ohne GeoWorks: DATADIR=... python3 test/emu.py "$SDK/build/geolos/geolos.resource.bin"
