module HashConditions
  class Matcher
    extend Core

    def self.fix_for_aritmetics *values
      class_precedence = [ Float, Integer, String ]

      klass = class_precedence.find{ |k| values.any?{ |v| v.is_a? k } } || NilClass

      values = case klass.name
        when "Integer" then values.map(&:to_i)
        when "Float"   then values.map(&:to_f).map{|x|x.round(3)}
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
          values = fix_for_aritmetics hash_value, *comparisson_value
          values[0] >= values[1] and values[0] < values[2]
        when :contains
          !! %r{#{comparisson_value}}.match( hash_value )
        else
          values = fix_for_aritmetics hash_value, comparisson_value
          values[0].send( expression[:operator], values[1] )
      end
      # rescue
        # raise "The expression: #{ expression } has an error"
    end

    def self.when hash, query, options = {}
      current_time = options[:current_time] ||= Time.now
      now_result = match hash, query, options
      test_times = critical_times( hash, time_expressions( query ), options )
      test_times.
       sort.
       drop_while{ |t| t < current_time }.
       find{ |t| now_result != match( hash, query, options.merge(current_time: t) ) }.
       tap{ |t| log 'Critical Times:', t }
    end

    def self.critical_times hash, expressions, options = {}
      current_time = options[:current_time] ||= Time.now
      expressions.
        map do | e |
          inverter = operand_uses_now?(e[:value])? -1: 1
          case e[:operator]
            when :<, :<=, :>, :>= then
              diff = inverter * get_diff( eval_operand( hash, e[:value], options ),
                                          eval_operand( hash, e[:key], options.merge(is_key: true) )) + 0.001
            when :==, :!= then
              # TODO: test this functionality
              diff = inverter * get_diff( eval_operand( hash, e[:value], options ),
                                          eval_operand(hash, e[:key], options.merge(is_key: true) ) )
            when :between
              diff = inverter * get_diff( eval_operand( hash, e[:value][0], options ),
                                          eval_operand(hash, e[:key], options.merge(is_key: true) ) )
              diff = inverter * get_diff( eval_operand( hash, e[:value][1], options ),
                                          eval_operand(hash, e[:key], options.merge(is_key: true) ) ) if current_time + diff < current_time
          end

          current_time + diff
        end
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

    def self.time_sensible? conditions
      ! time_expressions(conditions).empty?
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
