# DevLibScript

Bouw en installeer Boost en wxWidgets met Bash. Voer opdrachten uit vanuit
deze repository. `boost` en `wxwidgets` selecteren een library; `all` beide.
Messaginglibrary en robotworld worden niet meer beheerd.

## Native Linux en Windows/MSYS2

```bash
./build_devlib.sh --buildtool both --compiler both all
```

`--buildtool configure|cmake|both` selecteert het buildsysteem van wxWidgets.
Boost gebruikt altijd b2. `--compiler gcc|clang|both` selecteert native
compilers. Standaard zijn `configure`, de gedetecteerde compiler en
`--debug true` actief. Windows gebruikt de bestaande 64-bit MSYS2-route.

Boost.Process wordt gebouwd met de B2-feature `boost.process.fs=std`, die
`BOOST_PROCESS_USE_STD_FS` definieert, zodat de
geïnstalleerde Boost.Process-library geen Boost.Filesystem-linkdependency
heeft. De native en cross-routes nemen Boost.Process expliciet mee.

Native Windows-CMake gebruikt standaard de Windows-librarynaamgeving en
installeert daarbij geen `wx-config`. Dit is normaal wxWidgets-gedrag.
Gebruik voor CMake-consumers de exports met
`find_package(wxWidgets CONFIG REQUIRED)`. De Autotools-installatie heeft
wel een wx-config; kopieer die niet naar de CMake-installatie.

Native builds verwijderen vooraf de installaties van de geselecteerde library
voor het gekozen platform. De canonieke bronboom blijft behouden en wordt door
native en cross builds gedeeld. Bekijk de acties eerst met `--dry-run`.

## Linux naar Windows x86-64

Gebruik MinGW-GCC en een aparte stagingroot:

```bash
SRC_DIR="$HOME/devlib-cross-test/src" \
INSTALL_DIR="$HOME/devlib-cross-test" \
LOG_DIR="$HOME/devlib-cross-test/logs" \
NUMBER_OF_COMPILATIONS=4 \
./build_devlib.sh --target x86_64-w64-mingw32 --compiler gcc --buildtool both all
```

Voeg `--dry-run` toe om opdrachten te bekijken zonder downloaden, bouwen,
installeren of opruimen. Cross ondersteunt alleen GCC.
Boost wordt eenmaal gebouwd; wxWidgets met `both` via CMake en Autotools.
Cross verwijdert geen installaties en weigert een bestaande geselecteerde
prefix te overschrijven. Kies dan een andere `INSTALL_DIR`.

Crosspaden onder de gekozen roots:

| Onderdeel | Pad |
|---|---|
| Gedeelde bronnen | `<SRC_DIR>/boost_1_90_0/` en `<SRC_DIR>/wxWidgets-3.3.2/` |
| Cross-builds | `<SRC_DIR>/<library>/build/mingw-cross/` |
| Logs | `<LOG_DIR>/cross/x86_64-w64-mingw32/` |
| Boost | `<INSTALL_DIR>/windows/boost/mingw/boost.tagged/` |
| wxWidgets | `<INSTALL_DIR>/windows/wxwidgets/<cmake-of-configure>/mingw/wxWidgets-3.3.2/` |

Gebruik absolute roots. Zonder overrides blijven de roots `~/devlib/src`,
`~/devlib` en `~/devlib/logs`. Native en cross gebruiken exact dezelfde
uitgepakte bronboom; alleen de builddirectories verschillen. Crossbinaries gebruiken Windows-DLL's, geen
Linux-libraries. Kopieer voor uitvoering de bijpassende library- en
compiler-runtime-DLL's mee; vermeng geen verschillende builds van wxWidgets.

Boost-cross bouwt de bestaande geselecteerde set release/shared libraries
met system-layout en C++17. De naam `boost.tagged` is alleen de behouden
directorynaam. `--debug` verandert deze Boost-crosskeuze niet.
Voor wxWidgets kiest `--debug true` bij CMake RelWithDebInfo en bij
Autotools `--enable-debug`; false kiest Release respectievelijk
`--disable-debug`. Er is geen aparte debug/release-installatiemap.

Benodigd: Bash, GNU getopt, wget, tar/bzip2, tee, native GCC/G++ voor b2
en `x86_64-w64-mingw32-g++`. wxWidgets vereist ook de MinGW C- en
resourcecompiler; CMake/Ninja voor CMake, make en MinGW ar/ranlib voor
Autotools. Tools worden niet automatisch geinstalleerd.

## Controles

```bash
bash tests/check_flows.sh
shellcheck -x build_devlib.sh tests/check_flows.sh
```

De flowcontrole voert geen echte builds uit. Kleine linkvoorbeelden staan
in `tests/boost_smoke` en `tests/wxwidgets_smoke`; geef expliciet de bedoelde
crossinstallatie mee bij het configureren. Voor Autotools-wxWidgets kan het
GUI-voorbeeld rechtstreeks met de crosscompiler en de `--cxxflags` en
`--libs core,base` van de geinstalleerde wx-config worden gebouwd.

Boost, wxWidgets-CMake en wxWidgets-Autotools zijn in staging gebouwd en
Windows x86-64-testprogramma's zijn ertegen gelinkt. Voor wxWidgets zijn
beide crossroutes met zowel `--debug true` als `--debug false` gebouwd.
Uitvoering op Windows
staat nog open. De gebruiker meldt dat de native MSYS2-bouw is afgerond
zonder zichtbare fouten; de Windows-buildlogs zijn hier niet gecontroleerd.
De native Linux-bouw is eveneens afgerond, met de nog te behandelen
Boost.Histogram-installatiediagnose.
Zie `CROSSCOMPILATIE-PLAN.md` voor voortgang en beperkingen.
