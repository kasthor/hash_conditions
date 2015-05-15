module HashConditions
  module Core
    # Modular Matchers
    def matchers
      @@matchers ||= []
    end

    def reset
      @@matchers = []
    end
  
    # Iterator

    def iterator conditions, options = {}
      options = { glue: :and }.merge options

      result = case conditions 
        when ::Hash
          conditions.map do | key, value |
            case key
              when '$and' then iterator(value, options.merge( glue: :and ))
              when '$or' then iterator(value, options.merge( glue: :or))
              when _ext_match( value ) then _ext_parse( key, value, options )
              else options[:result].call( extract_expression( key, value ), options )
            end
          end
        when ::Array
          conditions.map do | condition |
            iterator condition, options
          end
      end
  
      options[:finalize].call result, options
    end

    def extract_expression key, value
      result = {}
      result[:key] = key

      case value
        when String, Integer, Float
          result[:operator] = :==
          result[:value] = value
        when Array
          result[:operator] = :in
          result[:value] = value
        when Hash
          if value.length == 1
            key, value = value.to_a.first

            result[:operator] = case key
              when '$eq', '$equal' then :==
              when '$ne', '$not_equal' then :!=
              when '$gt' then :>
              when '$lt' then :<
              when '$gte' then :>=
              when '$lte' then :<=
              when '$between' then :between
              when '$in' then :in
              when '$contains' then :contains
              else 
                raise "No operator for '#{ op }"
            end

            result[:value] = value
          else 
            case 
              when value.keys.include?('$between')
                result[:operator] = :between
                result[:values] = value.values_at [ '$between', '$and' ]
            end
          end
      end

      result
    end

    def _ext_match condition
      ->(key) { _ext_get_module( key, condition ) != nil }
    end

    def _ext_parse key, condition, options
      matcher, parser = _ext_get_module key,condition

      case parser 
        when String then options[:result].call(extract_expression( parser, condition ), options)
        when Proc   then _ext_read_module( parser.call( key, condition ), options )
      end 
    end

    def _ext_get_module key, condition
      matchers.find do | matcher_pair |
        matcher, parser = matcher_pair
        case matcher
          when Symbol then matcher == key.to_sym
          when String then matcher == key.to_s
          when Regexp then matcher =~ key.to_s
          when Proc   then !! matcher.call( key, condition )
          else false
        end
      end 
    end

    def _ext_read_module parser_output, options
      case parser_output
        when Hash   then iterator(parser_output, options)
        when NilClass then nil
        else raise "return data of type #{ parser_output.class } not supported"
      end
    end
  end
end
