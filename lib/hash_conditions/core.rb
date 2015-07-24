module HashConditions
  class KeyNotFound < Exception; end
  class UnexpectedExpression < Exception; end
  class InvalidExpression < Exception; end

  module Core
    # Modular Matchers
    DEBUG=false
    PRECISION=5
    ARITMETIC_OPERATORS = {
      '$add' => :+,
      '$substract' => :-,
      '$multiply' => :*,
      '$divide' => :/,
    }

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
        else
          raise "Unexpected expression found: #{ conditions }"
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
        condition[ rev_op( expression[:operator] ) ] = expression[:value]
      end
    end

    def ops
      {
        :==       => [ '$eq', '$equal' ],
        :!=       => [ '$ne', '$not_equal' ],
        :>        => [ '$gt' ],
        :<        => [ '$lt' ],
        :>=       => [ '$gte' ],
        :<=       => [ '$lte' ],
        :between  => [ '$between' ],
        :in       => [ "$in" ],
        :contains => [ "$contains" ]
      }
    end

    def rev_op key
      ops[ key ] && ops[ key ].first or key
    end
    def get_op key
      pair = ops.find{ |k, v| Array(v).include? key }
      pair && pair.first or key
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

    def get_key hash, key
      if hash.has_key? key
        hash[ key ]
      else
        key_type = key.class
        key.to_s.split('.').inject(hash) do |ret, k|
          typed_key = key_type == Symbol ? k.to_sym : k
          raise KeyNotFound, "key #{key} not found" unless ret.has_key? typed_key
          ret = ret[ typed_key ]
        end
      end
    end

    def eval_operand hash, key, options = {}
      __get_values = lambda do | values |
        values.map{ |x| eval_operand hash, x, options }
      end
      case key
        when String, Symbol
          if key.to_s == '$now'
            options[:current_time] || Time.now
          else
            val = options[:is_key] ? get_key( hash, key ) : key
            re_type val
          end
        when Array
          __get_values.call( key )
        when Hash
          op, values = key.to_a.first

          case op.to_s
            when *ARITMETIC_OPERATORS.keys
              #TODO: Test feature: when applying aritmetics it forces that the values are floats
              __get_values.call( values ).each{ |v| v.to_f }.inject( ARITMETIC_OPERATORS[ op ] )
            when '$ifNull'
              __get_values.call( values ).drop_while{ |n| n.nil? }.shift
            when '$concat'
              __get_values.call( values ).join('')
            when '$concatWithSeparator'
              separator = values[0]
              __get_values.call( values[1..-1] ).join( separator )
          end
        else
          key
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
        when Proc   then _ext_read_module( parser.call( key, condition, options ), options )
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
        when String then parser_output # this should be removed, since the matcher will not support it
        else raise "return data of type #{ parser_output.class } not supported"
      end
    end

    def log *args
      puts args.map(&:to_s).join(" ") if(DEBUG)
    end
  end
end
