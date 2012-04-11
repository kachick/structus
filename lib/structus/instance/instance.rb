module Structus::Instance
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

  def_delegators :'self.class',
  :members, :keys, :length, :size,
  :has_member?, :member?, :has_key?, :key?, :_attrs,
  :has_condition?, :restrict?, :has_default?, :has_adjuster?

  private :_attrs
  
  def_delegators :@_db, :hash, :has_value?, :value?, :empty?

  def_wrapped_enums :'self.class', :each_key, :each_index

  def each_member(&block)
    return to_enum(__method__) unless block_given?
    self.class.each_member(&block)
    self
  end

  def initialize(*values)
    @_db, @_locks = {}, {}
    _replace_values(*values)
  end

  def values
    members.map{|name|@_db[name]}
  end

  alias_method :to_a, :values

  # @param [Symbol, String] name
  def assign?(name)
    @_db.has_key? name.to_sym
  end
 
  # @param [Symbol, String, Fixnum] key
  def unassign(key)
    _subscript(key) {|name|@_db.delete name}
  end

  alias_method :clear_at, :unassign
 
  # @param [Symbol, String] name
  def default?(name)
    _attrs(name)[:default] == self[name]
  end
  
  # @return [Struct]
  def to_struct
    self.class.to_struct_class.new(*values)
  end

  # @return [Boolean]
  def ==(other)
    _compare other, :==
  end

  alias_method :===, :==
  
  def eql?(other)
    _compare other, :eql?
  end

   # @return [String]
  def inspect
    "#<#{self.class} (Structus)".tap {|s|
      each_pair do |name, value|
        suffix = (has_default?(name) && default?(name)) ? '(default)' : nil
        s << " #{name}=#{value.inspect}#{suffix}"
      end
      
      s << ">"
    }
  end

  # @return [String]
  def to_s
    "#<structus #{self.class}".tap {|s|
      each_pair do |name, value|
        s << " #{name}=#{value.inspect}"
      end
      
      s << '>'
    }
  end

  alias_method :to_a, :values

  # @return [Hash]
  def to_h(reject_no_assign=false)
    return @_db.dup if reject_no_assign

    {}.tap {|h|
      each_pair do |key, value|
        h[key] = value
      end
    }
  end

  # @param [Fixnum, Range] *keys
  # @return [Array]
  def values_at(*_keys)
    [].tap {|r|
      _keys.each do |key|
        case key
        when Fixnum
          r << self[key]
        when Range
          key.each do |n|
            raise TypeError unless n.instance_of? Fixnum
            r << self[n]
          end
        else
          raise TypeError
        end
      end
    }
  end

  # @param [Symbol, String, Fixnum] key
  def [](key)
    _subscript(key) {|name|_get! name}
  end
  
  # @param [Symbol, String, Fixnum] key
  # @param [Object] value
  # @return [value]
  def []=(key, value)
    _subscript(key) {|name|_set! name, value}
  end

  def freeze
    close
    super
  end

  def each_value
    return to_enum(__method__) unless block_given?
    each_member{|name|yield self[name]}
  end

  alias_method :each, :each_value

  def each_pair
    return to_enum(__method__) unless block_given?
    each_member{|name|yield name, self[name]}
    self
  end

  def each_pair_with_index
    return to_enum(__method__) unless block_given?

    index = 0
    each_pair do |name, value|
      yield name, value, index
      index += 1
    end

    self
  end

  # @param [Symbol, String] name
  # @param [Object] value - no argument and use own
  # passed under any condition
  def valid?(name, value=self[name.to_sym])
    restrict?(name) ? _valid?(_attrs(name)[:is], value) : true
  end

  # true if all members passed under specific condition
  def strict?
    each_member.all?{|name|valid? name}
  end
  
  def secure?
    (frozen? || locked?) && self.class.closed? && strict?
  end

  def lock!(key=true)
    raise "can't modify frozen #{self.class}" if frozen?
    
    if key.equal? true
      members.each do |name|
        @_locks[name] = true
      end
    else
      _subscript(key){|name|@_locks[name] = true}
    end

    self
  end

  def locked?(key=true)
    if key.equal? true
      members.all?{|name|@_locks[name]}
    else
      _subscript(key) {|name|@_locks[name] || false}
    end
  end
  
  private
  
  def initialize_copy(original)
    @_db, @_locks = @_db.dup, {}
  end

  def unlock(key=true)
    raise "can't modify frozen #{self.class}" if frozen?
    
    if key.equal? true
      @_locks.clear
    else
      _subscript(key) {|name|@_locks.delete name}
    end

    self
  end

  def close
    [@_db, @_locks].each(&:freeze).freeze
    self
  end

  def _get!(name)
    ret = @_db[name]
    attrs = _attrs name

    if restrict?(name) and attrs[:reader_validation] and
       !_valid?(attrs[:is], ret)
      raise ::Validation::InvalidReadingError,
      "#{ret.inspect} is deficient for #{name} in #{self.class}"
    else
      ret
    end
  end

  def _set!(name, value)
    attrs = _attrs name
    raise "can't modify frozen #{self.class}" if frozen?
    raise "can't modify locked member #{name}" if locked? name

    if adjuster = attrs[:via]
      begin
        value = instance_exec value, &adjuster
      rescue Exception
        raise ::Validation::UnmanagebleError
      end
    end

    if restrict?(name) and attrs[:writer_validation] and
        !_valid?(attrs[:is], value)
      raise ::Validation::InvalidWritingError,
            "#{value.inspect} is deficient for #{name} in #{self.class}"
    end

    @_db[name] = value
  end

  def _replace_values(*values)
    unless values.size <= size
      raise ArgumentError, "struct size differs (max: #{size})"
    end

    values.each_with_index do |value, index|
      self[index] = value
    end
      
    excess = members.last(size - values.size)
      
    excess.each do |name|
      if has_default?(name)
        default = _attrs[name][:default]
        self[name] = default.kind_of?(Proc) ? default.call : default
      end
    end
  end

  # @param [Symbol] method
  def _compare(other, method)
    instance_of?(other.class) && \
    each_pair.all?{|k, v|v.__send__ method, other[k]}
  end

  
  def _subscript(key)
    case key
    when Symbol, String
      key = key.to_sym
      if _attrs.has_key? key
        attrs = _attrs[key]
        yield attrs.kind_of?(Symbol) ? attrs : key
      else
        raise NameError
      end
    when Fixnum
      if name = members[key]
        yield name
      else
        raise IndexError
      end
    else
      raise ArgumentError
    end
  end

end
