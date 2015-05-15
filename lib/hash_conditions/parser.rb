module HashConditions
  class Parser
    extend Core

    def self.modules 
      @@modules ||= []
    end
    def self.add_module name
      modules << name
    end
    def self.contains_module name 
      modules.include? name
    end

    def self.match matcher, writer = nil, &block
      writer = block if block
      matchers << [matcher, writer];
    end

    def self.get_conditions conditions, options = {}
      result = iterator conditions,
        result: ->( expression, options ){
          _parse_key_value_condition expression
        },
        finalize: -> ( array, options ){
          "( #{ array.join( " #{ options[:glue].upcase } " ) } )"
        }

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
        when :>, :<, :>=, :<=
          "#{ expression[:operator] } #{_parse_value expression[:value]}"
        when :in
          "IN ( #{ expression[:value].map{ |v| _parse_value v }.join ", " } )"
        when :contains
          "LIKE #{ _parse_value(expression[:value], '%', '%') }"  
        when :between
          "BETWEEN #{ _parse_value expression[:value].shift } AND #{ _parse_value expression[:value].shift }"
      end

      "#{expression[:key]} #{comparisson}"
    end

    def self._parse_value value, prepend = '', append = ''
      case value
        when String then "'#{prepend}#{value}#{append}'"
        when DateTime, Date, Time then "'#{value.strftime("%Y-%m-%d %I:%M%p")}'"
        when Integer, Float then "#{value}"
      end
    end
  end
end
