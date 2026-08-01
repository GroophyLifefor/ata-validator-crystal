require "../support"

Bench.register(
  "Invalid JSON",
  description: "Malformed and semantically invalid documents.",
  order: 2,
) do |s|
  s.fixture("malformed", %q({"name": "Mert",))
  s.fixture("semantic", %({"age": -1}))

  ata = AtaValidator::Validator.new(Bench::SCHEMA_PERSON)
  Bench.person_workloads(Person, ata).each do |name, fn|
    s.target(name) { |json| fn.call(json) }
  end
end
