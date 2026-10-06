# ML-DSA in Haskell and Clash

This project implements parts of **ML-DSA (FIPS 204)** in Haskell and explores a synthesizable hardware implementation of the 256-point Number Theoretic Transform (NTT) using **Clash**.

The repository contains:

- a software 256-point NTT and inverse NTT in Haskell;
- ML-DSA key-generation and polynomial-support modules;
- a controller-driven, two-PE NTT accelerator in Clash;
- pipelined Montgomery modular multiplication;
- conflict-free banked coefficient memory;
- two synchronous twiddle-factor read lanes;
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
- Two parallel NTT processing elements
- Iterative eight-stage, 256-point NTT controller
- Four-bank, eight-block coefficient memory
- Two synchronous twiddle-factor ROM read lanes
- Load, issue, drain, unload, and done control phases
- Hardware-to-software NTT comparison tests
- Nix development environment
- Clash/Yosys synthesis, benchmark, and STA scripts

### In progress

- Remaining ML-DSA signing and verification operations
- Hardware inverse NTT support
- Exact latency assertions for the complete controller
- Streaming input/output to replace the wide `Vec 256` top-level interface
- FPGA BRAM/ROM inference and device-specific timing optimization
- ASIC SRAM-macro integration and post-layout evaluation
- Further optimization under tighter clock constraints

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
| `Component.NTTCore` | Modular arithmetic, pipelined PE, and two-PE array |
| `Component.NTTCoeffMem` | Conflict-free coefficient memory with eight synchronous RAM blocks |
| `Component.NTTCoeffController` | Coefficient addresses, twiddle addresses, PE operand routing, and writeback control |
| `Component.NTTTwiddleMem` | Two synchronous twiddle-factor ROM read lanes |
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
2 butterflies issued per cycle
64 issue cycles per stage
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

The current design is an iterative, memory-backed NTT accelerator with two parallel processing elements:

```text
Controller
  |-- coefficient addresses --> 8 coefficient RAM blocks
  |-- twiddle addresses -----> 2 synchronous twiddle ROM lanes
  |-- aligned metadata ------> writeback control

Coefficient RAM outputs + twiddle ROM outputs
  -> PE-input register
  -> two ten-stage pipelined PEs
  -> four coefficient results
  -> conflict-free memory writeback
```

Each PE computes one radix-2 butterfly. The two-PE array therefore accepts two butterflies per cycle and produces two results per cycle after the pipeline fills.

### Controller phases

`Component.NTT` uses the following phases:

| Phase | Purpose |
|---|---|
| `Idle` | Wait for `start` |
| `Load` | Load eight coefficients per cycle into coefficient memory |
| `Issue` | Issue two butterflies per cycle |
| `Drain` | Wait for the final pipelined result of a stage |
| `UnloadIssue` | Read eight final coefficients per cycle |
| `UnloadDrain` | Capture the final synchronous-memory output and assert completion |

The transform requires 64 issue cycles per stage. Including input loading, eight pipeline drains, and output unloading, the current complete operation takes approximately 673 cycles. The exact interface-visible latency should be checked by simulation whenever pipeline depth or controller sequencing changes.

### Coefficient memory

The coefficient store follows the paper-inspired conflict-free organization:

```text
4 banks
2 RAM blocks per bank
8 RAM blocks in total
48 rows per RAM block
384 coefficient locations = 1.5N
```

The 32 live logical rows rotate through the 48 physical rows using base offsets:

```text
0 -> 32 -> 16 -> 0
```

This replaces a two-full-polynomial ping-pong arrangement requiring `2N = 512` coefficient locations.

### Twiddle memory and timing isolation

Earlier versions selected twiddle factors combinationally inside the coefficient controller. That created a path through stage decoding, a large twiddle multiplexer, and the first multiplication stage.

The current version uses two synchronous twiddle ROM read lanes and a PE-input register. Coefficients, twiddles, and metadata are aligned after the one-cycle memory read:

```text
cycle n:     issue coefficient and twiddle addresses
cycle n+1:   receive memory outputs and aligned read control
cycle n+2:   register complete PE inputs
cycle n+12:  receive PE results with aligned write metadata
```

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

The Boolean input is `start`. The Boolean output is a one-cycle `done` indication, and the vector output contains the completed 256-point transform.

## Synthesis and timing results

The current Nangate45 standard-cell benchmark reports:

| Metric | Previous banked 2-PE design | Current design |
|---|---:|---:|
| Area | 209,573.420 um^2 | 212,708.762 um^2 |
| Critical path | 1.86 ns | 1.30 ns |
| Worst slack at a 5 ns constraint | 3.10 ns | 3.66 ns |
| WNS | 0.000 ns | 0.000 ns |
| TNS | 0.000 ns | 0.000 ns |

The synchronous twiddle memory and PE-input register reduced the reported critical path by approximately 30.1%, while area increased by approximately 1.5%.

The raw reciprocal of the reported 1.30 ns data-path delay is approximately 769 MHz. This is not a sign-off frequency: the current SDC constrains the design to 5 ns (200 MHz), and the report is pre-layout with an ideal clock. Setup time, placement, routing, clock-tree delay, process variation, and memory implementation must be included before claiming a final maximum frequency.

The Nangate45 flow does not contain the final FPGA BRAMs or ASIC SRAM macros. When memories are mapped into standard-cell registers and multiplexers, the reported area is not representative of a macro-based memory implementation.

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
2. Clash HDL generation;
3. Yosys synthesis;
4. OpenSTA static timing analysis.

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
- public-key construction and encoding;
- private-key construction and encoding;
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
- The synchronous twiddle table is duplicated to provide two simultaneous reads.
- The current standard-cell results are pre-layout and do not include clock-tree or routing effects.
- FPGA resource use and frequency must be measured with the target vendor tools.
- ASIC memory area and timing must be measured using the intended SRAM/ROM macros.

## Architecture summary

Compared with the earlier fully combinational implementation, the current design:

- reuses two pipelined butterfly PEs across all eight NTT stages;
- issues two butterfly operations per cycle;
- stores coefficients in a conflict-free `1.5N` memory organization;
- reads two twiddle factors synchronously per cycle;
- aligns coefficient data, twiddle data, and write metadata through explicit pipeline delays;
- provides `start` and `done` control;
- reduces the critical path while avoiding full combinational expansion of all 1024 butterfly operations.

  


  


