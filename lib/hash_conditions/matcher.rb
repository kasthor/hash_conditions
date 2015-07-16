module HashConditions
  class Matcher
    extend Core

    def self.fix_for_aritmetics *values
      class_precedence = [ Float, Integer, String ]

      klass = class_precedence.find{ |k| values.any?{ |v| v.is_a? k } } || NilClass

      values = case klass.name
        when "Integer" then values.map(&:to_i)
        when "Float"   then values.map(&:to_f)
        when "String"  then values.map(&:to_s)
        else values
      end
    end

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

    def self.match_single hash, expression, options
      log "Matching:", expression
      hash_value = eval_operand hash, expression[:key], options.merge(is_key: true)
      comparisson_value = eval_operand hash, expression[ :value ], options

      log "Left:", hash_value
      log "Right:", comparisson_value

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
          values = fix_for_aritmetics hash_value, comparisson_value
          values[0].send( expression[:operator], values[1] )
      end
      # rescue
        # raise "The expression: #{ expression } has an error"
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
              diff = get_diff( eval_operand( hash, e[:value] ), eval_operand( hash, e[:key], is_key: true )) + 1
            when :==, :!= then Time.now + s[:diff]
              diff = get_diff( eval_operand( hash, e[:value] ), eval_operand(hash, e[:key]) )
            when :between
              diff = get_diff( eval_operand( hash, e[:value][0] ), eval_operand(hash, e[:key], is_key: true ) )
              diff = get_diff( eval_operand( hash, e[:value][1] ), eval_operand(hash, e[:key], is_key: true ) ) if Time.now + diff < Time.now
          end

          Time.now + diff
        }
    end

    def self.get_diff *values
      fix_for_aritmetics(*values).inject(&:-)
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
      operand_uses_now? expression[:key]  or operand_uses_now? expression[:value]
    end

    def self.operand_uses_now? key
      case key
        when String, Symbol
          key.to_s == '$now'
        when Hash
          op, values = key.to_a.first
          values.map{ |v| operand_uses_now? v }.any?
        when Array
          key.map{ |v| operand_uses_now? v }.any?
        else
          false
      end
    end
  end
end
