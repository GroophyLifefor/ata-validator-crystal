require "../support"

Bench.register(
  "Parse valid JSON",
  description: "Validate/parse a well-formed document.",
  order: 1,
) do |s|
  s.fixture("valid", %({"name": "Mert", "age": 28}))
  s.fixture("invalid", %({"age": -1}))

  ata = AtaValidator::Validator.new(Bench::SCHEMA_PERSON)
  Bench.person_workloads(Person, ata).each do |name, fn|
    s.target(name) { |json| fn.call(json) }
  end
end
