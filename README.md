# ML-DSA in Haskell and Clash

This project implements parts of **ML-DSA (FIPS 204)** in Haskell and explores a synthesizable hardware implementation of the 256-point Number Theoretic Transform (NTT) using **Clash**.

The repository contains:

- a software 256-point NTT and inverse NTT in Haskell;
- ML-DSA key-generation and polynomial-support modules;
- a controller-driven NTT accelerator with a configurable number of processing elements (PEs);
- pipelined Montgomery modular multiplication;
- conflict-free banked coefficient memory;
- one synchronous twiddle-factor read lane per PE;
- Hspec and QuickCheck tests comparing the hardware output with the software reference;
- Nix, Stack, Clash, Yosys, synthesis, benchmarking, and static-timing-analysis tooling.

## Project status

### Implemented

- Software forward NTT for 256 coefficients
- Software inverse NTT for 256 coefficients
- ML-DSA key-generation support
- Polynomial and auxiliary operations
- Modular addition and subtraction
- Montgomery reduction and multiplication
- Ten-stage pipelined NTT processing element
- Configurable parallel NTT processing elements (`PECount`; latest reported benchmark: 8 PEs)
- Iterative eight-stage, 256-point NTT controller
- Four-bank coefficient memory with `4 * PECount` synchronous RAM blocks
- `PECount` synchronous twiddle-factor ROM read lanes
- Load, issue, drain, unload, and done control phases
- Hardware-to-software NTT comparison tests
- Nix development environment
- Clash/Yosys synthesis, benchmark, and STA scripts
- Simulation-based NTT cycle counting with a software-reference output check

## Main modules

### Software implementation

| Module | Purpose |
|---|---|
| `MLDSA` | Main ML-DSA module |
| `MLDSA.KeyGen` | Key generation and key encoding support |
| `MLDSA.NTT` | Software forward and inverse NTT reference |
| `MLDSA.Polynomial` | Polynomial types and operations |
| `MLDSA.Auxiliary` | Supporting ML-DSA functions |

### Clash hardware implementation

| Module | Purpose |
|---|---|
| `Component.NTT` | Top-level interface, controller state machine, load/unload logic, and module integration |
| `Component.NTTCore` | Modular arithmetic, ten-stage pipelined PE, and generic PE array |
| `Component.NTTCoeffMem` | Conflict-free coefficient memory with `4 * PECount` synchronous RAM blocks |
| `Component.NTTCoeffController` | Coefficient addresses, twiddle addresses, PE operand routing, and writeback control |
| `Component.NTTTwiddleMem` | One synchronous twiddle-factor ROM read lane per PE |
| `Component.NTTConfig` | PE count and derived issue counts and memory dimensions |
| `Component.NTTConstants` | Montgomery-domain ML-DSA twiddle-factor table |
| `Component.NTTTH` | Template Haskell helpers for fixed pipeline delays |

## NTT parameters

The implementation uses the ML-DSA modulus:

```text
q = 8380417
```

The transform contains:

```text
256 coefficients
8 radix-2 stages
128 butterflies per stage
1024 butterfly operations in total
PECount butterflies issued per cycle
128 / PECount issue cycles per stage
```

The forward transform uses the following logical stage lengths:

```text
128, 64, 32, 16, 8, 4, 2, 1
```

The zeta table is consumed as follows:

| Stage length | Zeta indices |
|---:|---:|
| 128 | 1 |
| 64 | 2-3 |
| 32 | 4-7 |
| 16 | 8-15 |
| 8 | 16-31 |
| 4 | 32-63 |
| 2 | 64-127 |
| 1 | 128-255 |

`zetasMont[0]` is not used by the forward NTT.

## Montgomery representation

The Clash butterfly uses Montgomery multiplication with:

```text
R = 2^24
R mod q = 16382
-q^(-1) mod R = 8380415
R^2 mod q = 196580
```

The hardware representation is:

```text
Polynomial input coefficients: ordinary values modulo q
Twiddle factors stored in hardware: zeta * R mod q
NTT output coefficients: ordinary values modulo q
```

The butterfly computes:

