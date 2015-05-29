module HashConditions
  class ModuleMatcher
    attr_accessor :replacement

    def initialize matcher, replacement, operations = []
      operations = [ :parse, :match ] if operations.empty?

      @matcher = matcher
      @replacement = replacement
      @operations = operations
    end

    def for_operation? operation
      @operations.include? operation
    end

    def apply_for key, condition
      case @matcher
        when Symbol then @matcher == key.to_sym
        when String then @matcher == key.to_s
        when Regexp then @matcher =~ key.to_s
        when Proc   then !! @matcher.call( key, condition )
        else false
      end
    end
  end
end
