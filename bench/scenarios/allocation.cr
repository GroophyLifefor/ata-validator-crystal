require "../support"

Bench.register(
  "Allocation",
  description: "Per-operation heap allocation (GC.stats total_bytes delta).",
  iterations: 20_000,
  order: 5,
) do |s|
  s.fixture("valid", %({"name": "Mert", "age": 28}))

  ata = AtaValidator::Validator.new(Bench::SCHEMA_PERSON)
  Bench.person_workloads(Person, ata).each do |name, fn|
    s.target(name) { |json| fn.call(json) }
  end
end
