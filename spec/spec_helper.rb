$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'hash_conditions'
require 'coveralls'

Coveralls.wear!

RSpec.configure do |config|
  config.filter_run :focus
  config.run_all_when_everything_filtered = true
  config.raise_errors_for_deprecations!
end
