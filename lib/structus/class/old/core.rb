module Structura::Class

  NAMING_RISKS = {
    conflict:      10,
    no_identifier:  9,
    bad_manners:    5,
    no_ascii:       3,
    strict:         0 
  }.freeze

  PROTECT_LEVELS = {
    struct:      {error: 99, warn: 99},
    warning:     {error: 99, warn:  5},
    error:       {error:  9, warn:  5},
    prevent:     {error:  5, warn:  1},
    nervous:     {error:  1, warn:  1}
  }.each(&:freeze).freeze

end

require_relative 'basic'
require_relative 'constructor'
require_relative 'safety'
require_relative 'handy'
require_relative 'macro'
require_relative 'inner'
