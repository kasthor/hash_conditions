describe "match" do
  let( :match ) { ->( scenario ){
    condition, value = scenario
    expect( HashConditions::Matcher.match( hash, condition ) ).to be value
  }}
  describe "$eq" do
    let( :hash ){{condition: 'value'}}
    let( :scenarios ){[
      [ { condition: 'value' }, true ],
      [ { condition: 'false' }, false ] 
    ]}
    it { scenarios.each &match }
  end
  
  describe "$gt" do
    let( :hash ){{condition: 5}}
    let( :scenarios ){ [ 
      [{ condition: { '$gt' =>  4 } }, true],
      [{ condition: { '$gt' =>  6 } }, false]
    ]}
    it { scenarios.each &match }
  end

  describe "$lt" do
    let( :hash ){{condition: 5}}
    let( :scenarios ){ [ 
      [{ condition: { '$lt' =>  4 } }, false],
      [{ condition: { '$lt' =>  6 } }, true]
    ]}
    it { scenarios.each &match }
  end

  describe "$gte" do
    let( :hash ){{condition: 5}}
    let( :scenarios ){ [ 
      [{ condition: { '$gte' =>  4 } }, true],
      [{ condition: { '$gte' =>  5 } }, true],
      [{ condition: { '$gte' =>  6 } }, false]
    ]}
    it { scenarios.each &match }
  end

  describe "$lte" do
    let( :hash ){{condition: 5}}
    let( :scenarios ){ [ 
      [{ condition: { '$lte' =>  4 } }, false],
      [{ condition: { '$lte' =>  5 } }, true],
      [{ condition: { '$lte' =>  6 } }, true]
    ]}
    it { scenarios.each &match }
  end

  describe "$in" do 
    let( :hash ){{ condition: 3 }}
    let( :scenarios ){ [ 
      [{ condition: [ 1,2,3 ] }, true],
      [{ condition: [ 4,5,6 ] }, false],
      [{ condition: { '$in' => [ 1,2,3 ] } }, true],
    ]}
    it { scenarios.each &match }
  end

  describe "$between" do 
    let( :hash ){{ condition: 3 }}
    let( :scenarios ){ [ 
      [{ condition: { '$between' => [2, 4] } }, true],
      [{ condition: { '$between' => [4,10] } }, false],
    ]}
    it { scenarios.each &match }
  end

  describe "$contains" do 
    let( :hash ){{ condition: "testing" }}
    let( :scenarios ){ [ 
      [{ condition: { '$contains' => 'test' } }, true],
      [{ condition: { '$contains' => 'not'  } }, false],
    ]}
    it { scenarios.each &match }
  end

  describe "$and" do
    let( :hash ){{condition: 5}}
    let( :scenarios ){ [ 
      [{ '$and' => [ { condition: { '$gt' =>  4 } }, { condition: { '$lt' =>  6 } } ] }, true],
      [{ '$and' => [ { condition: { '$gt' =>  4 } }, { condition: { '$lt' =>  4 } } ] }, false],
      [{ '$and' => [ { condition: { '$gt' =>  6 } }, { condition: { '$lt' =>  6 } } ] }, false],
      [{ '$and' => [ { condition: { '$gt' =>  6 } }, { condition: { '$lt' =>  4 } } ] }, false],
    ]}
    it { scenarios.each &match }
  end

  describe "$or" do
    let( :hash ){{condition: 5}}
    let( :scenarios ){ [ 
      [{ '$or' => [ { condition: { '$gt' =>  4 } }, { condition: { '$lt' =>  6 } } ] }, true],
      [{ '$or' => [ { condition: { '$gt' =>  4 } }, { condition: { '$lt' =>  4 } } ] }, true],
      [{ '$or' => [ { condition: { '$gt' =>  6 } }, { condition: { '$lt' =>  6 } } ] }, true],
      [{ '$or' => [ { condition: { '$gt' =>  6 } }, { condition: { '$lt' =>  4 } } ] }, false],
    ]}
    it { scenarios.each &match }
  end


  describe "force string comparations" do
    it "makes a string match a number for equality" do
      HashConditions::Matcher.configure force_string_comparations: true

      expect( HashConditions::Matcher.match( { a: "5" }, { a: 5 } ) ).to be true
      expect( HashConditions::Matcher.match( { a: "5" }, { a: { '$eq' => 5 } } ) ).to be true
    end
  end
end
