require "./native"

module AtaValidator
  struct ValidationError
    getter path : String
    getter message : String

    def initialize(@path : String, @message : String); end
  end

  struct ValidationResult
    getter valid : Bool
    getter errors : Array(ValidationError)

    def initialize(@valid : Bool, @errors : Array(ValidationError)); end
  end

  # Manages a compiled schema. Compiles once, reuse for multiple documents.
  class Validator
    @schema : LibAta::AtaSchema

    def initialize(schema_json : String)
      @schema = AtaValidator::Native.compile(schema_json)
      raise CompileError.new("failed to compile schema (invalid JSON Schema)") if @schema.null?
    end

    def valid?(json : String) : Bool
      validate(json).valid
    end

    def validate(json : String) : ValidationResult
      result = AtaValidator::Native.validate(@schema, json)
      errors = Array(ValidationError).new(result.error_count.to_i) do |i|
        index = i.to_u64
        ValidationError.new(
          AtaValidator::Native.error_path(index),
          AtaValidator::Native.error_message(index)
        )
      end
      ValidationResult.new(result.valid, errors)
    end

    def close
      unless @schema.null?
        AtaValidator::Native.schema_free(@schema)
        @schema = Pointer(Void).null
      end
    end

    def finalize
      close
    end
  end

  # One-shot validation: compiles the schema on every call. Useful for small/one-off payloads.
  def self.validate(schema_json : String, json : String) : ValidationResult
    result = AtaValidator::Native.validate_oneshot(schema_json, json)
    errors = Array(ValidationError).new(result.error_count.to_i) do |i|
      index = i.to_u64
      ValidationError.new(
        AtaValidator::Native.error_path(index),
        AtaValidator::Native.error_message(index)
      )
    end
    ValidationResult.new(result.valid, errors)
  end

  def self.version : String
    AtaValidator::Native.version
  end
end
