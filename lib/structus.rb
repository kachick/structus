# Copyright (C) 2011-2012  Kenichi Kamiya
# Provides a Struct++ class.

require 'validation'

# @abstract
class Structus
  include Validation

  # namespace for .to_struct_class, #to_struct
  module Structs
  end
end

require_relative 'structus/version'
require_relative 'structus/eigen'
