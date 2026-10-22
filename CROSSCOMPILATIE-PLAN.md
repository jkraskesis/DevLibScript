# Boost en wxWidgets: eenvoudige crosscompilatie

## Uitgangspunt

Alleen Boost en wxWidgets blijven in `build_devlib.sh`. De bewezen native
Linux- en Windows/MSYS2-routes blijven behouden. Crosscompilatie hergebruikt
de bestaande modules, met een expliciete crosskeuze en directe instellingen
in Bash. Geen framework, Python of afzonderlijke configuratie-/padmodules.

`BUILD_OS` beschrijft de uitvoeromgeving; `TARGET_OS` het doelplatform.
`--target x86_64-w64-mingw32` selecteert Linux naar Windows met MinGW-GCC.
Zonder deze optie blijft de bestaande native selectie actief.

Bewaar alleen de benodigde controles: geldige argumenten, beschikbare tools,
het compilertriplet, duidelijke fouten en geen bestaande crossinstallatie
overschrijven. Crossbronnen en logs krijgen een eigen directory per triplet.
Er wordt niets automatisch verwijderd in de crossroute.
Geen uitgebreid padcontroleframework of bescherming tegen zelfgekozen
symlinkomleidingen; de gebruiker kiest de bron-, log- en stagingroots.

## Bestaande situatie

| Library | Buildsysteem | Crossinstallatie onder `~/devlib/` |
|---|---|---|
| Boost 1.90.0 | b2 | `windows/boost/mingw/boost.tagged/` |
| wxWidgets 3.3.2 | CMake of Autotools | `windows/wxwidgets/cmake/mingw/wxWidgets-3.3.2/` |

`windows` en `mingw` zijn hier padlabels. Native MSYS2 gebruikt de bestaande
`mingw/<library>/<...>/<gcc-of-clang>/...`-indeling; die verandert niet.
Geen extra debug/release-directoryniveau toevoegen.

De bekeken Boost-metadata vermeldt release/shared, shared runtime,
multi-threading, 64-bit en **layout=system**, ondanks de mapnaam boost.tagged.
wx-config beschrijft release/shared MSW met de MinGW-crosscompiler.
Bekeken DLL's importeren MSVCRT en de GCC/C++-runtime.
De huidige beschikbare crosscompiler is GCC 16-posix; de oorspronkelijke
crosscompiler en commando's zijn niet meer bekend.

Native Linux-opdrachten zijn beschikbaar in `~/devlib/logs` en de
bouwdirectories onder `~/devlib/src`. Die zijn de referentie, niet nieuw
uitgevoerde regressiebouws. Exacte MSYS2-lesopdrachten zijn nog niet vastgelegd.
Messaginglibrary, robotworld en andere devlib-projecten blijven onaangeroerd.

## Stappen en voortgang

### 1. Inventarisatie

Onderzocht: bestaande paden, metadata, binaries, native logs en te verwijderen
projectverwijzingen. Reconstrueer crosskeuzes uit deze gegevens; het ontbreken
van de oorspronkelijke crosscommando's is geen blokkade.

### 2. Alleen twee libraries

Uitgevoerd: messaginglibrary en robotworld zijn uit configuratie, selectie,
uitvoer en bouwlogica verwijderd, evenals hun modules. `all` betekent nu
Boost en wxWidgets; verwijderde/onbekende selectors geven een fout voordat
bouw- of opruimacties plaatsvinden. Geen devlib-bestanden verwijderd.

### 3. Eenvoudige selectie, paden en dry-run

Geimplementeerd in de bestaande `modules/build.sh`:

- Opties `--target` en `--dry-run`, met argumentcontrole.
- Native hostinstellingen gekozen op `BUILD_OS`, niet op het doelplatform.
- Crossbronnen onder `<SRC_DIR>/cross/<triplet>`, logs onder
  `<LOG_DIR>/cross/<triplet>`.
- Instelbare `SRC_DIR`, `INSTALL_DIR`, `LOG_DIR` en optioneel
  `NUMBER_OF_COMPILATIONS`; bestaande standaardpaden behouden.
- Weigering om een bestaande Boost-crossprefix te overschrijven.
- Twee kleine helpers voor commandopreview en foutgevoelige logging via tee.

Native dry-run werkt zonder bronnen. Voor cross werken `boost`, `wxwidgets`
en `all` met `--buildtool cmake|configure|both`.
De eerdere extra toolchain-/padmodules en Python-tests zijn verwijderd.

### 4. Boost-crossroute

Geimplementeerd in de bestaande Boost-module, met directe crossvertakkingen:
native GCC bootstrapt b2; een lokale Jam-configuratie selecteert MinGW voor
de libraries. Geen wijziging aan `~/user-config.jam`.

Selectie zoals de referentie-installatie: release/shared, C++17, system-layout,
atomic, chrono, container, date_time, exception, filesystem, json,
program_options, regex en thread. Exception levert een static archive.
Native Boost-argumenten blijven behouden.

