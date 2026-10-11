#!/bin/sh
# Roda os testes de unidade do EFinancesKit (regras, API, sessão, modo demonstração e view models) neste Mac.
# Com o Xcode instalado, `swift test` sozinho basta; só com as Command Line Tools é preciso apontar o Swift Testing.
set -e
cd "$(dirname "$0")/../Packages/EFinancesKit"
CLT=/Library/Developer/CommandLineTools/Library/Developer
if xcodebuild -version >/dev/null 2>&1; then
  swift test "$@"
else
  swift test -Xswiftc -F -Xswiftc "$CLT/Frameworks" -Xlinker -F -Xlinker "$CLT/Frameworks" \
    -Xlinker -rpath -Xlinker "$CLT/Frameworks" -Xlinker -rpath -Xlinker "$CLT/usr/lib" "$@"
fi
