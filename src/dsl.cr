# Compile-time type-safe schema DSL on top of ata-validator.
#
#   Ata.object User do
#     string :name, min: 3
#     int :age, gt: 0
#   end
#
#   User.valid?(%({"name": "Mert", "age": 28}))   # => true
#   u = User.from_json(%({"name": "Mert", "age": 28}))
#   u.name                                         # => "Mert" (typed getter)
#
# `Ata.object` is a macro: it reads the block's AST at compile time and
# generates a real struct exposing class methods `schema_json`, `validate`,
# `valid?`, `from_json` plus a typed getter for every field, so `body.title`
# works at compile time. The block itself is never run at runtime (it is
# parsed, not executed).
#
# Crystal forbids struct definitions as the right-hand side of an assignment
# (`X = macro ... end` => "can't define struct inside def"), and NamedTuples
# don't support dot access, so the schema name is passed as the first
# argument and the generated type is a struct: `Ata.object User do ... end`.

require "json"
require "./validator"

module Ata
  module Schemas
  end

  # Define a typed schema.
  #
  #   Ata.object Task do
  #     string :title, min: 1
  #     int :priority, gt: 0, optional: true
  #   end
  macro object(struct_name, &block)
    {% schema_parts = [] of String %}
    {% getter_parts = [] of String %}
    {% ctor_parts = [] of String %}
    {% opt_parts = [] of String %}
    {% init_parts = [] of String %}
    {% required_parts = [] of String %}

    {% exprs = block.body.is_a?(Expressions) ? block.body.expressions : [block.body] %}

    {% for expr in exprs %}
      {% if expr.is_a?(Call) %}
        {% kind = expr.name.id.stringify %}
        {% if ["string", "int", "float", "bool", "any", "array", "object"].includes?(kind) %}
          {% name = expr.args[0] %}
          {% name_str = name.id.stringify %}

          {% optional = false %}
          {% of_value = nil %}
          {% of_is_symbol = false %}
          {% if expr.named_args %}
            {% for na in expr.named_args %}
              {% if na.name.id.stringify == "optional" %}
                {% optional = true %}
              {% elsif na.name.id.stringify == "of" %}
                {% of_value = na.value %}
                {% of_is_symbol = na.value.is_a?(SymbolLiteral) %}
              {% end %}
            {% end %}
          {% end %}

          {% if !optional %}
            {% required_parts << "\"" + name_str + "\"" %}
          {% end %}

          {% type_map = {"string" => "string", "int" => "integer", "float" => "number", "bool" => "boolean"} %}
          {% item_type_map = {"string" => "string", "int" => "integer", "float" => "number", "bool" => "boolean"} %}
          {% item_cast_map = {"string" => "as_s", "int" => "as_i", "float" => "as_f", "bool" => "as_bool"} %}
          {% prim_type_map = {"string" => "String", "int" => "Int32", "float" => "Float64", "bool" => "Bool", "any" => "JSON::Any"} %}

          # ── schema fragment ──────────────────────────────
          {% sp = "    j.field \"" + name_str + "\" do\n" %}
          {% unless kind == "object" %}
            {% sp = sp + "      j.object do\n" %}
          {% end %}
          {% if type_map.has_key?(kind) %}
            {% sp = sp + "        j.field \"type\", \"" + type_map[kind] + "\"\n" %}
          {% end %}

          {% if expr.named_args %}
            {% for na in expr.named_args %}
              {% key = "" %}
              {% if na.name.id.stringify == "min" %}
                {% key = "minLength" %}
              {% elsif na.name.id.stringify == "max" %}
                {% key = "maxLength" %}
              {% elsif na.name.id.stringify == "pattern" %}
                {% key = "pattern" %}
              {% elsif na.name.id.stringify == "format" %}
                {% key = "format" %}
              {% elsif na.name.id.stringify == "values" %}
                {% key = "enum" %}
              {% elsif na.name.id.stringify == "gt" %}
                {% key = "exclusiveMinimum" %}
              {% elsif na.name.id.stringify == "lt" %}
                {% key = "exclusiveMaximum" %}
              {% elsif na.name.id.stringify == "gte" %}
                {% key = "minimum" %}
              {% elsif na.name.id.stringify == "lte" %}
                {% key = "maximum" %}
              {% elsif na.name.id.stringify == "min_items" %}
                {% key = "minItems" %}
              {% elsif na.name.id.stringify == "max_items" %}
                {% key = "maxItems" %}
              {% end %}
              {% if key != "" %}
                {% sp = sp + "        j.field \"" + key + "\", #{na.value}\n" %}
              {% end %}
            {% end %}
          {% end %}

          {% if kind == "array" %}
            {% sp = sp + "        j.field \"items\" do\n" %}
            {% if of_value && of_is_symbol %}
              {% if item_type_map.has_key?(of_value.id.stringify) %}
                {% sp = sp + "          j.object do\n" %}
                {% sp = sp + "            j.field \"type\", \"" + item_type_map[of_value.id.stringify] + "\"\n" %}
                {% sp = sp + "          end\n" %}
              {% else %}
                {% sp = sp + "          j.raw \"{}\"\n" %}
              {% end %}
            {% elsif of_value %}
              {% sp = sp + "          j.raw " + of_value.stringify + ".schema_json\n" %}
            {% else %}
              {% sp = sp + "          j.raw \"{}\"\n" %}
            {% end %}
            {% sp = sp + "        end\n" %}
          {% elsif kind == "object" %}
            {% if of_value && !of_is_symbol %}
              {% sp = sp + "        j.raw " + of_value.stringify + ".schema_json\n" %}
            {% end %}
          {% end %}

          {% unless kind == "object" %}
            {% sp = sp + "      end\n" %}
          {% end %}
          {% sp = sp + "    end\n" %}
          {% schema_parts << sp %}

          # ── field type ───────────────────────────────────
          {% if kind == "string" %}
            {% type = "String" %}
          {% elsif kind == "int" %}
            {% type = "Int32" %}
          {% elsif kind == "float" %}
            {% type = "Float64" %}
          {% elsif kind == "bool" %}
            {% type = "Bool" %}
          {% elsif kind == "any" %}
            {% type = "JSON::Any" %}
          {% elsif kind == "array" %}
            {% if of_value && of_is_symbol && prim_type_map.has_key?(of_value.id.stringify) %}
              {% type = "Array(" + prim_type_map[of_value.id.stringify] + ")" %}
            {% elsif of_value && !of_is_symbol %}
              {% type = "Array(" + of_value.stringify + ")" %}
            {% else %}
              {% type = "Array(JSON::Any)" %}
            {% end %}
          {% elsif kind == "object" %}
            {% if of_value && !of_is_symbol %}
              {% type = of_value.stringify %}
            {% else %}
              {% type = "JSON::Any" %}
            {% end %}
          {% end %}

          {% if optional %}
            {% type = type + "?" %}
          {% end %}

          {% getter_parts << "getter " + name_str + " : " + type %}
          {% if optional %}
            {% opt_parts << "@" + name_str + " : " + type + " = nil" %}
          {% else %}
            {% ctor_parts << "@" + name_str + " : " + type %}
          {% end %}

          # ── from_json expression ─────────────────────────
          {% base = "json[\"" + name_str + "\"]" %}

          {% if kind == "string" %}
            {% cast = ".as_s" %}
          {% elsif kind == "int" %}
            {% cast = ".as_i" %}
          {% elsif kind == "float" %}
            {% cast = ".as_f" %}
          {% elsif kind == "bool" %}
            {% cast = ".as_bool" %}
          {% else %}
            {% cast = "" %}
          {% end %}

          {% if kind == "object" %}
            {% if of_value && !of_is_symbol %}
              {% if optional %}
                {% from_expr = base + "?.try { |v| " + of_value.stringify + ".from_json(v.to_json) }" %}
              {% else %}
                {% from_expr = of_value.stringify + ".from_json(" + base + ".to_json)" %}
              {% end %}
            {% else %}
              {% from_expr = optional ? base + "?" : base %}
            {% end %}
          {% elsif kind == "array" %}
            {% if optional %}
              {% if of_value && of_is_symbol && item_cast_map.has_key?(of_value.id.stringify) %}
                {% from_expr = base + "?.try { |v| v.as_a.map(&." + item_cast_map[of_value.id.stringify] + ") }" %}
              {% elsif of_value && !of_is_symbol %}
                {% from_expr = base + "?.try { |v| v.as_a.map { |w| " + of_value.stringify + ".from_json(w.to_json) } }" %}
              {% else %}
                {% from_expr = base + "?.try(&.as_a)" %}
              {% end %}
            {% else %}
              {% if of_value && of_is_symbol && item_cast_map.has_key?(of_value.id.stringify) %}
                {% from_expr = base + ".as_a.map(&." + item_cast_map[of_value.id.stringify] + ")" %}
              {% elsif of_value && !of_is_symbol %}
                {% from_expr = base + ".as_a.map { |v| " + of_value.stringify + ".from_json(v.to_json) }" %}
              {% else %}
                {% from_expr = base + ".as_a" %}
              {% end %}
            {% end %}
          {% else %}
            {% if optional %}
              {% if kind == "any" %}
                {% from_expr = base + "?" %}
              {% else %}
                {% from_expr = base + "?.try(&" + cast + ")" %}
              {% end %}
            {% else %}
              {% from_expr = base + cast %}
            {% end %}
          {% end %}

          {% init_parts << name_str + ": " + from_expr %}
        {% end %}
      {% end %}
    {% end %}

    struct {{struct_name.id}}
      {{ getter_parts.join("\n").id }}

      @@schema_json : String?
      @@validator : AtaValidator::Validator?

      def initialize({% for ctor in ctor_parts %}{{ ctor.id }}{% unless ctor == ctor_parts.last %}, {% end %}{% end %}{% unless ctor_parts.empty? || opt_parts.empty? %}, {% end %}{% for opt in opt_parts %}{{ opt.id }}{% unless opt == opt_parts.last %}, {% end %}{% end %})
      end

      def self.schema_json : String
        @@schema_json ||= String.build do |io|
          JSON.build(io) do |j|
            j.object do
              j.field "type", "object"
              j.field "properties" do
                j.object do
                  {{ schema_parts.join("\n").id }}
                end
              end
              {% unless required_parts.empty? %}
              j.field "required", [{{ required_parts.join(", ").id }}]
              {% end %}
            end
          end
        end
      end

      def self.validator : AtaValidator::Validator
        @@validator ||= AtaValidator::Validator.new(schema_json)
      end

      def self.validate(json : String) : AtaValidator::ValidationResult
        validator.validate(json)
      end

      def self.valid?(json : String) : Bool
        validator.valid?(json)
      end

      def self.from_json(raw : String) : self
        json = JSON.parse(raw)
        new(
          {{ init_parts.join(",\n").id }}
        )
      end
    end
  end
end
