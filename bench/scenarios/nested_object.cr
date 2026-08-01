require "../support"

Bench.register(
  "Nested object",
  description: "Object containing a nested object (address).",
  order: 3,
) do |s|
  s.fixture("valid", %({"name": "Mert", "age": 28, "address": {"city": "Ankara", "zip": 6420}}))
  s.fixture("invalid", %({"name": "Mert", "age": 28, "address": {"zip": -1}}))

  ata = AtaValidator::Validator.new(Bench::SCHEMA_PERSON_ADDRESS)
  Bench.person_workloads(PersonWithAddress, ata).each do |name, fn|
    s.target(name) { |json| fn.call(json) }
  end
end
