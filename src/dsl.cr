# Type-safe schema DSL on top of ata-validator.
#
#   User = Ata.object do
#     string :name, min: 3
#     int :age, gt: 0
#   end
#
#   User.valid?(%({"name": "Mert", "age": 28}))   # => true
#
# The block runs in the builder's scope (`with ... yield`), so bare calls work
# inside the block; `do |b| b.string :name, min: 3 end` works too. Every field
# is required unless `optional: true` is passed. The emitted JSON Schema is
# available via `Schema#schema_json`.

require "json"
require "./validator"

module Ata
  # A compiled, reusable schema returned by `Ata.object`.
  class Schema
    getter schema_json : String

    def initialize(@schema_json : String)
      @validator = AtaValidator::Validator.new(@schema_json)
    end

    def valid?(json : String) : Bool
      @validator.valid?(json)
    end

    def validate(json : String) : AtaValidator::ValidationResult
      @validator.validate(json)
    end

    def to_s(io : IO)
      io << @schema_json
    end
  end

  # Collects property definitions and emits the final JSON Schema.
  class Builder
    @properties = [] of Tuple(String, String)
    @required = [] of String

    def string(name : Symbol, *, min : Int32? = nil, max : Int32? = nil,
               pattern : String? = nil, format : String? = nil,
               values : Array(String)? = nil, optional : Bool = false)
      add(name, optional) do |j|
        j.field "type", "string"
        j.field "minLength", min if min
        j.field "maxLength", max if max
        j.field "pattern", pattern if pattern
        j.field "format", format if format
        j.field "enum", values if values
      end
    end

    def int(name : Symbol, *, gt : Int32? = nil, lt : Int32? = nil,
            gte : Int32? = nil, lte : Int32? = nil, optional : Bool = false)
      add(name, optional) do |j|
        j.field "type", "integer"
        j.field "exclusiveMinimum", gt if gt
        j.field "exclusiveMaximum", lt if lt
        j.field "minimum", gte if gte
        j.field "maximum", lte if lte
      end
    end

    def float(name : Symbol, *, gt : Float64? = nil, lt : Float64? = nil,
              gte : Float64? = nil, lte : Float64? = nil, optional : Bool = false)
      add(name, optional) do |j|
        j.field "type", "number"
        j.field "exclusiveMinimum", gt if gt
        j.field "exclusiveMaximum", lt if lt
        j.field "minimum", gte if gte
        j.field "maximum", lte if lte
      end
    end

    def bool(name : Symbol, *, optional : Bool = false)
      add(name, optional) do |j|
        j.field "type", "boolean"
      end
    end

    # Untyped field: any JSON value is accepted.
    def any(name : Symbol, *, optional : Bool = false)
      add(name, optional) { |j| }
    end

    # Array of a primitive type (`of: :string`, `:int`, `:float`, `:bool`, `:any`).
    def array(name : Symbol, of : Symbol, *, min_items : Int32? = nil,
              max_items : Int32? = nil, optional : Bool = false)
      item_type = case of
                  when :string then "string"
                  when :int    then "integer"
                  when :float  then "number"
                  when :bool   then "boolean"
                  when :any    then nil
                  else              raise ArgumentError.new("unknown array item type: #{of}")
                  end
      add(name, optional) do |j|
        j.field "type", "array"
        j.field "minItems", min_items if min_items
        j.field "maxItems", max_items if max_items
        j.field "items" do
          if item_type
            j.object { j.field "type", item_type }
          else
            j.raw "{}"
          end
        end
      end
    end

    # Array whose items follow a nested schema.
    def array(name : Symbol, of : Schema, *, min_items : Int32? = nil,
              max_items : Int32? = nil, optional : Bool = false)
      add(name, optional) do |j|
        j.field "type", "array"
        j.field "minItems", min_items if min_items
        j.field "maxItems", max_items if max_items
        j.field "items" do
          j.raw of.schema_json
        end
      end
    end

    # Nested object field embedding another schema.
    def object(name : Symbol, of : Schema, *, optional : Bool = false)
      @properties << {name.to_s, of.schema_json}
      @required << name.to_s unless optional
    end

    def build : Schema
      full = String.build do |io|
        JSON.build(io) do |j|
          j.object do
            j.field "type", "object"
            j.field "properties" do
              j.object do
                @properties.each do |name, schema|
                  j.field(name) { j.raw schema }
                end
              end
            end
            j.field "required", @required unless @required.empty?
          end
        end
      end
      Schema.new(full)
    end

    private def add(name : Symbol, optional : Bool, & : JSON::Builder ->)
      schema = String.build do |io|
        JSON.build(io) do |j|
          j.object do
            yield j
          end
        end
      end
      @properties << {name.to_s, schema}
      @required << name.to_s unless optional
    end
  end

  # Define a reusable schema.
  #
  #   User = Ata.object do
  #     string :name, min: 3
  #     int :age, gt: 0
  #   end
  def self.object(&)
    builder = Builder.new
    with builder yield
    builder.build
  end
end
