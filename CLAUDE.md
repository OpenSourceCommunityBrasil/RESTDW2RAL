# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**RESTDW2RAL** lets a REST Dataware project move to PascalRAL without rewriting its code. It reimplements RDW's *ServerEvents/ClientEvents* programming model on top of RAL, with **no RDW unit linked in**: property names, collection shapes, handler signatures and the `As*` accessors are copied from RDW deliberately, so the body of an existing handler compiles and behaves the same. `src/RALRESTDWCompat.pas` closes the last gap by aliasing the RDW type names (and re-declaring the enum *values*, since Pascal has no transitive exports).

Both halves matter equally: the server side (`TRALRESTDWModule` + `TRALRESTDWServerEvents`) and the client side (`TRALRESTDWClientEvents`). A change that only serves one of them is half a change.

It ships **two packages per compiler**. `RALRESTDW` is the events half and depends only on PascalRAL; `RALRESTDWDB` adds `TRALRESTDWClientSQL` and depends on a RAL database link (`RALDBFireDACLink` on Delphi, `raldbsqldblink` on Lazarus) - split on purpose, so an events-only user does not drag FireDAC in. There is also `ferramentas/conversor`, which rewrites a RDW project's `uses` and form class names: `uConversor.pas` holds every rule, and `rdw2ral.dpr` (console) and `gui/rdw2ralgui.dpr` (window) are two shells over it - **change the rule in the unit, never in one of the shells**, or the two drift apart. The window is the path a migrating user is meant to take; the console is for scripting.

It is an IDE component package, not an application: no `main`, **no test suite and no CI** (`.github/` holds only `FUNDING.yml`). Ten units in `src/`, demos under `exemplo/`.

**Reference checkouts, all sibling directories, all read-only — never edit them:**
- `../PascalRAL` — the RAL we build against (branch `dev`). Has its own `CLAUDE.md`; read it for `StringRAL`/`IntegerRAL`, `{$IFDEF FPC}@{$ENDIF}` on method pointers, `FixRoute`, `TRALParams`, typed params, `TRALModuleRoutes`, and the compiler recipes.
- `../RDW_Phoenix` — REST Dataware 2.1 (`OpenSourceCommunityBrasil/REST-DataWare`). The authority on what a member should be called and do. `CORE/Source/Basic/uRESTDW{Params,ServerEvents}.pas` and `CORE/Source/Consts/uRESTDWConsts.pas` carry almost all of it.
- `../RDW` — an older RDW checkout, useful only for what the `RDW143` directive selects.

## Build / verify

There is nothing to run as a test. Verification is: compile the package, compile the demos, then run the demos against each other.

Install order — `RALRESTDW` requires `PascalRALDsgn`, which requires `PascalRAL` + `designide`:

```powershell
msbuild ..\PascalRAL\pkg\Delphi\PascalRAL.dproj     /t:Build /p:Config=Release /p:Platform=Win32
msbuild ..\PascalRAL\pkg\Delphi\PascalRALDsgn.dproj /t:Build /p:Config=Release /p:Platform=Win32
msbuild pkg\delphi\RALRESTDW.dproj                  /t:Build /p:Config=Release /p:Platform=Win32

lazbuild --build-ide= pkg\lazarus\RALRESTDW.lpk
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

Expected noise, all pre-existing: `W1057` implicit string casts by the hundred (PascalRAL's own), one `W1055` on `TRALRESTDWParams` for the `published` block on a plain `TObject`. Anything else is yours.

**Compiling against the sources is not the whole check.** The `../PascalRAL` tree moves daily and the `PascalRAL.bpl` a user has installed can be weeks behind, so a brand-new RAL function compiles here and then refuses to install on their machine. That already happened once: `RALTools.RALSameName` landed 2026-09-10 and the installed package was from 2026-09-01. Build the package itself against the **installed** `.dcp` as well, which is the shape an install actually takes:

```powershell
$pub = "C:SERSPUBLICDOCUMENTSmbarcaderoStudio.0"   # onde ficam Bpl e Dcp
& "$bdsindcc32.exe" --no-config -B -Q -NS"..." ``
  -U"$bdsibwin32elease;$pubDcp;<repo>src" -I"<repo>src" ``
  -LU"rtl;PascalRALDsgn" -N0"<out>dcu" -LE"<out>" -LN"<out>" RALRESTDW.dpk