```text
t    = MontgomeryReduce(zetaMont * b)
outA = a + t mod q
outB = a - t mod q
```

Because `zetaMont = zeta * R mod q`, Montgomery reduction returns the ordinary-domain product `zeta * b mod q`.

The hardware twiddle ROM is initialized from `Component.NTTConstants.zetasMont`. Code that builds an alternative hardware twiddle table must convert ordinary zeta values first:

```haskell
toMontgomeryInteger :: Integer -> Integer
toMontgomeryInteger x =
  ((x `mod` 8380417) * 16382) `mod` 8380417
```

## Current hardware architecture

The design is an iterative, memory-backed NTT accelerator. Its parallelism is
set in `src/Component/NTTConfig.hs`. The latest user-reported benchmark uses
the following configuration:

```haskell
type PECount = 8
```

The controller issues coefficient-memory addresses, twiddle-ROM addresses, and
writeback metadata. Synchronous memory outputs pass through a PE-input register
and then the ten-stage butterfly pipelines before returning to coefficient memory.
Each PE computes one radix-2 butterfly, producing two coefficient values.
After the pipeline fills, the array can produce `PECount` butterfly results
(`2 * PECount` coefficient values) per cycle during a stage's output stream.
The controller drains the pipeline between stages.

| Parameter | Formula | 2 PEs | 4 PEs | 8 PEs | 16 PEs |
|---|---|---:|---:|---:|---:|
| Issue cycles per stage | `128 / PECount` | 64 | 32 | 16 | 8 |
| Total butterfly issue cycles | `1024 / PECount` | 512 | 256 | 128 | 64 |
| Coefficient RAM blocks | `4 * PECount` | 8 | 16 | 32 | 64 |
| Depth per RAM block | `96 / PECount` | 48 | 24 | 12 | 6 |
| Logical load/unload rows | `64 / PECount` | 32 | 16 | 8 | 4 |
| Twiddle read lanes | `PECount` | 2 | 4 | 8 | 16 |

These are configuration dimensions, not measured total latencies. Run functional
tests and cycle simulation after changing the PE count.

### Controller phases

`Component.NTT` uses the following phases:

| Phase | Purpose |
|---|---|
| `Idle` | Wait for `start` |
| `Load` | Load `4 * PECount` coefficients per cycle into coefficient memory |
| `Issue` | Issue `PECount` butterflies per cycle |
| `Drain` | Wait for the final pipelined result of a stage |
| `UnloadIssue` | Read `4 * PECount` final coefficients per cycle |
| `UnloadDrain` | Capture the final synchronous-memory output and assert completion |

The transform requires `128 / PECount` issue cycles per stage, with `PECount`
defined in `Component.NTTConfig`. The two-PE configuration requires 64 issue
cycles per stage. Complete operation latency also includes input loading,
eight pipeline drains, and output unloading. `bench NTT` measures the exact
interface-visible latency by simulation whenever it runs.

### Coefficient memory

The coefficient store uses four banks with `PECount` RAM blocks per bank.
Its total capacity remains:

```text
4 * PECount * (96 / PECount) = 384 coefficient locations = 1.5N
```

The `64 / PECount` live logical rows rotate through `96 / PECount` physical
rows. Base offsets follow `0`, `64 / PECount`, `32 / PECount`, then `0` again.
For two PEs these offsets are 0, 32, and 16; for 16 PEs they are 0, 4, and 2.
This arrangement uses fewer coefficient locations than two full polynomial
buffers (`2N = 512`). Physical implementation area still depends on the target
technology and memory mapping.

### Twiddle memory and timing isolation

Earlier versions selected twiddle factors combinationally inside the coefficient controller. That created a path through stage decoding, a large twiddle multiplexer, and the first multiplication stage.

The current version uses one synchronous twiddle ROM read lane per PE and a PE-input register. Coefficients, twiddles, and metadata are aligned after the one-cycle memory read:

| Cycle | Event |
|---|---|
| `n` | Issue coefficient and twiddle addresses |
| `n + 1` | Receive memory outputs and aligned read control |
| `n + 2` | Register complete PE inputs |
| `n + 12` | Receive PE results with aligned write metadata |

