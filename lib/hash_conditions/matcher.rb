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
        result: lambda{ | expression, options |
          match_single hash, expression
        },
        finalize: lambda{ | array, options |
          finalize hash, array, options 
        }
    end
   
    def self.finalize hash, array, options
      case options[:glue]
        when :or then array.any?
        when :and then array.all?
      end
    end   
    
    ARITMETIC_OPERATORS = {
      '$add' => :+,
      '$substract' => :-,
      '$multiply' => :*,
      '$divide' => :/,
    }

    def self.get_key hash, key
      case key
        when String, Symbol
          if key.to_s == '$now'
            Time.now
          else
            hash[key]
          end
        when Hash
          op, values = key.to_a.first

          values = values.map{ |x| get_key hash, x }

          case op.to_s
            when *ARITMETIC_OPERATORS.keys
              values.inject( ARITMETIC_OPERATORS[ op ] )
            when '$ifNull'
              val = values.shift
              val.nil? ? values.shift : val
          end
      end
    end
    
    def self.match_single hash, expression
      hash_value = get_key hash, expression[:key]
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
