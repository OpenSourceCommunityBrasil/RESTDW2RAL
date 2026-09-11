# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**RESTDW2RAL** lets a REST Dataware project move to PascalRAL without rewriting its code. It reimplements RDW's *ServerEvents/ClientEvents* programming model on top of RAL, with **no RDW unit linked in**: property names, collection shapes, handler signatures and the `As*` accessors are copied from RDW deliberately, so the body of an existing handler compiles and behaves the same. `src/RALRESTDWCompat.pas` closes the last gap by aliasing the RDW type names (and re-declaring the enum *values*, since Pascal has no transitive exports).

Both halves matter equally: the server side (`TRALRESTDWModule` + `TRALRESTDWServerEvents`) and the client side (`TRALRESTDWClientEvents`). A change that only serves one of them is half a change.

It ships **three packages per compiler**, split so that nobody carries what they do not use. `RALRESTDW` is the events half plus the client transport, the DataModule, the massive types and the server context, and depends only on PascalRAL; `RALRESTDWDB` adds `TRALRESTDWClientSQL`, `TRALRESTDWDatabase` and `TRALRESTDWPoolerDB`, and needs a RAL database link (`RALDBFireDACLink` on Delphi, `raldbsqldblink` on Lazarus); `RALRESTDWIndy` adds the server transport and needs `IndyRAL`. A new unit goes in four places **of the package it belongs to**: the `.dpk`, the `.dproj` `<DCCReference>` list, the `.lpk`, and the Lazarus-generated `.pas`.

There is also `ferramentas/conversor`: `uConversor.pas` holds every rule, and `rdw2ral.dpr` (console) and `gui/rdw2ralgui.dpr` (window) are two shells over it - **change the rule in the unit, never in one of the shells**, or the two drift apart. The window is the path a migrating user is meant to take; the console is for scripting.

### The shells are the load-bearing idea

A converter can rewrite a `.dfm`. It cannot rewrite *code* with any confidence, and RDW's transports are driven from code constantly - across the official RDW demos `AuthenticationOptions.OptionParams` appears 40 times, `Active` 26, `RootPath` 9, `ServerMethodClass` 5. So this project carries a class wearing each RDW transport's face with RAL inside it, and **the converter only swaps the class name**:

| RDW | shell here | unit |
| --- | --- | --- |
| `TRESTDW*ServicePooler` | `TRALRESTDWIndyServicePooler` | `RALRESTDWIndyPooler` |
| `TRESTDW*ClientPooler`, `*ClientREST` | `TRALRESTDWClient` | `RALRESTDWClient` |
| `TServerMethodDataModule` | `TRALRESTDWDataModule` | `RALRESTDWDataModule` |
| `TRESTDWIdDatabase` | `TRALRESTDWDatabase` | `RALRESTDWDatabase` |
| `TRESTDWPoolerDB`, `TRESTDWFireDACDriver` | `TRALRESTDWPoolerDB`, `TRALRESTDWFireDACDriver` | `RALRESTDWPoolerDB` |
| `TRESTDWMassiveCache` + os tipos do massive | `TRALRESTDWMassiveCache` | `RALRESTDWMassive` |
| `TRESTDWServerContext` | `TRALRESTDWServerContext` | `RALRESTDWServerContext` |
| as classes de opção (auth, cripto, proxy, conexão) | `TRALRESTDW*` | `RALRESTDWOptions` |

Three rules follow from that, and breaking any of them breaks a migrated project:

1. **Publish everything the RDW class published, even what RAL cannot honour.** DFM streaming stops at the first unknown property and takes the whole form with it. An inert member says so in a comment beside itself; Delphi 12 rejects `deprecated` on a property, so the comment plus the converter's report is the whole warning channel.
2. **The mapping lives in `RALRESTDWOptions.pas`, never in a shell.** `TRALServer` is abstract and the engine is the descendant, so there is one shell per RAL *engine* (the migrating user picks it, the RDW class name does not decide). Keeping `RALRESTDWApply*` outside them is what makes the next engine a thin file instead of a second copy of the rules.
3. **Not every RAL base has a virtual constructor.** `TRALDBConnection.Create` is declared `overload`, not `override`, so it hides `TComponent`'s virtual one: a constructor declared in a descendant is never called when the form streams the component. `TRALRESTDWDatabase` initialises in `AfterConstruction`, which is virtual and runs before the first property is read. Check the ancestor before writing a constructor.
4. **A `var` string parameter is `String`, never `StringRAL`.** `StringRAL` is `UTF8String` - one byte per character against two. The compiler refuses the mismatch on a normal call, and on a handler bound through the DFM (matched by name, signature unchecked) it does not even refuse: it corrupts. `SendEvent(..., var AError)`, `OnAuthRequest` and `OnReplyEventStr`'s `Result` all take `String`, exactly as RDW declares them.

