describe "match" do
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

    describe "homogenize the values when <, >, >=, <=" do
      let( :hash ){{condition: 5}}
      let( :scenarios ){ [
        [{ condition: { '$gt' =>  "4" } }, true],
        [{ condition: { '$lt' =>  "4" } }, false],
        [{ condition: { '$lte' =>  "5" } }, true],
        [{ condition: { '$gte' =>  "5" } }, true],
      ]}
      it { scenarios.each &match }
    end

    describe "$in" do
      let( :hash ){{ condition: 3 }}
      let( :scenarios ){ [
        [{ condition: [ 1,2,3 ] }, true],
        [{ condition: [ 4,5,6 ] }, false],
        [{ condition: { '$in' => [ 1,2,3 ] } }, true]
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

    describe "$eval" do
      let( :hash ){{condition: 5, other_condition: 10, null: nil, time: Time.now}}
      let( :scenarios ){[
        [{ '$eval' => [ :condition, '$eq', 5] }, true],
        [{ '$eval' => [ {'$add' => [ :condition, :other_condition ] }, '$eq', 15 ] }, true],
        [{ '$eval' => [ {'$substract' => [ '$now', :time ] }, '$lt', 1 ] }, true]
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

    describe "re_type" do
      it "returns the value as a date if it matches the regex" do
        expect(
          HashConditions::Matcher.re_type("2015-05-21T18:03:39.000Z")
        ).to be_a Time
      end
    end

    describe "eval_operand" do
      let( :hash ){{ a: 1, b: 2, null: nil } }
      it "returns a key when key is a string" do
        expect( HashConditions::Matcher.eval_operand hash, :a ).to eq :a
      end

      it "returns a key when key is a string and is_key is true" do
        expect( HashConditions::Matcher.eval_operand hash, :a, is_key: true ).to eq 1
      end

      it "return a time containing current time when now is specified" do
        expect( HashConditions::Matcher.eval_operand(hash, '$now') ).to be_within( 1 ).of( Time.now )
      end

      it "executes an addition when requested" do
        expect( HashConditions::Matcher.eval_operand( hash, { "$add" => [ :a, :b ] }, is_key: true )).to eq( 3 )
      end

      it "executes a substraction when requested" do
        expect( HashConditions::Matcher.eval_operand( hash, { "$substract" => [ :b, :a ] }, is_key: true )).to eq( 1 )
      end

      it "executes an $ifNull expression" do
        expect( HashConditions::Matcher.eval_operand( hash, {'$ifNull' => [ :null , :a ] }, is_key: true )).to eq( 1 )
      end
    end
  end

  describe "when" do
    let( :hash ){{ date: Time.now - 1800, permanent_condition: false } }
    let( :query ){{{ '$substract' => [ '$now', :date ] } => { '$gt' => 3600 }}}

    it "knows if an expression is time sensible" do
      expect( HashConditions::Matcher.time_sensible? query ).to be true
    end

    it "calculates the critical points out of a bunch of expressions" do
      expect( HashConditions::Matcher.critical_times( hash,
       [ {:key=>{"$substract"=>["$now", :date]}, :operator=>:>, :value=>3600} ]
      ).shift).to be_within( 1 ).of( Time.now + 1800 )
    end

    it "calculates the critical points out of a bunch of expressions when $now is in the value" do
      expect( HashConditions::Matcher.critical_times( hash,
       [ {:key=> :date, :operator=>:between, :value=> [ { '$substract' => [ '$now', 3600 ] }, '$now' ] } ]
      ).shift).to be_within( 1 ).of( Time.now + 1800 )
    end

    it "calculates the critical points out of a bunch of expressions when $now is in the value" do
      hash = { date: Time.now }
      expect( HashConditions::Matcher.critical_times( hash,
        [{:key=>:date, :operator=>:between, :value=>[{"$substract"=>[{"$substract"=>["$now", 0]}, 600]}, {"$add"=>[{"$substract"=>["$now", 0]}, 60]}]}]
      ).shift).to be_within( 1 ).of( Time.now + 600 )
    end

    it "calculates the critical points out of a bunch of expressions when compared with a numeric string" do
      expect( HashConditions::Matcher.critical_times( hash,
       [ {:key=>{"$substract"=>["$now", :date]}, :operator=>:>, :value=>"3600"} ]
      ).shift).to be_within( 1 ).of( Time.now + 1800 )
    end

    it "knows when a sub expression uses $now" do
      expect( HashConditions::Matcher.uses_now?({:key=>{"$substract"=>["$now", "date"]}, :operator=>:>, :value=>3600}) ).to be true
    end

    it "knows when a complex sub expression uses $now" do
      expect( HashConditions::Matcher.uses_now?({:key=>{"$substract"=>[{ "$ifNull" => [ 'null', "$now" ] } , "date"]}, :operator=>:>, :value=>3600}) ).to be true
    end

    it "knows when a sub expression uses $now in the value" do
      expect( HashConditions::Matcher.uses_now?({:key=>'test', :operator=>:>, :value=> '$now' }) ).to be true
    end

    it "knows when a complex sub expression doesn't use $now" do
      expect( HashConditions::Matcher.uses_now?({:key=>{"$substract"=>[{ "$ifNull" => [ 'null', "null" ] } , "date"]}, :operator=>:>, :value=>3600}) ).to be false
    end

    it "returns a list of the expressions using $now" do
      expect( HashConditions::Matcher.time_expressions( query ) ).to include({:key=>{"$substract"=>["$now", :date]}, :operator=>:>, :value=>3600})
    end

    it "handles a basic query" do
      expect( HashConditions::Matcher.when( hash, query ) ).to be_within(1).of( Time.now + 1800 )
    end

    it "handles a basic query when time has passed" do
      query = {{ '$substract' => [ '$now', :date ] } => { '$gt' => 1800 }}
      expect( HashConditions::Matcher.when( hash, query ) ).to be nil
    end

    it "solves a query when there are multiple time queries" do
      query = {
        "$and" => [
          { '$substract' => [ '$now', :date ] } => { '$gt' => 3600 },
          { '$substract' => [ '$now', :date ] } => { '$gt' => 7200 },
        ]
      }
      expect( HashConditions::Matcher.when hash, query ).to be_within(1).of( Time.now + 5400 )
    end

    it "returns nil when the condition will never pass" do
      query = {
        "$and" => [
          { { '$substract' => [ '$now', :date ] } => { '$gt' => 3600 } },
          { permanent_condition: {"$eq" =>  true}}
        ]
      }
      expect( HashConditions::Matcher.when hash, query ).to be nil
    end

    it "handles between operator when first condition is relevant" do
      query = { { '$substract' => [ '$now', :date ] } => { '$between' => [3600, 7200] } }
      expect( HashConditions::Matcher.when( hash, query ) ).to be_within(1).of( Time.now + 1800 )
    end

    it "handles between operator when second conditions is relevant" do
      query = { { '$substract' => [ '$now', :date ] } => { '$between' => [1000, 7200] } }
      expect( HashConditions::Matcher.when( hash, query ) ).to be_within(1).of( Time.now + 5400 )
    end

    it "handles between operator when time window already passed" do
      query = { { '$substract' => [ '$now', :date ] } => { '$between' => [500, 1000] } }
      expect( HashConditions::Matcher.when( hash, query ) ).to be nil
    end

  end
end
