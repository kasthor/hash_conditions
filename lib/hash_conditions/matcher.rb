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

    def self.match hash, conditions, options = {}
      options = {
        operation: :match,
        result: lambda{ | expression, options |
          match_single hash, expression, options
        },
        finalize: lambda{ | array, options |
          finalize hash, array, options
        }
      }.merge options

      iterator conditions, options
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

    def self.get_key hash, key, options = {}
      __get_values = lambda do | values |
        values.map{ |x| get_key hash, x, options }
      end
      case key
        when String, Symbol
          if key.to_s == '$now'
            options[:current_time] || Time.now
          else
            re_type hash[key]
          end
        when Hash
          op, values = key.to_a.first

          case op.to_s
            when *ARITMETIC_OPERATORS.keys
              __get_values.call( values ).inject( ARITMETIC_OPERATORS[ op ] )
            when '$ifNull'
              __get_values.call( values ).drop_while{ |n| n.nil? }.shift
            when '$concat'
              __get_values.call( values ).join('')
            when '$concatWithSeparator'
              separator = values.shift
              __get_values.call( values ).join( separator )
          end
      end
    end

    def self.match_single hash, expression, options
      hash_value = get_key hash, expression[:key], options
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
          hash_value > comparisson_value[0] and hash_value < comparisson_value[1]
        when :contains
          !! %r{#{comparisson_value}}.match( hash_value )
        else
          hash_value.send( expression[:operator], comparisson_value )
      end
    end

    def self.when hash, query
      now_result = match hash, query
      test_times = critical_times( hash, time_expressions( query ) )
      test_times.
       sort.
       drop_while{ |t| t < Time.now }.
       find{ |t| now_result != match( hash, query, current_time: t ) }
    end

    def self.critical_times hash, expressions
      expressions.
        map{ | e |
          case e[:operator]
            when :<, :<=, :>, :>= then
              diff = e[:value] - get_key(hash, e[:key]) + 1
            when :==, :!= then Time.now + s[:diff]
              diff = e[:value] - get_key(hash, e[:key])
            when :between
              diff = e[:value][0] - get_key(hash, e[:key])
              diff = e[:value][1] - get_key(hash, e[:key]) if Time.now + diff < Time.now
          end

          Time.now + diff
        }
    end

    def self.time_expressions conditions
      expressions = []
      iterator conditions,
        operation: :match,
        result: lambda{ | expression, options |
          expressions << expression if uses_now? expression
        },
        finalize: lambda{ | array, options |
          expressions
        }

      expressions
    end

    def self.uses_now? expression
      key_uses_now? expression[:key]
    end

    def self.key_uses_now? key
      case key
        when String, Symbol
          key.to_s == '$now'
        when Hash
          op, values = key.to_a.first
          values.map{ |v| key_uses_now? v }.any?
      end
    end
  end
end
