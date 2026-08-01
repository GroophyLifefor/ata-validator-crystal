# Crystal bindings for the ata-validator C API.
#
# C functions are linked at compile time via @[Link("ata")], Crystal's
# standard FFI approach. The native library has two parts:
#   - ata.lib / libata.a   : import library (link time)
#   - ata.dll / libata.so  : shared library (runtime)
#
# Pass the library path to the linker at build time (e.g. on Windows):
#   crystal build ... --link-flags "/LIBPATH:ata-validator-crystal/libata"
#
# At runtime, make the DLL findable: copy it next to the executable, add it
# to PATH, or point ATA_VALIDATOR_LIB at its full path.
#
# Struct layouts match ata-validator/include/ata_c.h exactly.

module AtaValidator
  # Raised when a JSON Schema fails to compile.
  class CompileError < Exception; end
end

@[Link("ata")]
lib LibAta
  alias SizeT = LibC::SizeT
  alias AtaSchema = Void*

  struct AtaString
    data : UInt8*
    length : SizeT
  end

  struct AtaResult
    valid : Bool
    error_count : SizeT
  end

  struct AtaVersionComponents
    major : UInt32
    minor : UInt32
    revision : UInt32
  end

  fun ata_compile(schema_json : UInt8*, length : SizeT) : AtaSchema
  fun ata_schema_free(schema : AtaSchema)
  fun ata_validate(schema : AtaSchema, json : UInt8*, length : SizeT) : AtaResult
  fun ata_validate_oneshot(schema_json : UInt8*, schema_length : SizeT,
                           json : UInt8*, json_length : SizeT) : AtaResult
  fun ata_get_error_message(index : SizeT) : AtaString
  fun ata_get_error_path(index : SizeT) : AtaString
  fun ata_get_version : UInt8*
  fun ata_get_version_components : AtaVersionComponents
end

module AtaValidator
  module Native
    def self.compile(schema_json : String) : LibAta::AtaSchema
      LibAta.ata_compile(schema_json.to_unsafe, schema_json.bytesize.to_u64)
    end

    def self.schema_free(schema : LibAta::AtaSchema)
      LibAta.ata_schema_free(schema)
    end

    def self.validate(schema : LibAta::AtaSchema, json : String) : LibAta::AtaResult
      LibAta.ata_validate(schema, json.to_unsafe, json.bytesize.to_u64)
    end

    def self.validate_oneshot(schema_json : String, json : String) : LibAta::AtaResult
      LibAta.ata_validate_oneshot(schema_json.to_unsafe, schema_json.bytesize.to_u64,
                                  json.to_unsafe, json.bytesize.to_u64)
    end

    def self.error_message(index : UInt64) : String
      s = LibAta.ata_get_error_message(index)
      return "" if s.data.null?
      String.new(s.data, s.length.to_i32)
    end

    def self.error_path(index : UInt64) : String
      s = LibAta.ata_get_error_path(index)
      return "" if s.data.null?
      String.new(s.data, s.length.to_i32)
    end

    def self.version : String
      String.new(LibAta.ata_get_version)
    end
  end
end
