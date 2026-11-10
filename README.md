# socam

**Smack Open-Code Assistance Mechanism** — a native macOS assistance CLI and bridge for the Krypton + SmackUI stack.

`socam` gives you a fast, local-only command line for working with `.k` sources, the krypton compiler pipeline, and the broader SmackUI toolkit. No network calls, no AI back-ends; everything runs against the toolchain you have on disk.

## Usage

```
socam                       Show this help
socam -h | --help           Show this help
socam version               Print version
socam explain <file.k>      Compile <file.k> to IR and print statistics
socam grep <pat> <file>     Matches lines in <file> (prefix match, no regex)
socam list [<dir>]          Enumerate .k files under <dir> (default: .)
socam gen <name>            Emit a starter module <name>.k
```

Environment variables:

```
KRYPTON_ROOT          Repo root (used to locate the toolchain)
KCC_FRONTEND          Override ./compiler/macos_arm64/kcc-arm64 directly
```

## Build

```
KRYPTON_ROOT=/path/to/krypton  ./bootstrap/kcc_driver_macos_aarch64 bin/socam.k -o socam
```

## Layout

```
bin/socam.k          CLI dispatcher / argument parser
core/assistance.k    Bridge into the krypton compiler (read-IR, count FUNCs)
core/dispatch.k      Route names and shared context
tests/test_socam.k   Smoke tests (help, version, list, gen)
```

## Status

Actively scaffolding. Nothing here is stable, but everything listed above works
against a stock krypton build.