The PE-input register adds one cycle of latency per stage drain but does not reduce throughput.

## Top-level interface

`Component.NTT.topEntity` exposes:

```haskell
topEntity
  :: Clock System
  -> Reset System
  -> Enable System
  -> Signal System Bool
  -> Signal System (Vec 256 Coeff)
  -> ( Signal System Bool
     , Signal System (Vec 256 Coeff)
     )
```

The Boolean input is `start`. Pulse it for one enabled cycle while the controller
is idle; requests during an active transform are ignored. The Boolean output is
a one-cycle `done` indication when enable remains high, and the vector output
contains the completed 256-point transform. Hold enable high throughout the
benchmark measurement.

## Synthesis and timing results

### Architecture comparison

The following historical Nangate45 standard-cell results were recorded in the
original README. They are retained as reported; the 8-PE area and timing
match the latest reported benchmark above. Other configurations were not
remeasured in that invocation:

| Metric | Previous 2 PE design | 2 PE design | 4 PE design | 8 PE design |
|---|---:|---:|---:|---:|
| Area | 212,708.762 um^2 | 213215.226 um^2 | 2458191.464 um^2 | 310231.544 um^2 |
| Critical path | 1.30 ns | 1.28 ns | 1.34 ns | 1.36 ns |
| Start-to-done latency | Not recorded | Not recorded | 386 cycles | 242 cycles |
| Worst slack at a 5 ns constraint | 3.66 ns | 3.68 ns | 3.62 ns | 3.60 ns |
| WNS | 0.000 ns | 0.000 ns | 0.000 ns | 0.000 ns |
| TNS | 0.000 ns | 0.000 ns | 0.000 ns | 0.000 ns |

## Development environment

The recommended workflow uses Nix and Stack.

Enter the development shell from the repository root:

```bash
nix develop
```

The shell provides:

- GHC 9.6.6
- Stack
- Cabal
- Clash
- Yosys
- Python
- synthesis, benchmark, and STA helper commands

## Build

Inside `nix develop`:

```bash
stack build
```

## Testing

The main full-transform test module is:

```text
tests/Test/NTT256.hs
```

The tests cover:

- Montgomery multiplication against ordinary modular multiplication;
- Montgomery boundary cases;
- zero-polynomial behavior;
- full-transform agreement with `MLDSA.NTT.ntt`;
- coefficient outputs remaining in `[0, q)`;
- correct omission of zeta index zero;
- randomized reduced-input cases.

Coefficient-memory mapping tests are located in:

```text
tests/Test/NTTCoeffMem.hs
```

Ensure this module is imported and included in `tests/Main.hs`; compilation alone does not guarantee that its examples were executed.

Run all tests:

```bash
stack test
```

Run only Montgomery tests:

```bash
stack test --test-arguments="--match Montgomery"
```

Run only the full 256-point transform tests:

```bash
stack test --test-arguments="--match 'full 256-point'"
```

Run tests under the outer NTT description:

```bash
stack test --test-arguments="--match Component.NTT"
```

Hspec matches the text in `describe` and `it`, not the Haskell module name. A result such as:

```text
0 examples, 0 failures
```

means compilation succeeded, but the selected filter did not match any test description.

## Benchmarking

Run the complete NTT benchmark with:

```bash
bench NTT
```

The benchmark performs:

1. Haskell build;
2. NTT cycle simulation and a ramp-polynomial check against `MLDSA.NTT`;
3. Clash HDL generation;
4. Yosys synthesis;
5. OpenSTA static timing analysis.

For `NTT` (or `Component.NTT.topEntity`), the final metrics include `latency`
in clock cycles. This is `doneCycle - startCycle`: elapsed clock periods from
the single-cycle `start` pulse while idle to the first asserted `done`, with
enable held high. It includes input capture, loading, all eight stages and
their pipeline drains, and output unloading; reset and idle warm-up are excluded.
The counter exists only in the simulation executable, so synthesis area and
timing are unaffected. Other benchmark targets keep their existing metrics.

Run just the measurement, without synthesis or STA, inside `nix develop`:

```bash
stack run ntt-cycles
```

