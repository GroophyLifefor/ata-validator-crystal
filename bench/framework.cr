# Minimal benchmark framework.
#
# A benchmark suite is a set of "scenarios" (the table rows). Each scenario
# registers JSON fixtures and a set of "workloads" (one per target/tool).
# Workloads are just procs that answer "is this JSON acceptable?" so new
# targets can be added without touching the runner.

module Bench
  record Fixture, name : String, json : String

  # One named operation: given a JSON string, returns whether it is acceptable
  # to this target. Exceptions raised inside a workload are treated by the
  # scenario's closures as "not acceptable" (see support.cr).
  class Workload
    getter name : String
    getter fn : Proc(String, Bool)

    def initialize(@name : String, @fn : Proc(String, Bool)); end

    def call(json : String) : Bool
      @fn.call(json)
    end
  end

  # One row of the benchmark table.
  class Scenario
    getter name : String
    getter description : String?
    getter iterations : Int32
    getter order : Int32
    getter fixtures : Array(Fixture)
    getter workloads : Array(Workload)

    def initialize(@name : String, @description : String?, @iterations : Int32, @order : Int32)
      @fixtures = [] of Fixture
      @workloads = [] of Workload
    end

    # Add a JSON fixture. The first fixture is used for timing/allocation.
    def fixture(name : String, json : String)
      @fixtures << Fixture.new(name, json)
    end

    # Add one workload (target) to this scenario.
    def target(name : String, &block : String -> Bool)
      @workloads << Workload.new(name, block)
    end

    def primary_json : String
      @fixtures.first.json
    end
  end

  @@scenarios = [] of Scenario

  # Register a scenario. This is the extension point: new scenarios are added
  # by dropping a file into bench/scenarios/ that calls this method (scenario
  # files are auto-required via `require "./scenarios/*"`).
  def self.register(name : String, description : String? = nil, iterations : Int32 = 100_000, order : Int32 = 1000, &block : Scenario ->)
    scenario = Scenario.new(name, description, iterations, order)
    yield scenario
    @@scenarios << scenario
  end

  def self.scenarios : Array(Scenario)
    @@scenarios
  end
end
