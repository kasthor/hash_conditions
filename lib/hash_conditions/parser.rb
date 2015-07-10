module HashConditions
  class Parser
    extend Core

    def self.get_conditions conditions, options = {}
      options = options.merge \
        operation: :parse,
        result: lambda{ | expression, options |
          _parse_key_value_condition expression
        },
        finalize: lambda{ | array, options |
          "( #{ array.join( " #{ options[:glue].upcase } " ) } )"
        }

      result = iterator conditions, options

      result.
        gsub!(/^\( /, '').
        gsub!(/ \)$/, '')

      result
    end

    def self._parse_key_value_condition expression
      # "#{key} #{_parse_value_condition condition}"
      comparisson = case expression[:operator]
        when :==
          "= #{_parse_value expression[:value]}"
        when :!=
          "!= #{_parse_value expression[:value]}"
        when :>, :<, :>=, :<=
          "#{ expression[:operator] } #{_parse_value expression[:value]}"
        when :in
          "IN ( #{ expression[:value].map{ |v| _parse_value v }.join ", " } )"
        when :contains
          "LIKE #{ _parse_value(expression[:value], '%', '%') }"
        when :between
          "BETWEEN #{ _parse_value expression[:value][0] } AND #{ _parse_value expression[:value][1] }"
      end

      "#{expression[:key]} #{comparisson}"
    end

    def self._parse_value value, prepend = '', append = ''
      case value
        when String then "'#{prepend}#{value}#{append}'"
        when DateTime, Date, Time then "'#{value.strftime("%Y-%m-%d %H:%M")}'"
        when Integer, Float then "#{value}"
        when Hash then _parse_value( eval_operand( {}, value ) , prepend, append )
      end
    end
  end
end