Een echte proefbuild met vier jobs is geslaagd in de sessiewerkmap onder
`files/boost-cross-test/`. b2 is Linux ELF; het Boost.Filesystem-testprogramma
is Windows x86-64 en linkt via de nieuwe CMake-export tegen de nieuwe DLL.
Dit programma is nog niet op Windows uitgevoerd. Herhaal de proef na
inhoudelijke wijzigingen aan de crossbouwopdrachten.

### 5. wxWidgets met CMake

De crossvertakkingen zijn aangesloten op de bestaande wxWidgets-functies.
`toolchains/mingw-gcc.cmake` selecteert Windows x86-64 en de MinGW-tools.
De Windows-zoekroot wordt afgeleid van de compilerlocatie van libkernel32.a;
Linux-packages worden niet als targetdependencies gebruikt. Extra targetroots
voor consumers kunnen via `CMAKE_FIND_ROOT_PATH` worden meegegeven.

De opdracht bouwt shared MSW-libraries, C++17, zonder samples/tests.
`--debug true` behoudt de bestaande CMake-keuze RelWithDebInfo;
`--debug false` kiest Release. De platformmap blijft `windows` en de
compilerpadnaam `mingw`. Een bestaande geselecteerde wxWidgets-prefix wordt
voor enige bouwactie geweigerd, ook bij `all`.

De bronnen worden uitsluitend in de crossbronboom hergebruikt, nooit
opgeruimd. Configuratie, bouw en installatie gebruiken dezelfde opdrachten
voor echte uitvoering en dry-run. Fouten stoppen de flow, ook achter tee.
`tests/wxwidgets_smoke` is een klein GUI-linkvoorbeeld via de CMake-exports.

De echte stagingbouw met vier jobs is geslaagd onder de sessiewerkmap
`files/wx-cross-test/`. De installatie bevat nu wel CMake-packagefiles.
Het GUI-voorbeeld configureert via die exports en linkt als Windows x86-64
GUI-executable tegen `wxbase332u_gcc_custom.dll` en
`wxmsw332u_core_gcc_custom.dll`. De executable importeert daarnaast MSVCRT
en de GCC/C++-runtime. Uitvoering op Windows is nog niet gecontroleerd.

1. Voeg een klein CMake-toolchainbestand toe met Windows als doel en de
   geselecteerde MinGW-tools. Geen machinespecifieke compilerpaden.
2. Geef dit alleen in crossmodus mee; behoud native argumenten.
3. Bouw de MSW-port in een eigen crossbouwdirectory. Zorg dat CMake geen
   Linux-libraries kiest en Windows-testprogramma's niet op Linux uitvoert.
4. Gebruik de bestaande crossprefixvorm en weiger overschrijven vooraf.
5. Sluit dezelfde directe opdrachten aan op dry-run. Stop bij fouten,
   inclusief fouten die anders door tee gemaskeerd worden.
6. Bouw in staging en link een klein GUI-testprogramma; controleer de exports
   en DLL's. In de bestaande Windows-installatie zijn geen CMake-packagefiles
   gevonden, hoewel de bron ze kan exporteren: controleer dit bij installatie.
7. Test het programma op Windows met de benodigde DLL's. Gebruik robotworld
   niet als testdoel en maak Wine geen impliciete vereiste.

### 6. wxWidgets met Autotools

De configure-crossroute is aangesloten in dezelfde bestaande functies.
Ze bepaalt het GNU-buildtriplet met de config.guess uit de bron en geeft
`--build`, `--host`, de MinGW-tools, MSW, shared en C++17 expliciet mee.
De eigen bouwdirectory is `wxwidgets-configure` onder de crossbronroot.
`--debug true` geeft `--enable-debug`, false geeft `--disable-debug`;
de bestaande native configure-argumenten blijven ongewijzigd.

`--buildtool both` bouwt Boost eenmaal en beide wxWidgets-varianten in
afzonderlijke directories en prefixes. Alle geselecteerde prefixes worden
vooraf op aanwezigheid gecontroleerd; ook een bestaande configure-prefix
blokkeert de volledige opdracht. Dry-run toont beide routes zonder bronnen.

De echte Autotools-stagingbouw met vier jobs en debug ingeschakeld is
geslaagd onder `files/wx-cross-test/`. De geinstalleerde wx-config draait op
Linux, meldt versie 3.3.2 en selecteert de x86-64-MinGW-compiler. Hetzelfde
GUI-voorbeeld is met zijn cxxflags en core/base-linkvlaggen gebouwd en is
Windows x86-64. De importtabel bevat de wxWidgets-base/core-DLL's en de
MSVCRT/GCC-runtime. Uitvoering op Windows blijft open.

Ook `--debug false --buildtool both` is daadwerkelijk gebouwd met 20 jobs,
naar een afzonderlijke `install-release`-prefix in dezelfde stagingroot.
CMake bevestigt `Release`; Autotools-wx-config geeft `wxDEBUG_LEVEL=0`.
Beide GUI-voorbeelden linken tegen hun expliciete release-installaties
en zijn Windows x86-64. De native Windows-CMake-instellingen zijn hierbij
niet gewijzigd.

