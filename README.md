# ata-validator-crystal

Crystal bindings for [ata-validator](https://github.com/) — a high-performance C++20 JSON Schema validator.

The C++ core uses simdjson and the RE2 regex engine; this shard only wraps its pure C API (`ata_c.h`). Struct layouts and function signatures match `ata_c.h` exactly.

## Install

Add to `shard.yml`:

```yaml
dependencies:
  ata-validator-crystal:
    github: user/ata-validator-crystal
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

## License

MIT. The C++ core comes from [ata-validator](https://github.com/), MIT licensed (original copyright preserved in `LICENSE`).