```

It needs `pkg/delphi/RALRESTDW.res`, which the IDE generates and the repo does not track - `brcc32` over a one-line `.rc` produces a usable one. Prefer the oldest API that does the job: this package should install on a PascalRAL that is a few weeks old.

**Compile with range checking on at least once.** `dcc32 --no-config` leaves `$R` off, the IDE turns it on for every Debug build, and the difference is not academic: `TRALStringStream` ends every write in `WriteBytes`, which does `Write(ABytes[0], Length(ABytes))` - indexing `[0]` of an empty array. Harmless with the check off, `ERangeError` with it on, and it fires on something as ordinary as a param declared with no `DefaultValue`. Nothing in this repo may hand empty content to those constructors; `StoreText`/`StoreStream` build an empty stream instead. Add `'-$R+'` to the dcc32 line (quoted, or PowerShell eats `$R` as a variable) and run the demos again.

### End-to-end

`exemplo/delphi/servidor` + `exemplo/delphi/cliente` exercise every feature. For an automated pass, a console harness that drives `TRALRESTDWClientEvents` against the running server covers discovery, typed params, datasets, per-event auth and the failure paths in one run — that is how the current behaviour was validated (19 checks, all green).

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

### `RDW143`

`src/RALRESTDW.inc` is the only conditional. Undefined (default) gives the RDW 2.x handler shape `(var AParams; const AResult: TStringList)`; `{$DEFINE RDW143}` gives the 1.4.3 shape `(var AParams; var AResult: StringRAL)`. `RALRESTDWEvents.pas` is the only unit that branches on it. Flipping it changes a published type: every wired DFM/LFM breaks and the package must be rebuilt.

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

## Traps

- **A lone body param travels without its name.** PascalRAL's `EncodeBody` skips multipart when there is exactly one body param and sends the raw value; the name arrives as `ral_body`. This bit both directions — `getevents` sends only `servereventname` when `AccessTag` is empty, and a handler returning just text answers with only `cUndefined`. Both sides now read in two steps (by name, then `Body`). Its own `CLAUDE.md` says not to "fix" this in RAL, so any new param that can travel alone needs the same two-step read.
- **PascalRAL faults under `$R+` on any query with a parameter.** `RALDBSQLCache.GetQueryParams` (`src/database/RALDBSQLCache.pas`, line 308) does `vParam.Size := GetInt64Prop(vColetItem, 'Size')` - reading an `Integer` property as `Int64`. Range checking turns the truncation into `ERangeError`, and the IDE turns range checking on for every Debug build. Confirmed by map lookup, with a param whose `Size` is 0 and `DataType` is `ftInteger`; setting `Size` by hand does not help, because the bad read happens inside RAL. **There is no client-side workaround** - it has to be fixed there (`GetOrdProp`). The events half is unaffected. Until then the DB demos need range checking off.
- **The DB calls are async in RAL and synchronous here.** `TRALDBConnection` posts `Open`/`ExecSQL`/`ApplyUpdates` with a callback and `ebMultiThread`, so they return before the answer exists. `TRALRESTDWClientSQL.WaitResponse` pumps `CheckSynchronize` until the callback lands, because RDW's are synchronous and ported code reads `RecordCount` on the next line. It re-enters: the callback calls `SetActive` again, and `FWaiting` is what keeps that from waiting on itself. `ThreadRequest` opts back out.
- **An error raised inside the callback escapes the caller's `try..except`.** That is why `InternalError` only *stores* the message and `WaitResponse` raises it - in the context of whoever called `Open`.
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
