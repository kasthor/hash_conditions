describe ".get_conditions" do
  it "parses single string operator" do 
    HashConditions::Parser.get_conditions({ condition: 'value' }).should == "condition = 'value'" 
  end

  it "parses single integer operator" do 
    HashConditions::Parser.get_conditions({ condition: 1 }).should == "condition = 1" 
  end

  it "parses an array as an IN" do
    HashConditions::Parser.get_conditions({ condition: [1, 2, 3] }).should == "condition IN ( 1, 2, 3 )" 
  end

  it "parses a $lt condition" do
    HashConditions::Parser.get_conditions( { condition: { '$lt' => 1 } } ).should == "condition < 1" 
  end

  it "parses a $gt condition" do
    HashConditions::Parser.get_conditions( { condition: { '$gt' => 1 } } ).should == "condition > 1" 
  end

  it "parses a $lte condition" do
    HashConditions::Parser.get_conditions( { condition: { '$lte' => 1 } } ).should == "condition <= 1" 
  end

  it "parses a $gte condition" do
    HashConditions::Parser.get_conditions( { condition: { '$gte' => 1 } } ).should == "condition >= 1" 
  end

  it "parses a $eq condition" do
    HashConditions::Parser.get_conditions( { condition: { '$eq' => 1 } } ).should == "condition = 1" 
  end
  
  it "parses a $equal condition" do
    HashConditions::Parser.get_conditions( { condition: { '$equal' => 1 } } ).should == "condition = 1" 
  end

  it "parses a $contains condition" do
    HashConditions::Parser.get_conditions( { condition: { '$contains' => 'a' } } ).should == "condition LIKE '%a%'" 
  end

  it "parses implicit $and conditions" do
    HashConditions::Parser.get_conditions( { condition: 1, another: 2 } ).should == "condition = 1 AND another = 2"
  end 

  it "parses explicit $and conditions" do
    HashConditions::Parser.get_conditions( { "$and" => { condition: 1, another: 2 } } ).should == "( condition = 1 AND another = 2 )"
  end   

  it "parses explicit $or conditions" do
    HashConditions::Parser.get_conditions( { "$or" => { condition: 1, another: 2 } } ).should == "( condition = 1 OR another = 2 )"
  end   
  it "parses explicit $and condition within array" do
    HashConditions::Parser.get_conditions( { "$and" => [{ condition: 1},{ another: 2 } ] } ).should == "( ( condition = 1 ) AND ( another = 2 ) )"
  end
end
describe "external handlers" do
  before { HashConditions::Parser.reset }
  it "reset the matchers" do
    HashConditions::Parser.match "x", "x"
    HashConditions::Parser.reset
    expect( HashConditions::Parser.matchers.length ).to eq 0
  end
  it "add a matcher" do
    HashConditions::Parser.match "special", "special"
    expect( HashConditions::Parser.matchers.length ).to eq 1
  end
  describe "matchers" do
    let(:fake_parser) { lambda{} }
    it "match a string" do
      expect(fake_parser).to receive(:call)
      HashConditions::Parser.match "special", fake_parser
      HashConditions::Parser.get_conditions( { special: "test" } )
    end
    it "match a regex" do
      expect(fake_parser).to receive(:call)
      HashConditions::Parser.match /^special/, fake_parser
      HashConditions::Parser.get_conditions( { special: "test" } )
    end
    it "match a proc" do
      expect(fake_parser).to receive(:call)
      is_special = ->(key, condition){ key == :special  }
      HashConditions::Parser.match is_special, fake_parser
      HashConditions::Parser.get_conditions( { special: "test" } )
    end
  end
  describe "parser" do
    it "receives a string" do
      HashConditions::Parser.match :condition, "new_condition"
      HashConditions::Parser.get_conditions({ condition: 1 }).should == "new_condition = 1" 
    end
    it "receives a proc" do
      parser = ->( key, condition ){{ new_condition: 1 }}
      HashConditions::Parser.match :condition, parser 
      HashConditions::Parser.get_conditions({ condition: 1 }).should == "( new_condition = 1 )" 
    end
    it "receives a block" do
      HashConditions::Parser.match(:condition){ |key, condition| { new_condition: 1 } }
      HashConditions::Parser.get_conditions({ condition: 1 }).should == "( new_condition = 1 )" 
    end
  end
  describe "parser application" do
    it "when receiving is a string, replace key" do
      HashConditions::Parser.match :condition, "new_condition"
      HashConditions::Parser.get_conditions({ condition: 1 }).should == "new_condition = 1" 
    end

    it "when receiving a proc and returns a string, raises an exception" do
      HashConditions::Parser.match :condition do 
        "new_condition = 0"
      end
      expect {
        HashConditions::Parser.get_conditions({ condition: 1 }).should == "new_condition = 0" 
      }.to raise_error
    end
    it "when receiving a proc and return a hash, it gets assambled" do
      HashConditions::Parser.match :condition do 
        { new_condition: 0 }
      end
      HashConditions::Parser.get_conditions({ condition: 1 }).should == "( new_condition = 0 )" 
    end
  end
  describe "module flags" do
    it "adds and check existence of a module" do
      HashConditions::Parser.add_module "TEST"
      expect( HashConditions::Parser.contains_module("TEST") ).to eq( true )
    end
  end
end
