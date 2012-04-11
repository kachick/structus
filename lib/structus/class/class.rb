require 'lettercase'
require 'forwardable'

module Structus::Class
  extend Forwardable
  
  class << self
    def def_wrapped_enums(recepter, *methods)
      methods.each do |method|
        def_delegator recepter, method, :"_#{method}"
        
        define_method method do |*args, &block|
          return to_enum(method) unless block_given?
          __send__ :"_#{method}", *args, &block
          self
        end
      end
    end
  end

  # @note Remind returnning values
  #   safe:   def_wrap[*]
  #   faster: def_delegator[s] 

  def_wrapped_enums :_attrs, :each_key
  def_wrapped_enums :members, :each_index

  def each_member(&block)      
    return to_enum(__method__) unless block_given?
    _attrs.each_key(&block)
    self
  end

  def members(aliased=false)
    (aliased ? _attrs : _attrs.select{|k, v|v.respond_to? :each_pair}).keys
  end

  alias_method :keys, :members

  def length
    _attrs.length
  end

  alias_method :size, :length

  def has_member?(name)
    _attrs.has_key? name
  end

  alias_method :member?, :has_member?
  alias_method :has_key?, :has_member?
  alias_method :key?, :has_member?

  VALID_OPTIONS = 
    [:is, :via, :default, :reader_validation, :writer_validation].freeze

  DEFAULT_OPTIONS = {writer_validation: true}.freeze

  def has(name, options={}, &block)
    options = DEFAULT_OPTIONS.merge options
    name = name.to_sym
    raise NameError, 'Already defined' if _attrs.has_key? name
    unless (options.keys - VALID_OPTIONS).empty?
      raise ArgumentError, 'Invalid Option Parameter' 
    end
    
    if block_given?
      raise ArgumentError unless options.empty? or options == DEFAULT_OPTIONS
      nested = _define_nested_member(name, &block)
      options = {is: nested, default: ->{nested.new}}
    end

    options.each_pair do |key, value|
      raise ArgumentError unless __send__ :"valid_option_in_#{key}?", value
    end
    
    _attrs[name] = options
    
    define_method name do
      _get! name
    end

    define_method :"#{name}=" do |value|
      _set! name, value
    end

    nil
  end

  alias_method :have,:has
  alias_method :member, :has

  def alias_member(aliased, original)
    _attrs[aliased] = original
   (_attrs(original)[:aliases] ||= []) << aliased

    alias_method aliased, original
    alias_method :"#{aliased}=", :"#{original}="
  end

  def freeze
    close
    super
  end

  def has_condition?(name)
    _attrs[name].has_key? :is
  end

  alias_method :restrict?, :has_condition?

  def has_default?(name)
    _attrs[name].has_key? :default
  end

  def has_adjuster?(name)
    _attrs[name].has_key? :via
  end

  def valid_option_in_is?(object)
    conditionable? object
  end

  def valid_option_in_via?(object)
    adjustable? object
  end

  def valid_option_in_default?(object)
    object.kind_of?(Proc) ?  (object.arity == 0) : true  
  end

  %w[reader writer].each do |type|
    define_method :"valid_option_in_#{type}_validation?" do |object|
      [true, false].any?{|bool|bool.equal? object}
    end
  end

  def closed?
    _attrs.frozen?
  end
 
  # @return [Class]
  def to_struct_class
    raise 'No defined members' if members.empty?

    struct_klass = Struct.new(*members)
  
    if name
      tail_name = name.slice(/[^:]+\z/)
      if ::Structus::Structs.const_defined?(tail_name) && 
          ((already = ::Structus::Structs.const_get(tail_name)).members == members)
          already
      else
        ::Structus::Structs.const_set tail_name, struct_klass
      end
    else
      struct_klass
    end
  end

  # @param [Symbol, String, #to_str] name
  def autonym(name)
    name = name.to_sym
    if _attrs.has_key? name
      (linked = _attrs[name]).kind_of?(Symbol) ? linked : name
    else
      raise NameError
    end
  end

  private

  def close
    _attrs.freeze
    self
  end

  def _attrs(name=nil)
    name ? self::MEMBER_DEFINES[autonym name] : self::MEMBER_DEFINES
  end

  def _define_nested_member(name, &block)
    klass = ::Structus.define {instance_exec(&block)}
    const_set name.PascalCase, klass
  end

end

require_relative 'constructor'