It is an IDE component package, not an application: no `main`, **no test suite and no CI** (`.github/` holds only `FUNDING.yml`). Fifteen units in `src/`, demos under `exemplo/`.

**Reference checkouts, all sibling directories, all read-only — never edit them:**
- `../PascalRAL` — the RAL we build against (branch `dev`). Has its own `CLAUDE.md`; read it for `StringRAL`/`IntegerRAL`, `{$IFDEF FPC}@{$ENDIF}` on method pointers, `FixRoute`, `TRALParams`, typed params, `TRALModuleRoutes`, and the compiler recipes.
- `../RDW_Phoenix` — REST Dataware 2.1 (`OpenSourceCommunityBrasil/REST-DataWare`). The authority on what a member should be called and do. `CORE/Source/Basic/uRESTDW{Params,ServerEvents}.pas` and `CORE/Source/Consts/uRESTDWConsts.pas` carry almost all of it.
- `../RDW` — an older RDW checkout. Its `CORE/demos/Delphi/VCL` is where the real demos used to test the converter come from, and it is the authority on the 1.4.3 handler shape.

## Build / verify

There is nothing to run as a test. Verification is: compile the package, compile the demos, then run the demos against each other.

Install order — `RALRESTDW` requires `PascalRALDsgn`, which requires `PascalRAL` + `designide`:

```powershell
msbuild ..\PascalRAL\pkg\Delphi\PascalRAL.dproj     /t:Build /p:Config=Release /p:Platform=Win32
msbuild ..\PascalRAL\pkg\Delphi\PascalRALDsgn.dproj /t:Build /p:Config=Release /p:Platform=Win32
msbuild pkg\delphi\RALRESTDW.dproj                  /t:Build /p:Config=Release /p:Platform=Win32
msbuild pkg\delphi\RALRESTDWIndy.dproj              /t:Build /p:Config=Release /p:Platform=Win32

lazbuild --build-ide= pkg\lazarus\RALRESTDW.lpk
lazbuild --build-ide= pkg\lazarus\RALRESTDWIndy.lpk
```

If msbuild dies with `MSB6003` / "dcc could not be run", see `../PascalRAL/CLAUDE.md` — it is the `DelphiLibraryPath` length problem, not this package.

### Checking a source change without installing anything

The units compile straight against the sibling PascalRAL checkout, which is the fast loop (verified on Delphi 12, Athens 23.0). Write a throwaway `chk.dpr` outside the repo whose `uses` names the eight runtime units, and give `dcc32` the source paths — Windows-form paths, since Git Bash mangles a `/c/...` argument into something the compiler rejects:

```powershell
$bds = "C:\Program Files (x86)\Embarcadero\Studio\23.0"
$ral = "<repo>\..\PascalRAL\src"
$u = "$bds\lib\win32\release;$ral\base;$ral\base\plugins;$ral\base\modules;$ral\utils;$ral\database;<repo>\src"
$i = "$ral\base;$ral\languages;$ral\utils;<repo>\src"
& "$bds\bin\dcc32.exe" --no-config -B -Q `
  -NS"System;System.Win;Winapi;Vcl;Data;Data.Win;Xml;Web;Soap;Datasnap;FireDAC" `
  -U"$u" -I"$i" -N0"<out>" -E"<out>" chk.dpr
```

`RALRESTDWReg.pas` needs the design-time packages on top of that — a second `chk2.dpr` using only it, plus `-LU"rtl;designide"` (`designide.dcp` is in `$bds\lib\win32\release`, already on the `-U` path; there is no `DesignIntf.dcu` to find). The demos add one engine path each (`$ral\engine\indy`, `$ral\engine\netHTTP`) and need a generated `.res` — `brcc32 -fo<name>.res` over a one-line `.rc` written **without a BOM** (`Set-Content -Encoding ascii`; brcc32 rejects a UTF-8 BOM with "Bad character in source input").

