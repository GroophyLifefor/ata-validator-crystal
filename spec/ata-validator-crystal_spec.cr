require "./spec_helper"

describe AtaValidator do
  schema = <<-JSON
  {
    "type": "object",
    "properties": {
      "name": {"type": "string", "minLength": 1},
      "age":  {"type": "integer", "minimum": 0}
    },
    "required": ["name"]
  }
  JSON

  it "loads the native library and reports version" do
    AtaValidator.version.should eq("1.2.2")
  end

  it "accepts a valid document via compiled schema" do
    validator = AtaValidator::Validator.new(schema)
    result = validator.validate(%({"name": "Mert", "age": 28}))
    validator.close

    result.valid.should be_true
    result.errors.empty?.should be_true
  end

  it "rejects an invalid document and reports paths/messages" do
    validator = AtaValidator::Validator.new(schema)
    result = validator.validate(%({"age": -1}))
    validator.close

    result.valid.should be_false
    result.errors.size.should eq(2)
    result.errors[0].message.should contain("name")
    result.errors[1].path.should eq("/age")
  end

  it "supports valid? for a quick boolean check" do
    validator = AtaValidator::Validator.new(schema)
    validator.valid?(%({"name": "Mert"})).should be_true
    validator.valid?(%({})).should be_false
    validator.close
  end

  it "supports the one-shot module-level API" do
    result = AtaValidator.validate(schema, %({"name": "Mert"}))
    result.valid.should be_true
  end
end
