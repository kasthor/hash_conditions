module HashConditions
  class Matcher
    extend Core 

    def self.configurations 
      @@configurations ||= {}
    end

    def self.configure config
      configurations.merge! config
    end

    def self.configuration key
      configurations[key]
    end

    def self.match hash, conditions
      iterator conditions, 
        result: ->( expression, options ){
          match_single hash, expression
        },
        finalize: ->( array, options ){
          finalize hash, array, options 
        }
    end
   
    def self.finalize hash, array, options
      case options[:glue]
        when :or then array.any?
        when :and then array.all?
      end
    end   
    
    def self.match_single hash, expression
      hash_value = hash[ expression[:key] ]
      comparisson_value = expression[ :value ]

      case expression[:operator]
        when :== 
          if configuration( :force_string_comparations )
            hash_value = hash_value.to_s
            comparisson_value = comparisson_value.to_s
          end
          hash_value == comparisson_value
        when :in
          if configuration( :force_string_comparations )
            hash_value = hash_value.to_s
            comparisson_value = comparisson_value.map(&:to_s)
          end
  
          comparisson_value.include? hash_value
        when :between
          hash_value > comparisson_value.shift and hash_value < comparisson_value.shift
        when :contains
          !! %r{#{comparisson_value}}.match( hash_value )
        else
          hash_value.send( expression[:operator], comparisson_value )
      end
    end
  end
end
