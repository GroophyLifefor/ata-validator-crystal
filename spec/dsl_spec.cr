require "./spec_helper"

Ata.object User do
  string :name, min: 3, max: 10
  int :age, gt: 0, lte: 120
  string :email, format: "email", optional: true
  bool :active
end

Ata.object Address do
  string :city, min: 1
  int :zip, gte: 0
end

Ata.object Person do
  string :name, min: 3
  object :address, of: Address
end

Ata.object Tags do
  string :name, min: 1
  array :tags, of: :string, min_items: 1
end

Ata.object Any do
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

  describe "from_json" do
    it "returns a typed struct with field getters" do
      u = User.from_json(%({"name": "Mert", "age": 28, "active": true}))
      u.should be_a(User)
      u.name.should eq("Mert")
      u.age.should eq(28)
      u.active.should be_true
    end

    it "treats missing optional fields as nil" do
      u = User.from_json(%({"name": "Mert", "age": 28, "active": true}))
      u.email.should be_nil
    end
  end

  describe "nested schemas" do
    it "validates the nested object" do
      Person.valid?(%({"name": "Mert", "address": {"city": "Ankara", "zip": 6420}})).should be_true
      Person.valid?(%({"name": "Mert", "address": {"zip": -1}})).should be_false
      Person.valid?(%({"name": "Mert"})).should be_false
    end

    it "parses the nested object into a typed struct" do
      p = Person.from_json(%({"name": "Mert", "address": {"city": "Ankara", "zip": 6420}}))
      p.address.should be_a(Address)
      p.address.city.should eq("Ankara")
      p.address.zip.should eq(6420)
    end
  end

  describe "arrays" do
    it "validates primitive arrays" do
      Tags.valid?(%({"name": "x", "tags": ["a", "b"]})).should be_true
      Tags.valid?(%({"name": "x", "tags": []})).should be_false
      Tags.valid?(%({"name": "x", "tags": [1]})).should be_false
    end

    it "parses primitive arrays" do
      t = Tags.from_json(%({"name": "x", "tags": ["a", "b"]}))
      t.tags.should eq(["a", "b"])
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