1. Bepaal een echt GNU-buildtriplet, bijvoorbeeld met config.guess.
2. Geef `--build`, `--host=x86_64-w64-mingw32` en de cross-tools mee.
   Autotools gebruikt hiervoor `--host`, niet `--target`.
3. Bouw met native make en installeer afzonderlijk onder
   `windows/wxwidgets/configure/mingw/wxWidgets-3.3.2/`.
4. Controleer dat wx-config op Linux draait en crossargumenten teruggeeft.
5. Herhaal de GUI-link- en Windows-runtimeproef.
6. Ondersteun dan cross `--buildtool both`: twee wxWidgets-varianten,
   maar slechts een Boost-build.

### 7. Controle en documentatie

Gebruik Bash en bestaande hulpmiddelen, geen Python-testinfrastructuur:

```bash
bash tests/check_flows.sh
shellcheck -x build_devlib.sh
```

Controleer ook Bash-syntaxis van elk gewijzigd script. De Bash-flowcontrole
blokkeert filesystemveranderende commando's en controleert native dry-run
voor Linux en gesimuleerd MSYS2, de Boost-crosspreview en ongeldige selectors.
Dat is geen vervanging voor echte native of crossbuilds.

Behoud `tests/boost_smoke` als klein CMake/C++-linkvoorbeeld.
Controleer echte resultaten met file/objdump en runtimeproeven op Windows.
Native MSYS2-regressie blijft open totdat die op MSYS2 is uitgevoerd.
Update: de gebruiker heeft de native MSYS2-bouw uitgevoerd en meldt geen
zichtbare fouten. De logs zijn hier nog niet gecontroleerd. Het ontbreken
van wx-config bij de native CMake-installaties is normaal: wxWidgets kiest
daar standaard Windows/MSVC-naamgeving en slaat wx-config-installatie over.
Dit gedrag blijft behouden; de CMake-package-exports zijn de consumerroute.
Een native Linux-regressiebouw is vanaf nieuwe downloads uitgevoerd in een
nieuwe `~/devlib`, met 20 parallelle jobs, GCC en Clang en beide
wxWidgets-buildsystemen. `~/devlib.org` is daarbij niet benaderd.
De opdracht eindigde met exitcode 0; beide Boost-installaties en alle vier
wxWidgets-installaties zijn aanwezig. wx-config meldt bij alle vier 3.3.2/GTK3.
Boost rapporteerde wel acht `No best alternative`-diagnoses voor
`histogram/install-libraries-shared` (beide compilers, debug/release,
multi/single). B2 stopte daar niet op; deze diagnoses zijn nog niet onderzocht.
Beschouw dit dus niet als een volledig foutloze Boost-regressie.
Documenteer het uiteindelijke gebruik en de beperkingen in een README.
Commit of push alleen na opdracht.

## Gebruik

```bash
# Native opdracht tonen zonder bouw-/opruimacties.
./build_devlib.sh --dry-run --buildtool both --compiler both all

# Boost-crossbuild in een afzonderlijke stagingroot.
SRC_DIR="$HOME/devlib-cross-test/src" \
INSTALL_DIR="$HOME/devlib-cross-test" \
LOG_DIR="$HOME/devlib-cross-test/logs" \
NUMBER_OF_COMPILATIONS=4 \
./build_devlib.sh --target x86_64-w64-mingw32 --buildtool cmake --compiler gcc boost
```

Vervang `boost` door `wxwidgets` voor alleen wxWidgets of door `all` voor beide.
De opdracht weigert iedere reeds aanwezige geselecteerde installatieprefix.
Voor het GUI-linkvoorbeeld, na installatie in een stagingroot:

```bash
cmake -S tests/wxwidgets_smoke -B /tmp/wxwidgets-smoke -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$PWD/toolchains/mingw-gcc.cmake" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_FIND_ROOT_PATH="$HOME/devlib-cross-test/windows/wxwidgets/cmake/mingw/wxWidgets-3.3.2"
cmake --build /tmp/wxwidgets-smoke
```

Voeg `--dry-run` toe voor de crosspreview. De bestaande installatieprefix
mag niet aanwezig zijn; kies voor een nieuwe proef een andere stagingroot.
Bewaar een mislukte gedeeltelijke installatie voor inspectie; verwijder die
niet automatisch. Cross ondersteunt alleen GCC. `--buildtool` selecteert
`cmake`, `configure` of `both` voor wxWidgets; Boost gebruikt altijd b2.

## Opdracht aan de uitvoerende agent

Houd volgende wijzigingen klein en lineair, in de bestaande modules.
Voeg alleen een helper toe als die aantoonbaar duplicatie voorkomt.
Geen Python, Meson, generiek platformframework of onnodige configuratielagen.
Behoud native Linux/MSYS2-instellingen; wijzig geen libraryversies.
Bouw en installeer proeven uitsluitend in staging. Wijzig of verwijder geen
bestaande devlib-installaties en pas externe repositories niet aan zonder
toestemming.
