require "./spec_helper"

User = Ata.object do
  string :name, min: 3, max: 10
  int :age, gt: 0, lte: 120
  string :email, format: "email", optional: true
  bool :active
end

Address = Ata.object do
  string :city, min: 1
  int :zip, gte: 0
end

Person = Ata.object do
  string :name, min: 3
  object :address, of: Address
end

Tags = Ata.object do
  string :name, min: 1
  array :tags, of: :string, min_items: 1
end

Any = Ata.object do
  string :name, min: 1
  any :payload, optional: true
end

describe Ata do
  describe ".object" do
    it "emits a JSON Schema that compiles and validates" do
      User.valid?(%({"name": "Mert", "age": 28, "active": true})).should be_true
      User.valid?(%({"name": "Mert", "age": 28, "active": true, "email": "m@x.com"})).should be_true
    end

    it "enforces min/max string length" do
      User.valid?(%({"name": "Me", "age": 28, "active": true})).should be_false
      User.valid?(%({"name": "Mert Mert Mert", "age": 28, "active": true})).should be_false
    end

    it "enforces exclusive minimum and inclusive maximum on ints" do
      User.valid?(%({"name": "Mert", "age": 0, "active": true})).should be_false
      User.valid?(%({"name": "Mert", "age": 121, "active": true})).should be_false
      User.valid?(%({"name": "Mert", "age": 120, "active": true})).should be_true
    end

    it "applies format to optional fields" do
      User.valid?(%({"name": "Mert", "age": 28, "active": true, "email": "nope"})).should be_false
    end

    it "treats fields as required by default" do
      User.valid?(%({"name": "Mert", "active": true})).should be_false
    end

    it "allows missing optional fields" do
      User.valid?(%({"name": "Mert", "age": 28, "active": true})).should be_true
    end
  end

  describe "nested schemas" do
    it "validates the nested object" do
      Person.valid?(%({"name": "Mert", "address": {"city": "Ankara", "zip": 6420}})).should be_true
      Person.valid?(%({"name": "Mert", "address": {"zip": -1}})).should be_false
      Person.valid?(%({"name": "Mert"})).should be_false
    end
  end

  describe "arrays" do
    it "validates primitive arrays" do
      Tags.valid?(%({"name": "x", "tags": ["a", "b"]})).should be_true
      Tags.valid?(%({"name": "x", "tags": []})).should be_false
      Tags.valid?(%({"name": "x", "tags": [1]})).should be_false
    end
  end

  describe "any field" do
    it "accepts any value" do
      Any.valid?(%({"name": "x", "payload": {"anything": [1, 2, "three"]}})).should be_true
    end
  end

  describe "schema_json" do
    it "exposes the generated JSON Schema" do
      User.schema_json.should contain("\"exclusiveMinimum\":0")
      User.schema_json.should contain("\"required\":[\"name\",\"age\",\"active\"]")
    end
  end
end
