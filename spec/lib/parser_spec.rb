describe ".get_conditions" do
  it "parses single string operator" do
    expect(HashConditions::Parser.get_conditions({ condition: 'value' })).to eq "condition = 'value'"
  end

  it "parses single integer operator" do
    expect(HashConditions::Parser.get_conditions({ condition: 1 })).to eq "condition = 1"
  end

  it "evals an expression before creating the request" do
    expect(HashConditions::Parser.get_conditions({ condition: { '$eq' => { '$add' => [ 2, 2 ] }}})).to eq "condition = 4"
  end

  it "parses an array as an IN" do
    expect(HashConditions::Parser.get_conditions({ condition: [1, 2, 3] })).to eq "condition IN ( 1, 2, 3 )"
  end

  it "parses a $lt condition" do
    expect(HashConditions::Parser.get_conditions( { condition: { '$lt' => 1 } } )).to eq "condition < 1"
  end

  it "parses a $gt condition" do
    expect(HashConditions::Parser.get_conditions( { condition: { '$gt' => 1 } } )).to eq "condition > 1"
  end

  it "parses a $lte condition" do
    expect(HashConditions::Parser.get_conditions( { condition: { '$lte' => 1 } } )).to eq "condition <= 1"
  end

  it "parses a $gte condition" do
    expect(HashConditions::Parser.get_conditions( { condition: { '$gte' => 1 } } )).to eq "condition >= 1"
  end

  it "parses a $eq condition" do
    expect(HashConditions::Parser.get_conditions( { condition: { '$eq' => 1 } } )).to eq "condition = 1"
  end

  it "parses a $ne condition" do
    expect(HashConditions::Parser.get_conditions( { condition: { '$ne' => 1 } } )).to eq "condition != 1"
  end

  it "parses a $not_equal condition" do
    expect(HashConditions::Parser.get_conditions( { condition: { '$not_equal' => 1 } } )).to eq "condition != 1"
  end

  it "parses a $equal condition" do
    expect(HashConditions::Parser.get_conditions( { condition: { '$equal' => 1 } } )).to eq "condition = 1"
  end

  it "parses a $contains condition" do
    expect(HashConditions::Parser.get_conditions( { condition: { '$contains' => 'a' } } )).to eq "condition LIKE '%a%'"
  end

  it "parses implicit $and conditions" do
    expect(HashConditions::Parser.get_conditions( { condition: 1, another: 2 } )).to eq "condition = 1 AND another = 2"
  end

  it "parses explicit $and conditions" do
    expect(HashConditions::Parser.get_conditions( { "$and" => { condition: 1, another: 2 } } )).to eq "( condition = 1 AND another = 2 )"
  end

  it "parses explicit $or conditions" do
    expect(HashConditions::Parser.get_conditions( { "$or" => { condition: 1, another: 2 } } )).to eq "( condition = 1 OR another = 2 )"
  end
  it "parses explicit $and condition within array" do
    expect(HashConditions::Parser.get_conditions( { "$and" => [{ condition: 1},{ another: 2 } ] } )).to eq "( ( condition = 1 ) AND ( another = 2 ) )"
  end
end
describe "external handlers" do
  before { HashConditions::Parser.reset }
  it "reset the matchers" do
    HashConditions::Parser.module_match "x", "x"
    HashConditions::Parser.reset
    expect( HashConditions::Parser.modules.length ).to eq 0
  end
  it "add a matcher" do
    HashConditions::Parser.module_match "special", "special"
    expect( HashConditions::Parser.modules.length ).to eq 1
  end
  describe "modules" do
    let(:fake_parser) { lambda{} }
    it "match a string" do
      expect(fake_parser).to receive(:call)
      HashConditions::Parser.module_match "special", fake_parser
      HashConditions::Parser.get_conditions( { special: "test" } )
    end

    it "match a specific operation" do
      fake_parser = lambda{}
      fake_matcher = lambda{}

      expect( fake_parser ).to receive(:call)
      expect( fake_matcher).not_to receive(:call)

      HashConditions::Parser.module_match "special", fake_parser, [:parse]
      HashConditions::Parser.module_match "special", fake_matcher, [:match]

      HashConditions::Parser.get_conditions( { special: "test" } )
    end

    it "match a regex" do
      expect(fake_parser).to receive(:call)
      HashConditions::Parser.module_match /^special/, fake_parser
      HashConditions::Parser.get_conditions( { special: "test" } )
    end
    it "match a proc" do
      expect(fake_parser).to receive(:call)
      is_special = ->(key, condition){ key == :special  }
      HashConditions::Parser.module_match is_special, fake_parser
      HashConditions::Parser.get_conditions( { special: "test" } )
    end
  end
  describe "parser" do
    it "receives a string" do
      HashConditions::Parser.module_match :condition, "new_condition"
      expect(HashConditions::Parser.get_conditions({ condition: 1 })).to eq "new_condition = 1"
    end
    it "receives a proc" do
      parser = ->( key, condition, options ){{ new_condition: 1 }}
      HashConditions::Parser.module_match :condition, parser
      expect(HashConditions::Parser.get_conditions({ condition: 1 })).to eq "( new_condition = 1 )"
    end
    it "receives a block" do
      HashConditions::Parser.module_match(:condition){ |key, condition| { new_condition: 1 } }
      expect(HashConditions::Parser.get_conditions({ condition: 1 })).to eq "( new_condition = 1 )"
    end
  end
  describe "parser application" do
    it "when receiving is a string, replace key" do
      HashConditions::Parser.module_match :condition, "new_condition"
      expect(HashConditions::Parser.get_conditions({ condition: 1 })).to eq "new_condition = 1"
    end

    it "when receiving a proc and returns a string, it matches" do
      HashConditions::Parser.module_match :condition do
        "new_condition = 0"
      end
      expect( HashConditions::Parser.get_conditions({ condition: 1 }) ).to eq("new_condition = 0")
    end
    it "when receiving a proc and return a hash, it gets assambled" do
      HashConditions::Parser.module_match :condition do
        { new_condition: 0 }
      end
      expect( HashConditions::Parser.get_conditions({ condition: 1 }) ).to eq( "( new_condition = 0 )" )
    end
  end
  describe "module flags" do
    it "adds and check existence of a module" do
      HashConditions::Parser.add_bundle "TEST"
      expect( HashConditions::Parser.contains_bundle("TEST") ).to eq( true )
    end
  end
end
