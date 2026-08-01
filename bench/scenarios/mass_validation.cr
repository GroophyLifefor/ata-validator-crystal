require "../support"

Bench.register(
  "100.000 validation",
  description: "Bulk throughput over 100k iterations on a valid document.",
  iterations: 100_000,
  order: 4,
) do |s|
  s.fixture("valid", %({"name": "Mert", "age": 28}))

  ata = AtaValidator::Validator.new(Bench::SCHEMA_PERSON)
  Bench.person_workloads(Person, ata).each do |name, fn|
    s.target(name) { |json| fn.call(json) }
  end
end