**Filter dcc32's output for `(Error|Fatal): [EF]\d`, not for `\) (Error|Fatal):`.** A
missing resource comes out as `Error: E1026 File not found: 'X.res'` with no file name and
no parenthesis before it, so the narrower pattern reported a failed build as a success and
the absent `.exe` was only noticed later.

Expected noise, all pre-existing: `W1057` implicit string casts by the hundred (PascalRAL's own), one `W1055` on `TRALRESTDWParams` for the `published` block on a plain `TObject`. Anything else is yours.

**Compiling against the sources is not the whole check.** The `../PascalRAL` tree moves daily and the `PascalRAL.bpl` a user has installed can be weeks behind, so a brand-new RAL function compiles here and then refuses to install on their machine. That already happened once: `RALTools.RALSameName` landed 2026-09-10 and the installed package was from 2026-09-01. Build the package itself against the **installed** `.dcp` as well, which is the shape an install actually takes:

```powershell
$pub = "C:\Users\Public\Documents\Embarcadero\Studio\23.0"   # onde ficam Bpl e Dcp
& "$bds\bin\dcc32.exe" --no-config -B -Q -NS"..." `
  -U"$bds\lib\win32\release;$pub\Dcp;<repo>\src" -I"<repo>\src" `
  -LU"rtl;PascalRALDsgn" -N0"<out>\dcu" -LE"<out>" -LN"<out>" RALRESTDW.dpk
```

That is how `MaxRedirects` was caught: `TRALClient` only grew it recently, so the shell's
`RedirectMaximum` compiled fine against the sources and then refused to install. It is
inert now, on purpose. `RALRESTDWIndy` builds the same way but needs the freshly produced
`RALRESTDW.dcp` on the `-U` path (add the `-LE` output directory), since the installed one
is older than the units it depends on.

It needs `pkg/delphi/RALRESTDW.res`, which the IDE generates and the repo does not track - `brcc32` over a one-line `.rc` produces a usable one. Prefer the oldest API that does the job: this package should install on a PascalRAL that is a few weeks old.

**Compile with range checking on at least once.** `dcc32 --no-config` leaves `$R` off, the IDE turns it on for every Debug build, and the difference is not academic: `TRALStringStream` ends every write in `WriteBytes`, which does `Write(ABytes[0], Length(ABytes))` - indexing `[0]` of an empty array. Harmless with the check off, `ERangeError` with it on, and it fires on something as ordinary as a param declared with no `DefaultValue`. Nothing in this repo may hand empty content to those constructors; `StoreText`/`StoreStream` build an empty stream instead. Add `'-$R+'` to the dcc32 line (quoted, or PowerShell eats `$R` as a variable) and run the demos again.

### Lazarus

`lazbuild` builds the packages straight from the checkout, and Lazarus 3 with FPC 3.2.2 is installed here:

```powershell
C:\lazarus\lazbuild.exe --build-all pkg\lazarus\RALRESTDW.lpk
C:\lazarus\lazbuild.exe --build-all pkg\lazarus\RALRESTDWIndy.lpk
C:\lazarus\lazbuild.exe --build-all pkg\lazarus\RALRESTDWDB.lpk
C:\lazarus\lazbuild.exe --build-all exemplo\lazarus\cliente\cli_rdw2ral.lpi
```

`pascalral` and `pascalraldsgn` are already installed in that IDE, so the packages resolve. Two things to know:

- **The demo needs a `.res` that the repo does not track**, and `windres` here dies with `gcc: cannot exec 'cpp'`. Delphi's `brcc32` produces a plain Win32 `.res` that FPC reads fine - same one-line `.rc` recipe as above. Opening the `.lpi` in the IDE also generates it.
- **`lazbuild` writes `packagefiles.xml` into the working directory** and leaves `.obj` next to the demo. Both are in `.gitignore`; check `git status` before committing anyway.

Three FPC-only defects have already been caught this way, and all three compile silently on Delphi:

1. **`ftExtended` and `ftSingle` do not exist in FPC's `DB`.** Not a different value - the identifier is absent, so the whole `case` line has to go under `{$IFNDEF FPC}`.
2. **A method pointer needs `()` to be called.** `Result := FOnContar;` is the pointer in ObjFPC and the call in Delphi. Always write `FOnContar()`.
3. **Calling an overload of the enclosing routine by its bare name fails** with *Illegal expression*: `ApplyUpdates;` inside `function ApplyUpdates(var AError): Boolean`. `Self.ApplyUpdates()` resolves it on both compilers.

### End-to-end

`exemplo/delphi/servidor` + `exemplo/delphi/cliente` exercise every feature. For an automated pass, a console harness that drives `TRALRESTDWClientEvents` against the running server covers discovery, typed params, datasets, per-event auth and the failure paths in one run — that is how the current behaviour was validated (19 checks, all green).

**Our own demos are not the real check.** They were written against this code and agree with it by construction; a migrating user's project was not. `ferramentas/conversor/demos/` carries four real RDW demos **unconverted**, exactly as RDW publishes them minus credentials and machine paths - copy one out, convert it, compile it, and run it. Its `LEIAME.md` says what each exercises and what was blanked. `SimpleServer` is the smallest complete one and the fastest signal: set `Active = True` in its `.dfm` and drive `/teste` with every verb (the handler answers 200 for GET/DELETE and 201 for POST/PUT/PATCH, so a wrong status is a real failure and not a guess). That loop is what found every defect worth finding here - the wrong bind port, the duplicated `uses`, the missing `TRESTDWAuthBasic` alias, the `var String` mismatch.

Those demos come in two shapes and both must pass: `SimpleServer` is RDW 1.4.3 (`var Result: String`, `Routes = [crAll]`) and `FileTransfer` is RDW 2.1 (`const Result: TStringList`, `Routes.All`). Both work against the same installed package - see *Two handler shapes* below. The converter reports each rename it makes.

**Check the converted `.dfm` by RTTI, not by opening the IDE.** A property the shells do not
publish is invisible until the designer refuses the form, and finding them one dialog at a
time is a whole afternoon. A throwaway console program that links the eight runtime units,
calls `RegisterClasses` with the shell classes by hand and then walks a `.dfm` - resolving
each `object` line with `GetClass` and each `Prop.Sub = ` line with `GetPropInfo` - reports
the whole list in one run, including inside `Events = <item ...>` collections. Two things
are not published properties and must be skipped or they read as false positives: `Left`
and `Top` (from `TComponent.DefineProperties`) and `.Strings` (from `TStrings`). That probe
is how `CriptOptions`, `FailOverConnections`, `SSLVersions`, `SSLMode`, `ProxyOptions.Port`,
`MaxAuthRetries`, `RequestCharset`, `AccessControlAllowOrigin`, `VerifyCert`, `CertMode`,
`PortCert`, `OnWork*` and `BinaryCompatibleMode` were all found in one afternoon instead of
thirteen round trips through the IDE. `RegisterComponents` does nothing outside the IDE and
`LoadPackage` does not call a package's `Register`, so link the units - do not load the BPLs.

## Architecture

### Server: the module discovers the events

`TRALRESTDWModule` (`src/RALRESTDWModule.pas`) is a `TRALModuleRoutes` attached to a `TRALServer`. It owns two route collections:

- `FRDWRoutes`, built in the constructor: `getevents` and `getservereventslist` (POST + OPTIONS), the two endpoints the client uses to mirror the server.
- the inherited `Routes`, one per RDW event.

**`AutoRoutes` (default `True`) is the feature that removes the manual step.** `AutoBuildRoutes` runs from `Loaded` and from `SetServer`, instantiates `ClassModule` once, walks its `TRALRESTDWServerEvents` components and calls `AddEventRoute` per event — which maps `Routes.AllowedMethods`/`SkipAuthMethods`, `CallbackEvent` and the IN params onto the `TRALRoute`. Hand-made or imported routes win: `AutoBuildRoutes` bails out when `Routes.Count > 0`, so it never overwrites what a developer wrote. `RefreshRoutes` is the public rebuild, also exposed as the *Refresh Routes* component-editor verb.

Every route in `Routes` ends in `ReplyRoutes`. `BindRoutes` wires them from `Loaded` and at creation time, so the request path does not write to shared route objects; `CanAnswerRoute` only fills in a route added by code afterwards.

`ReplyRoutes`, `GetEvents` and `GetServerEventsList` share a shape:

1. `AResponse.Answer(HTTP_Forbidden)` up front. Everything below only *replaces* it, so **a 403 from this module means "class not registered" or "AccessTag did not match", not an auth failure.**
2. `CreateModuleObject` → `vClass.Create(nil)` — a fresh data module per request, freed in a `finally`, so handlers are stateless. Owner is deliberately `nil`: the module's component list is shared across request threads and `TComponent.InsertComponent`/`RemoveComponent` have no lock. The handler reaches the module through `TRALRESTDWParams.Module`.
3. `DoCreate` fires the component's `OnCreate` once per instance — the per-request hook RDW users expect.
4. `TRALRESTDWServerEvents.ExecuteEvent` resolves the event (by route, then `DefaultEvent`) and runs `ReplyEvent` with the component's `IgnoreInvalidParams`.

**`servereventname` is a hint, not a filter.** `ReplyRoutes` reads it by name; when absent it tries the body (see the lone-param trap below) and only keeps the value if it matches a component. Otherwise it dispatches by route across every component — which is what makes the events callable from `curl`, JavaScript or any non-Delphi client with no knowledge of RDW conventions.

### Client: the mirror fills itself

`TRALRESTDWClientEvents` (`src/RALRESTDWClientEvents.pas`) keeps a local copy of the event definitions and needs a `TRALClient` in `RALClient`. `GetEvents` is a published **Boolean** property (RDW parity — setting it True fetches); the stream-returning method is `FetchEventsStream`, and `FetchEvents` does fetch-and-apply.

**`AutoFetch` (default `True`)** makes `FindEvent` pull the definitions the first time an unknown event is asked for, so a working client needs no design-time step either. `FFetched` is set *before* the network call so a failure cannot turn into one attempt per call.

### Params: RDW shape, typed wire

`TRALRESTDWParams` / `TRALRESTDWJSONParam` (`src/RALRESTDWParams.pas`) is the RDW-shaped façade over `TRALParams`. The value lives in a `TStream`; `ObjectDirection` decides the direction of every copy:

| | IN / INOUT | OUT / INOUT |
| --- | --- | --- |
| server | `AssignRequest` | `AppendResponse` |
| client | `AppendRequest` | `AssignResponse` |

Two things are worth knowing before editing this unit:

- **`StoreText`/`StoreStream` write the payload without touching `ObjectValue`.** Every public `SetAs*` stamps the type it just wrote, which is right when the application says "this is an integer" and wrong for the paths that only carry a value across — cloning a declared param, reading the wire, applying a `DefaultValue`. Those used to flatten every declared type to `ovString`. Use `StoreText`/`SetValue` on any new copy path.
- **`WriteToRALParam`/`ReadFromRALParam` are the only places that touch the wire.** They map `ObjectValue` → `TRALParamType` (`ObjectValueToParamType`) and use RAL's `SetTypedInteger/Int64/Double/Currency/Boolean/DateTime`, so numbers and dates travel as little-endian binary and never pass through `FloatToStr`. Text and binary have no typed form and travel as the stream. Where a value *must* become text (JSON, `AsString`), `RALRESTDWTypes` supplies invariant conversions — `RALRESTDWFloatToStr`, `RALRESTDWDateTimeToStr` and friends. Adding an `As*` that formats with the local settings reintroduces the locale bug.

`toDataset` is served by `LoadFromDataSet`/`SaveToDataSet` over `TRALStorageBINLink`, the same storage `TRALDBModule` uses.

### Two binary formats, both versioned

Both use `TRALBinaryWriter` and both start with a signature and a version, because without them a mismatched pair read the next field as a length prefix and died with "stream announces more bytes than it holds".

| format | constants | written by | read by |
| --- | --- | --- | --- |
| live event list | `cEventsSignature`/`cEventsVersion` (`RALRESTDWTypes`) | `TRALRESTDWServerEvents.GetEvents` | `TRALRESTDWClientEvents.SetEvents` |
| route export | `cExportSignature`/`cExportVersion` (in `RALRESTDWModule`) | `ExportToStream` → `ExportEvents` | `ImportFromStream` |

Bump the version whenever a field moves. The export exists so routes can be published without instantiating the data module; with `AutoRoutes` it is a fallback, not the main path.

### Two handler shapes, one package

RDW 2.x hands the event result over as `const AResult: TStringList` and RDW 1.4.3 as
`var AResult: string`. This used to be the `RDW143` directive in `src/RALRESTDW.inc`, which
meant one installed package served one generation: switching rebuilt everything and broke
every wired DFM.

Both are published now, under different names - `OnReplyEvent`/`OnReplyEventByType` for the
2.x shape and `OnReplyEventStr`/`OnReplyEventByTypeStr` for 1.4.3 - and `ReplyEvent` fires
whichever is assigned. The converter picks the name when it rewrites the `.dfm`. The
directive is gone; the `.inc` stays, empty, because the units include it.

**The shape is per handler, not per file.** The RDW `FullServer` demo carries handlers of
both generations side by side in `uDMPrincipal.pas`. Deciding by file bound half the events
to the wrong signature, and because the DFM binds by name without checking, that is not a
compile error - it is an access violation on the first call. `FormaDoMetodo` looks up the
method named on the very `OnReplyEvent = ` line being rewritten.

### Where things live

| unit | what for |
| --- | --- |
| `RALRESTDWTypes` | the RDW enums, the `ObjectValue` → RAL/field-type maps, the invariant text conversions, the stream signature |
| `RALRESTDWParams` | runtime params, the wire, JSON, datasets, the `TParam` bridge |
| `RALRESTDWParamsMethods` | design-time param declaration, cloned into the runtime container |
| `RALRESTDWEvents` | the event items, `TRALRESTDWRoutes` (verbs), `ReplyEvent` |
| `RALRESTDWServerEvents` | the server component, `ExecuteEvent`, the two serializers |
| `RALRESTDWClientEvents` | the client component |
| `RALRESTDWModule` | route discovery, dispatch, export/import |
| `RALRESTDWCompat` | RDW type and enum names, plus the `StringRAL`/`IntegerRAL` aliases |
| `RALRESTDWClientSQL` | the remote dataset, RDW-shaped, over RAL's memtable (package `RALRESTDWDB`) |
| `RALRESTDWDBReg` | palette registration for the database half |
| `RALRESTDWReg` | palette, component editors, property editor |

### The database half: two seams, not one

RDW puts `TRESTDWPoolerDB` inside the server DataModule and points it at a driver
component; RAL hangs a `TRALDBModule` off the `TRALServer` and answers on a route. Three
things have to happen for a migrated project to reach its database, and each was a separate
silent failure:

1. **Somebody has to create the `TRALDBModule`.** `TRALRESTDWPoolerDB.ConfigurarModulo`
   existed and nothing called it, so `/datadm` answered 404 with everything else correct.
   `TRALRESTDWModule.RefreshRoutes` now calls the `RALRESTDWMontarBanco` hook while it has
   the DataModule instance in hand. It is a hook and not a call because `RALRESTDWPoolerDB`
   lives in `RALRESTDWDB`: the events package must not drag RAL's database link along.
2. **The link class has to be registered.** `TRALDBModule.DatabaseLink` is matched against
   `TRALDBBase.DatabaseName`, and the registration is the `initialization` of the link unit
   — `RALDBFireDAC` on Delphi, `RALDBSQLDB` on FPC. Without it in `uses` the server
   answers *DBLink Property missing* on the first query. `RALRESTDWPoolerDB` names it, so
   any project that links the shell gets it.
3. **The project's own connection code has to run.** This is the one that matters. RDW
   builds the connection in the `BeforeConnect` of the project's `TFDConnection`, per
   request, reading an `.ini` or form fields — nothing is in the `.dfm`. RAL keeps the
   connection as strings on the module and builds its own driver, so that handler would
   never fire and the server would reach Firebird with no user and no path.
   `TRALRESTDWPonteConexao` hooks `TRALDBModule.OnBeforeConnect`, which arrives with RAL's
   connection and before it opens: it creates the project's DataModule, calls **its**
   `BeforeConnect` through RTTI (`GetMethodProp`, no connection opened) and copies the
   resulting `Params` across. Reading the params once at setup is not enough and looks
   right until you try it.

**`ChangeCount` is not the pending count.** RAL leaves FireDAC's `CachedUpdates` off and
keeps pending statements in a private `TRALDBSQLCache`, so `ChangeCount` is always 0 and
the cache is unreachable from a descendant. `TRALRESTDWClientSQL` counts them itself in
`InternalPost`/`InternalDelete` — that is what `MassiveCount` reports, and what keeps
`ApplyUpdates` from calling RAL with an empty cache, which faults inside RAL.

### O que o conversor troca no código, e por quê

The converter renames the **RDW-namespaced types** (`TRESTDWParams`, `TDWParams`,
`TRESTDWAuthOptionBasic`, ...) in the `.pas` as well, always - not only with `--tipos`.
It has to: the compat unit aliases them and the compiler is happy, but **the IDE
designer resolves the type name through RDW's own design package** when that is
installed, and then refuses every bound handler with *has an incompatible parameter
list* on opening the form. Measured on this machine, where `RESTDWCoreDesign.bpl` is
installed alongside ours.

That is why `RALRESTDWCompat` re-exports the native `TRALRESTDW*` names too: with the
types renamed, a converted unit still needs nothing but `RALRESTDWCompat` in its uses.
Names that are *not* RDW-namespaced (`TDataMode`, `TObjectValue`, `TTypeObject`,
`TObjectDirection`, `TSendEvent`) stay behind `--tipos`: a project may have its own.

## Traps

- **A lone body param travels without its name.** PascalRAL's `EncodeBody` skips multipart when there is exactly one body param and sends the raw value; the name arrives as `ral_body`. This bit both directions — `getevents` sends only `servereventname` when `AccessTag` is empty, and a handler returning just text answers with only `cUndefined`. Both sides now read in two steps (by name, then `Body`). Its own `CLAUDE.md` says not to "fix" this in RAL, so any new param that can travel alone needs the same two-step read.
- **PascalRAL faults under `$R+` on any query with a parameter.** `RALDBSQLCache.GetQueryParams` (`src/database/RALDBSQLCache.pas`, line 308) does `vParam.Size := GetInt64Prop(vColetItem, 'Size')` - reading an `Integer` property as `Int64`. Range checking turns the truncation into `ERangeError`, and the IDE turns range checking on for every Debug build. Confirmed by map lookup, with a param whose `Size` is 0 and `DataType` is `ftInteger`; setting `Size` by hand does not help, because the bad read happens inside RAL. **There is no client-side workaround** - it has to be fixed there (`GetOrdProp`). The events half is unaffected. Until then the DB demos need range checking off.
- **Only `Open` is asynchronous.** `TRALDBConnection` posts `ExecSQL` and `ApplyUpdates`
  with `ebSingleThread`, so their callback has already run when `inherited` returns;
  only `OpenRemote` is threaded. Waiting for those two through `CheckSynchronize` meant
  nothing ever arrived and the wait ran the full `RequestTimeout` - thirty seconds of
  frozen window on every `ExecSQL`, with the command already executed. `ExecSQL` and
  `ApplyUpdates` now mark the response done before calling `WaitResponse`, which is
  still called because it is what raises the stored error in the caller's context.
- **`ApplyUpdates` posts the open edit first.** In a grid the record sits in `dsEdit`
  until the user leaves the row, and the project's button calls `ApplyUpdates` straight
  away: without the `Post` the change on screen never became a pending statement and the
  next `Open` brought back the old value. RDW posts it too.
- **The DB calls are async in RAL and synchronous here.** `TRALDBConnection` posts `Open`/`ExecSQL`/`ApplyUpdates` with a callback and `ebMultiThread`, so they return before the answer exists. `TRALRESTDWClientSQL.WaitResponse` pumps `CheckSynchronize` until the callback lands, because RDW's are synchronous and ported code reads `RecordCount` on the next line. It re-enters: the callback calls `SetActive` again, and `FWaiting` is what keeps that from waiting on itself. `ThreadRequest` opts back out.
- **An error raised inside the callback escapes the caller's `try..except`.** That is why `InternalError` only *stores* the message and `WaitResponse` raises it - in the context of whoever called `Open`.
- **`RootPath` is a folder on disk, not a URL prefix.** RDW serves static files from it
  (`IncludeTrailingPathDelimiter(FRootPath) + file`). Mapping it to the module's `Domain`
  looked reasonable and broke every route in the `FullServer` demo, which does
  `RootPath := ExtractFilePath(Application.ExeName)`. It feeds a `TRALWebModule.DocumentRoot`
  now; that module only claims a request when a matching file exists inside the folder, so
  it never shadows an event route.
- **A lone OUT param comes back without its name.** The same trap as the request side:
  PascalRAL skips multipart for a single body param, so `AResponse.ParamByName('result')`
  finds nothing and the value was dropped in silence — `servertime` answered empty with
  the server perfectly correct. `AssignResponse` falls back to `Body` when exactly one OUT
  param was declared and none matched by name.
- **`SendEvent`'s `ANativeResult` is the response body**, as in RDW (`TReplyOK` normally,
  the handler's raw text in `dmRaw`). It used to carry the status code, which the demos
  then showed on screen.
- **RAL's memtable cannot be opened without a connection, so `OpenJson` does not work.**
  `TRALDBFDMemTable.SetActive` raises *Connection not set* when `RALConnection` is nil and
  goes to the server when it is not; there is no local path, and `CreateDataSet` needs one.
  RDW's `OpenJson` is purely local - parse a JSON an API returned and show it. The fix is one
  line in PascalRAL: in the nil-connection
  branch of `SetActive`, call `inherited` instead of raising. Until then `OpenJson` raises a
  message naming the cause rather than passing RAL's along. Do not "fix" it here by
  assigning a throwaway connection - that reaches the server and comes back 404, which was
  measured, not guessed.
- **`ItemsString['x']` returns nil** when the param is not there — same as RDW, deliberately. Every new consumer needs the nil check.
- **Do not subclass `TRALRESTDWServerEvents` without passing the item class.** `TRALRESTDWEventList.Create` takes `AItemClass` now; it used to pick it by comparing the owner's class *name* with a literal, which silently gave a descendant items with no handlers.
- **`CreateDWParams` allocates and the caller owns the object.** It nils the `var` first, so an unknown event is detectable, but nothing frees it for you.
- **The data module is created per request.** Anything expensive in its `OnCreate` runs on every call. That is the RDW semantic, and it is what makes handlers thread-safe.
- **`exemplo/lazarus/cliente` has not been compiled.** Only the Delphi side was validated.

## Repo conventions

Code and `///` comments are in English; the comments that explain a decision inside a method are in Portuguese, matching the commit language. Commit messages are in Portuguese and every line is a `- ` bullet — the first bullet *is* the subject, there is no subject/body split and no Conventional Commits. Work happens on `dev`; `main` is the release branch. Remote is `OpenSourceCommunityBrasil/RESTDW2RAL`. Naming follows PascalRAL: `F` fields, `A` arguments, `v` locals.

There is a `.gitignore` covering build output and IDE session files, but no `.gitattributes`, no hooks and no CI. The demo project files (`exemplo/**/*.dproj`, `*.lps`) are ignored on purpose: opening the `.dpr` or `.lpi` recreates them, and what the IDE writes carries the machine's whole installed-package list. The package project `pkg/delphi/RALRESTDW.dproj` is tracked and must stay so. Every tracked file is CRLF, `.md` included — `sed -i` and `perl -pi` under Git Bash write LF back and turn the diff into the whole file, so normalize before committing. There is no Python on this machine; `perl` is the scripting tool that works.

A new unit has to be registered in four places or one compiler silently misses it: `pkg/delphi/RALRESTDW.dpk` (`contains`), the `.dproj` `<DCCReference>` list, `pkg/lazarus/RALRESTDW.lpk` (`<Files>`), and the Lazarus-generated `pkg/lazarus/RALRESTDW.pas`.

Component glyphs: Delphi reads `pkg/delphi/RALRESTDW.dcr`, regenerated by `assets/src/_gerardcr.bat`; Lazarus reads `pkg/lazarus/RALRESTDW.lrs`, included by `RALRESTDWReg.pas` under `{$IFDEF FPC}`.