It prints `NTT_CYCLES=<count>` on success and fails on a missing `done` within
2048 cycles or a reference-output mismatch. The simulation runs even when HDL,
synthesis, and STA results are cached, so a previous measurement is never reused
after a PE-count or pipeline change.

The cycle-counting workflow requires `bench/NTTCycles.hs`, the `ntt-cycles`
executable stanza in `ml-dsa.cabal`, and its integration in `scripts/bench.py`.
These are the cycle-counting additions described below; an older checkout
without those additions only performs build, HDL generation, synthesis, and STA.

### Cycle-counting files

| File | Responsibility |
|---|---|
| `bench/NTTCycles.hs` | Simulate `Component.NTT.topEntity`, find the first `done`, and compare the ramp-polynomial output with `MLDSA.NTT.ntt` |
| `ml-dsa.cabal` | Define the `ntt-cycles` executable and its dependencies |
| `scripts/bench.py` | Run the measurement for NTT targets and display the `latency` metric |

The printed stage durations in seconds measure tool execution time. The
`latency` metric measures simulated hardware clock cycles; it is independent
of how quickly the host runs the simulation. The latest reported measurement is 242 cycles for 8 PEs; cycle counts for
other configurations must be measured separately.

### Troubleshooting

If the coefficient-memory configuration test rejects `16` while
`Component.NTTConfig` selects 16 PEs, update the whitelist in
`tests/Test/NTTCoeffMem.hs` from `[2, 4, 8]` to `[2, 4, 8, 16]`, then rerun
`stack test`. This aligns the configuration check with the selected PE count;
the transform and memory tests must still pass.

For `IndentationError: unexpected indent` in `scripts/bench.py`, keep
`cycles = None` inside `bench()`, aligned with the build call at four spaces.
The `if resolved_target ...` statement also starts at four spaces, and its body
starts at eight spaces. Use spaces consistently and check syntax before benchmarking:

```bash
python3 -m py_compile scripts/bench.py
```

Before comparing architectural changes, run the functional tests. A successful synthesis or timing report proves that the circuit was generated and analyzed; it does not prove that the NTT result is mathematically correct.

## Software reference

`MLDSA.NTT` contains the software reference:

```haskell
ntt
  :: Integer
  -> Data.Vector.Vector Integer
  -> Data.Vector.Vector Integer
  -> Data.Vector.Vector Integer
```

Its arguments are:

```text
modulus
ordinary-domain zeta table
ordinary-domain input polynomial
```

Hardware tests use Montgomery-domain zetas for the DUT. The software reference continues to receive ordinary-domain zetas.

## Key-generation support

The key-generation work includes functions and operations for:

- seed generation and expansion;
- matrix generation;
- uniform polynomial sampling;
- public-key polynomial construction;
- seed expansion and key-generation intermediate values;
- polynomial and NTT support used by key generation.

Relevant modules include:

```text
MLDSA/KeyGen.hs
MLDSA/Polynomial.hs
MLDSA/Auxiliary.hs
MLDSA/NTT.hs
```

## Current limitations

- Signing and verification are not yet complete.
- The hardware currently implements the forward NTT datapath; hardware inverse NTT support remains future work.
- The wide `Vec 256` input and output interface creates large top-level registers and routing.
- The design waits for the pipeline to drain between stages rather than overlapping adjacent stages.
- The synchronous twiddle table is replicated to provide one simultaneous read per PE.
- The current standard-cell results are pre-layout and do not include clock-tree or routing effects.
- FPGA resource use and frequency must be measured with the target vendor tools.
- ASIC memory area and timing must be measured using the intended SRAM/ROM macros.

## Architecture summary

Compared with the earlier fully combinational implementation, the current design:

- reuses `PECount` pipelined butterfly PEs across all eight NTT stages;
- issues `PECount` butterfly operations per issue cycle;
- stores coefficients in a conflict-free `1.5N` memory organization;
- reads `PECount` twiddle factors synchronously per issue cycle;
- aligns coefficient data, twiddle data, and write metadata through explicit pipeline delays;
- provides `start` and `done` control;
- reduces the critical path while avoiding full combinational expansion of all 1024 butterfly operations.

  


  


