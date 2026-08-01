# Shared Crystal types, JSON schemas and workload factories used by the
# benchmark scenarios. Scenarios may reuse these or define their own.

require "json"
require "athena-validator"
require "../src/ata-validator-crystal"
require "./framework"

# Used by the JSON::Serializable and Athena::Validator targets.
class Address
  include JSON::Serializable
  include AVD::Validatable

  @[Assert::NotBlank]
  property city : String

  @[Assert::Range(0..90000)]
  property zip : Int32
end

class Person
  include JSON::Serializable
  include AVD::Validatable

  @[Assert::NotBlank]
  property name : String

  @[Assert::Range(0..120)]
  property age : Int32
end

class PersonWithAddress
  include JSON::Serializable
  include AVD::Validatable

  @[Assert::NotBlank]
  property name : String

  @[Assert::Range(0..120)]
  property age : Int32

  @[Assert::Valid]
  property address : Address?
end

module Bench
  SCHEMA_PERSON = <<-JSON
  {
    "type": "object",
    "properties": {
      "name": {"type": "string", "minLength": 1},
      "age":  {"type": "integer", "minimum": 0, "maximum": 120}
    },
    "required": ["name"]
  }
  JSON

  SCHEMA_PERSON_ADDRESS = <<-JSON
  {
    "type": "object",
    "properties": {
      "name": {"type": "string", "minLength": 1},
      "age":  {"type": "integer", "minimum": 0, "maximum": 120},
      "address": {
        "type": "object",
        "properties": {
          "city": {"type": "string", "minLength": 1},
          "zip":  {"type": "integer", "minimum": 0, "maximum": 90000}
        },
        "required": ["city"]
      }
    },
    "required": ["name"]
  }
  JSON

  # Builds the standard three workloads for a JSON::Serializable-compatible
  # type: raw JSON validation (ata), parsing (JSON::Serializable) and
  # parse + constraint validation (Athena::Validator). Returns a Hash so
  # scenarios can pick and choose.
  def self.person_workloads(person_type : T.class, ata : AtaValidator::Validator) forall T
    avd = AVD.validator
    {
      "ata-validator-crystal" => ->(json : String) { ata.validate(json).valid },
      "JSON::Serializable"    => ->(json : String) { (person_type.from_json(json); true) rescue false },
      "Athena::Validator"     => ->(json : String) { (avd.validate(person_type.from_json(json)).size == 0) rescue false },
    }
  end
end
