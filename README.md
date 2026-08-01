# ata-validator-crystal

Crystal bindings for [ata-validator](https://github.com/ata-core/ata-validator) — a high-performance C++20 JSON Schema validator.

The C++ core uses simdjson and the RE2 regex engine; this shard only wraps its pure C API (`ata_c.h`). Struct layouts and function signatures match `ata_c.h` exactly.

## Install

Add to `shard.yml`:

```yaml
dependencies:
  ata-validator-crystal:
    github: groophylifefor/ata-validator-crystal
    version: ~> 0.1.0
```

```bash
shards install
```

## Native library

Two parts are required:

- **`ata.lib`** (or `libata.a`) — at link time, passed to `crystal build` via `/LIBPATH` (Windows/MSVC) or `-L` (Unix)
- **`ata.dll`** (or `libata.so`) — at runtime, next to the executable, on `PATH`, or pointed to by `ATA_VALIDATOR_LIB`

To build the library into `libata/` (the ata-validator source must be a sibling directory):

```bash
crystal run scripts/build_native.cr
```

This script compiles the shared library in `ata-validator` with CMake and copies `libata/ata.dll` + `libata/ata.lib` into the package root. (Default source path is `../../ata-validator`; override with the `ATA_VALIDATOR_SRC` env var.)

## Build

Windows (MSVC linker):

```bash
crystal build src/main.cr --link-flags "/LIBPATH:ata-validator-crystal/libata"
```

Linux/macOS:

```bash
crystal build src/main.cr --link-flags "-Lata-validator-crystal/libata -lata"
```

## Usage

```crystal
require "ata-validator-crystal"

schema = <<-JSON
{
  "type": "object",
  "properties": {
    "name": {"type": "string", "minLength": 1},
    "age":  {"type": "integer", "minimum": 0}
  },
  "required": ["name"]
}
JSON

puts "ata v#{AtaValidator.version}"

# Reuse a compiled schema
validator = AtaValidator::Validator.new(schema)

result = validator.validate(%({"name": "Mert", "age": 28}))
puts result.valid                          # => true

result = validator.validate(%({"age": -1}))
puts result.valid                          # => false
result.errors.each do |e|
  puts "#{e.path}: #{e.message}"           # => /age: value -1.000000 < minimum 0.000000
end

validator.valid?(%({"name": "Mert"}))      # => true (quick boolean check)
validator.close

# One-shot (compiles the schema on every call)
AtaValidator.validate(schema, %({"name": "Mert"})).valid
```

## API

- `AtaValidator.version : String`
- `AtaValidator::Validator.new(schema_json)` — compiles the schema once
  - `validate(json) : ValidationResult` (`valid` + `errors`)
  - `valid?(json) : Bool`
  - `close` / `finalize` — frees the compiled schema
- `AtaValidator.validate(schema_json, json) : ValidationResult` — one-shot
- Error types: `CompileError` (invalid schema), `ValidationError` (`path`, `message`)

## Test

```bash
crystal run scripts/build_native.cr
crystal spec --link-flags "/LIBPATH:libata"
```

## Benchmarks

`bench/` compares `ata-validator-crystal` against `JSON::Serializable` and `Athena::Validator` on five scenarios: parse valid JSON, invalid JSON, nested objects, 100k bulk validation and per-operation allocation.

### Results (2026-08-01, Windows 11 / MSVC, Crystal 1.15.0, `--release --no-debug`)

Higher is better for throughput, lower is better for allocation.

| Scenario | Metric | ata-validator-crystal | JSON::Serializable | Athena::Validator | × vs JSON::Serializable | × vs Athena::Validator |
|---|---|---|---|---|---|---|
| Parse valid JSON | ops/s | **750 968** | 449 970 | 299 640 | **1.67×** | **2.51×** |
| Parse valid JSON | bytes/op | **32** | 816 | 1 232 | **25.5×** | **38.5×** |
| Invalid JSON (malformed) | ops/s | **641 287** | 1 138 | 1 090 | **563.5×** | **588.3×** |
| Invalid JSON (malformed) | bytes/op | **112** | 5 504 | 5 504 | **49.1×** | **49.1×** |
| Nested object | ops/s | **338 270** | 304 255 | 190 074 | **1.11×** | **1.78×** |
| Nested object | bytes/op | **32** | 1 025 | 1 632 | **32.0×** | **51.0×** |
| 100.000 validation | ops/s | **844 921** | 407 730 | 274 917 | **2.07×** | **3.07×** |
| 100.000 validation | bytes/op | **32** | 816 | 1 232 | **25.5×** | **38.5×** |
| Allocation | bytes/op | **32** | 816 | 1 232 | **25.5×** | **38.5×** |

> **Reading the ratios:** for `ops/s` rows, `N×` = ata-validator-crystal is N× faster; for `bytes/op` rows, `N×` = ata-validator-crystal allocates N× less memory.

> **Note on "Invalid JSON":** `JSON::Serializable` and `Athena::Validator` raise a `JSON::ParseException` on malformed JSON, so each iteration pays exception-handling cost (hence the ~1 000 ops/s and 5.5 kB/op). `ata-validator-crystal` returns `valid=false` with a structured error list instead of throwing, which is why it stays fast.

These numbers are machine- and schema-specific — rerun locally with `crystal build bench/bench.cr --release --no-debug` to reproduce.

```bash
# build with the shared fixtures (requires the dev dependency: shards install)
crystal build bench/bench.cr -o bin/bench.exe --release --no-debug --link-flags "/LIBPATH:libata"

# run everything (100k / 20k iterations per scenario)
$env:PATH = "$PWD\libata;$env:PATH"
.\bin\bench.exe

# run a subset, or override iterations
.\bin\bench.exe nested
.\bin\bench.exe 10000
```

Each scenario prints:

- **correctness** — whether each target accepts/rejects each fixture
- **throughput** — total ms and ops/s over N iterations
- **allocation** — heap bytes per operation (`GC.stats` delta)

### Adding a scenario

Drop a new file into `bench/scenarios/` — it is auto-required. Register a row with `Bench.register`:

```crystal
require "../framework"

Bench.register("My scenario", description: "...", order: 6) do |s|
  s.fixture("valid", %({"name": "Mert", "age": 28}))
  s.fixture("invalid", %({"age": -1}))

  s.target("my-tool") { |json| my_tool_valid?(json) }
end
```

Reuse the shared types (`Person`, `PersonWithAddress`, `Bench::SCHEMA_*`, `Bench.person_workloads`) from `bench/support.cr`, or define your own. The first fixture is used for the throughput/allocation runs.

## License

MIT. The C++ core comes from [ata-validator](https://github.com/ata-core/ata-validator), MIT licensed (original copyright preserved in `LICENSE`).
