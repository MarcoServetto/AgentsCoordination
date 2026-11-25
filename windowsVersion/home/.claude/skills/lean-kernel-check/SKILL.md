---
name: lean-kernel-check
description: Check a Lean 4 project with the two external kernels lean4lean and nanoda after it builds. Use whenever Lean work (a proof, a formalization, a Lean project such as C:\data\funnelling\lean) is about to be reported as done, committed or put in a PR.
---

# Checking a Lean project with external kernels

A Lean proof is done only when `lake build` succeeds and both external kernels accept the project:
- lean4lean, the Lean kernel written in Lean, checks the declarations of every module of the project against their imports.
- nanoda, an independent kernel written in Rust, checks the export of the whole environment, `Init` included, and accepts only the axioms `propext`, `Classical.choice` and `Quot.sound`.
A `sorry` or a `native_decide` uses an axiom outside that list (`sorryAx`, `Lean.trustCompiler`), so nanoda fails on it.

The tools are in `C:\data\tools`, built for the Lean version in the `lean-toolchain` of the project:
- `C:\data\tools\lean4export\.lake\build\bin\lean4export.exe` (lean4export at the tag equal to the Lean version, for example `v4.35.0`)
- `C:\data\tools\lean4lean\.lake\build\bin\lean4lean.exe` (lean4lean at the last commit whose `lean-toolchain` is that Lean version)
- `C:\data\tools\nanoda_lib\target\release\nanoda_bin.exe` (nanoda, independent of the Lean version)

lean4export and lean4lean read `.olean` files, which only the same Lean version reads.
When the `lean-toolchain` of the project names another version, check out the matching tag of lean4export and the matching commit of lean4lean, and run `lake build` in `lean4export` and `lake build lean4lean` in `lean4lean`.
Rust is installed through rustup: `%USERPROFILE%\.cargo\bin\cargo.exe build --release` in `nanoda_lib` builds nanoda.

## Steps

`<Root>` is the root module of the project (the `lean_lib` of `lakefile.toml`), `<s>` is the session scratchpad.
Run every command from the project folder.
The export goes through `cmd /c` redirection: a PowerShell pipe re-encodes the bytes of a native command, and the export holds non-ASCII names.

1. `& "$env:USERPROFILE\.elan\bin\lake.exe" build`
2. `cmd /c "%USERPROFILE%\.elan\bin\lake.exe env C:\data\tools\lean4lean\.lake\build\bin\lean4lean.exe <Root> 2>&1"`
   Success ends with `checked <n> declarations` and exit code 0.
   `--fresh` takes only a module with no submodules, so it does not apply to `<Root>`.
3. `cmd /c "%USERPROFILE%\.elan\bin\lake.exe env C:\data\tools\lean4export\.lake\build\bin\lean4export.exe <Root> > <s>\export.ndjson"`
4. Write `<s>\nanoda.json`:
   ```json
   {
     "export_file_path": "<s>\\export.ndjson",
     "use_stdin": false,
     "num_threads": 8,
     "permitted_axioms": ["propext", "Classical.choice", "Quot.sound"],
     "unpermitted_axiom_hard_error": false,
     "nat_extension": true,
     "string_extension": true,
     "pp_to_stdout": true,
     "print_success_message": true
   }
   ```
5. `cmd /c "C:\data\tools\nanoda_lib\target\release\nanoda_bin.exe <s>\nanoda.json 2>&1"`
   Success prints the three axioms, then `Checked <n> declarations with no errors`, and exits with code 0.
   `skipping exported but unpermitted axioms ["sorryAx"]` is expected: `Init` declares `sorryAx`, and nanoda fails on any declaration that uses a skipped axiom.
6. Delete `<s>\export.ndjson` (hundreds of MB).

The report of the Lean work gives the two declaration counts and the result of each kernel.
