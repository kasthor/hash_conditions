module HashConditions
  module Core
    # Modular Matchers
    def modules
      @@modules ||= []
    end

    def reset
      @@modules = []
    end

    def bundles 
      @@bundles ||= []
    end

    def add_bundle name
      bundles << name
    end
    def contains_bundle name 
      bundles.include? name
    end

    def module_match matcher, writer = nil, operations = [], &block
      writer = block if block
      modules << ModuleMatcher.new(matcher, writer, operations)
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
              when '$eval' then results_from_expression( eval_expression( value ), options )
              when _ext_match( value, options ) then _ext_parse( extract_expression(key, value) , options )
              else results_from_expression( extract_expression( key, value ), options )
            end
          end
        when ::Array
          conditions.map do | condition |
            iterator condition, options
          end
      end
  
      options[:finalize].call result, options
    end

    def results_from_expression expression, options
      options[:result].call( expression, options )
    end

    def eval_expression value
      raise "Invalid eval expression" unless value.is_a? Array and value.length == 3 

      Hash[ [ :key, :operator, :value ].zip( value ) ].tap do | exp |
        exp[ :operator ] = get_op exp[ :operator ] 
      end
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

            result[:operator] = get_op key
            result[:value] = value
          else 
            case 
              when value.keys.include?('$between')
                result[:operator] = :between
                result[:value] = value.values_at [ '$between', '$and' ]
            end
          end
      end

      result[:value] = re_type result[:value]

      result
    end

    def get_condition_from_expression expression
      {}.tap do | condition |
        condition[ expression[:operator] ] = expression[:value]
      end
    end

    def get_op key
      case key
        when '$eq', '$equal' then :==
        when '$ne', '$not_equal' then :!=
        when '$gt' then :>
        when '$lt' then :<
        when '$gte' then :>=
        when '$lte' then :<=
        when '$between' then :between
        when '$in' then :in
        when '$contains' then :contains
        else key
      end
    end

    def re_type data
      if data.is_a? String
        case data
          when /\d{4}-\d{2}-\d{2}[\sT]\d{2}:\d{2}:\d{2}(\.\d{3})?Z?/ then DateTime.parse( data ).to_time
          else data
        end  
      else
        data
      end
    end

    def _ext_match condition, options
      ->(key) { _ext_get_module( key, condition, options ) != nil }
    end

    def _ext_parse expression, options
      key, op, value = expression.values_at :key, :operator, :value
      condition = get_condition_from_expression expression

      mod = _ext_get_module key,condition, options
      parser = mod.replacement

      case parser 
        when String then options[:result].call(extract_expression( parser, condition ), options)
        when Hash   then _ext_read_module( { '$eval' => [ parser, op, value ] }, options )
        when Proc   then _ext_read_module( parser.call( key, condition ), options )
      end 
    end

    def _ext_get_module key, condition, options
      modules.select{ |m| m.for_operation? options[:operation] }.find do | matcher |
        matcher.apply_for key, condition
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
