module Structura::Class
  # @group Use Only Inner

  private

  def _attrs(name)
    self::MEMBER_DEFINES[name]
  end

  def _names
    self::MEMBER_DEFINES.keys
  end
  
  def _alias_member(aliased, original)
    self::MEMBER_DEFINES[aliased] = original
    _attrs[original][:aliases] << aliased
  end
  
  def _original_for(aliased)
    self::MEMBER_DEFINES[aliased]
  end

  def _aliases_for(original)
    _attrs[original][:aliases]
  end

  def _remove_inference(name)
    _attrs(name).delete :inference
  end
  
  def _mark_setter_validation(name)
    _attrs(name)[:setter_validation] = true
  end

  def _mark_getter_validation(name)
    _attrs(name)[:getter_validation] = true
  end

  def _mark_inference(name)
    _attrs(name)[:inference]= true
  end
  
  def _set_flavor(name, flavor)
    @flavors[name] = flavor
  end
  
  def _set_condition(name, condition)
    @conditions[name] = condition
  end
  
  def _set_default_value(name, value)
    @defaults[name] = value
  end

  # @param [Symbol, String, #to_sym, #to_str] name
  def originalkey_for(name)
    name = keyable_for name
    
    if _names.include? name
      name
    else
      if original = _original_for(name)
        original
      else
        raise NameError, "not defined member for #{name}"
      end
    end
  end

  # @param [Symbol, String, #to_sym, #to_str] name
  # @return [Symbol] name(keyable)
  def keyable_for(name)
    return name if name.instance_of? Symbol

    r = (
      case name
      when Symbol, String
        name.to_sym
      else
        case
        when name.respond_to?(:to_sym)
          name.to_sym
        when name.respond_to?(:to_str)
          name.to_str.to_sym
        else
          raise TypeError
        end
      end
    )

    if r.instance_of? Symbol
      r
    else
      raise 'must not happen'
    end
  end

  # @param [Symbol] name
  # @return [void]
  # @yieldreturn [Boolean]
  def _check_safety_naming(name)
    estimation = _estimate_naming name
    risk    = NAMING_RISKS[estimation]
    plevels = PROTECT_LEVELS[@protect_level]
    caution = "undesirable naming '#{name}', because #{estimation}"

    r = (
      case
      when risk >= plevels[:error]
        raise NameError, caution unless block_given?
        false
      when risk >= plevels[:warn]
        warn caution unless block_given?
        false
      else
        true
      end
    )

    yield r if block_given?
  end
  
  # @param [Symbol] name
  # @return [Symbol]
  def _estimate_naming(name)
    if (instance_methods + private_instance_methods).include? name
      return :conflict
    end

    return :no_ascii unless name.encoding.equal? Encoding::ASCII

    case name
    when /[\W]/, /\A[^a-zA-Z_]/, :''
      :no_identifier
    when /\Aeach/, /\A__[^_]*__\z/, /\A_[^_]*\z/, /[!?]\z/, /\Ato_/
      :bad_manners
    when /\A[a-zA-Z_]\w*\z/
      :strict
    else
      raise 'must not happen'
    end
  end

  def __getter__!(name) 
    define_method name do
      __get__ name
    end
    
    nil
  end

  def __setter__!(name, condition, &flavor)
    __set_condition__! name, condition unless Validation::Condition::ANYTHING.equal? condition
    __set_flavor__! name, &flavor if block_given?

    define_method "#{name}=" do |value|
        __set__ name, value
    end
 
    nil

  end
  
  def __set_condition__!(name, condition)
    if ::Validation.conditionable? condition
      _set_condition name, condition
    else
      raise TypeError, 'wrong object for condition'
    end
 
    nil
  end

  def __set_flavor__!(name, &flavor)
    if ::Validation.adjustable? flavor
      _set_flavor name, flavor
    else
      raise ArgumentError, "wrong number of block argument #{arity} for 1"
    end
 
    nil
  end

  def __found_family__!(_caller, name, our)
    family = our.class

    raise 'must not happen' unless name.instance_of?(Symbol) and
                                   inference?(name) and
                                   member?(name) and
                                   _caller.instance_of?(self)

    raise ArgumentError unless Validation.conditionable? family

    _set_condition name, family
    _remove_inference name

    nil
  end
  
  def _condition_for(name)
    @conditions[name]
  end
  
  # @param [Symbol, String] name
  def condition_for(name)
    _condition_for originalkey_for(keyable_for name)
  end
  
  def _flavor_for(name)
    @flavors[name]
  end

  # @param [Symbol, String] name
  def flavor_for(name)
    _flavor_for originalkey_for(keyable_for name)
  end
  
  def _default_for(name)
    @defaults[name]
  end

  # @endgroup
end
