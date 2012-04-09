$VERBOSE = true
require_relative 'test_helper'

class TestStructusDefaultValue < Test::Unit::TestCase
  Sth = Structus.new do
    has :lank, is: OR(Bignum, Fixnum), default: 1
  end
  
  def test_default
    sth = Sth.new 2
    assert_equal 2, sth.lank
    sth = Sth.new
    assert_equal 1, sth.lank
    assert_equal true, sth.default?(:lank)
    sth.lank = 2
    assert_equal false, sth.default?(:lank)
  end
  
  def test_define_default    
    klass = Structus.define do
      has :lank2, is: Integer, default: '10'
    end

    assert_raises Validation::InvalidWritingError do
      klass.new
    end
  end
end

class TestStructusAssign < Test::Unit::TestCase
  Sth = Structus.new do
    has :foo
  end  

  def test_unassign
    sth = Sth.new
    assert_equal false, sth.assign?(:foo)
    sth.foo = nil
    assert_equal true, sth.assign?(:foo)
    sth.unassign :foo
    assert_equal false, sth.assign?(:foo)
    sth.foo = nil
    assert_equal true, sth.assign?(:foo)
    sth.clear_at 0
    assert_equal false, sth.assign?(:foo)
    
    assert_raises NameError do
      sth.unassign :var
    end
    
    assert_raises IndexError do
      sth.unassign 1
    end
  end
end

class TestStructusClassLock < Test::Unit::TestCase
  Sth = Structus.new do
    has :foo
  end

  def test_class_lock
    sth = Sth.new

    assert_equal true, sth.member?(:foo)

    Sth.class_eval do
      has :bar
    end

    assert_equal true, sth.member?(:bar)
    assert_equal [:foo, :bar], sth.members
    
    assert_equal false, Sth.closed?
    
    Sth.__send__ :close
    
    assert_equal true, Sth.closed?
   
    assert_raises RuntimeError do
      Sth.class_eval do
        member :var2
      end
    end
   
    assert_equal false, sth.member?(:var2)
  end
end

class TestStructusDefine < Test::Unit::TestCase
  def test_define
    assert_raises RuntimeError do
      Structus.define do
      end
    end
    
    klass = Structus.define do
      member :foo
    end

    assert_equal true, klass.closed?
  end
end

class TestStructusFreeze < Test::Unit::TestCase
  Sth = Structus.new :foo
  
  def test_freeze
    sth = Sth.new
    sth.freeze
    
    assert_raises RuntimeError do
     sth.foo = 8
    end
   
    assert_equal true, sth.frozen?
  end
end


class TestStructusLoadPairs < Test::Unit::TestCase
  Sth = Structus.new :foo, :bar, :hoge
  
  def test_load_pairs
    sth = Sth[hoge: 7, foo: 8]
    assert_equal [8, nil, 7], [sth.foo, sth.bar, sth.hoge]
    assert_equal [8, nil, 7], sth.values
  end
end

class TestStructusObject < Test::Unit::TestCase
  Sth = Structus.new :foo, :bar, :hoge

  def test_hash
    sth1 = Sth[hoge: 7, foo: 8]
    sth2 = Sth[hoge: 7, foo: 8]
    assert_equal true, sth1.eql?(sth2)
    assert_equal true, sth2.eql?(sth1)
    assert_equal sth1.hash, sth2.hash
    assert_equal true, {sth1 => 1}.has_key?(sth2)
    assert_equal true, {sth2 => 1}.has_key?(sth1)
    assert_equal 1, {sth1 => 1}[sth2]
    assert_equal 1, {sth2 => 1}[sth1]
  end
end


class TestStructusAliasMember < Test::Unit::TestCase
  class Sth < Structus.new
    has :foo, is: String
    has :bar, is: Integer, via: ->v{Integer v}, default: '8'
    has :hoge, is: Symbol, default: :'Z'
    alias_member :abc, :bar
  end

  def test_alias_member
    sth = Sth.new 'A'
    assert_equal [:foo, :bar, :hoge], sth.members
    assert_equal 8, sth[:bar]
    assert_equal 8, sth[:abc]
    assert_equal 8, sth.abc
    sth.abc = 5
    assert_equal 5, sth.bar
    sth[:abc] = 6
    assert_equal 6, sth.bar
    
    assert_raises Validation::InvalidAdjustingError do
      sth[:abc] = 'a'
    end
    
    assert_raises Validation::InvalidAdjustingError do
      sth.abc = 'a'
    end
    
    assert_raises Validation::InvalidAdjustingError do
      sth.bar = 'a'
    end
    
    assert_raises NameError do
      Sth.class_eval do
        member :abc
      end
    end
  end
end

class TestStructusSpecificConditions < Test::Unit::TestCase
  Sth = Structus.define do
    has :list_only_int, is: GENERICS(Integer)
    has :true_or_false, is: BOOL?
    has :like_str, is: STRINGABLE?
    has :has_x, is: CAN(:x)
    has :has_x_and_y, is: CAN(:x, :y)
    has :one_of_member, is: MEMBER_OF([1, 3])
    has :has_ignore, is: AND(1..5, 3..10)
    has :nand, is: NAND(1..5, 3..10)
    has :all_pass, is: OR(1..5, 3..10)
    has :catch_error, is: CATCH(NoMethodError){|v|v.no_name!}
    has :no_exception, is: QUIET(->v{v.class})
    has :not_integer, is: NOT(Integer)
  end

  def test_not
    sth = Sth.new
    
    obj = Object.new
    
    sth.not_integer = obj
    assert_same obj, sth.not_integer

    assert_raises Validation::InvalidWritingError do
      sth.not_integer = 1
    end
  end


  def test_still
    sth = Sth.new
    
    obj = Object.new
    
    sth.no_exception = obj
    assert_same obj, sth.no_exception
    sth.no_exception = false

    obj.singleton_class.class_eval do
      undef_method :class
    end

    assert_raises Validation::InvalidWritingError do
      sth.no_exception = obj
    end
  end

  def test_catch
    sth = Sth.new
    
    obj = Object.new
    
    sth.catch_error = obj
    assert_same obj, sth.catch_error
    sth.catch_error = false

    obj.singleton_class.class_eval do
      def no_name!
      end
    end

    assert_raises Validation::InvalidWritingError do
      sth.catch_error = obj
    end
  end

  def test_or
    sth = Sth.new

    assert_raises Validation::InvalidWritingError do
      sth.all_pass = 11
    end
    
    sth.all_pass = 1
    assert_equal 1, sth.all_pass
    sth.all_pass = 4
    assert_equal 4, sth.all_pass
    assert_equal true, sth.valid?(:all_pass)
  end

  def test_and
    sth = Sth.new

    assert_raises Validation::InvalidWritingError do
      sth.has_ignore = 1
    end

    assert_raises Validation::InvalidWritingError do
      sth.has_ignore= 2
    end
  
    sth.has_ignore = 3
    assert_equal 3, sth.has_ignore
    assert_equal true, sth.valid?(:has_ignore)
    
    assert_raises Validation::InvalidWritingError do
      sth.has_ignore = []
    end
  end

  def test_nand
    sth = Sth.new

    assert_raises Validation::InvalidWritingError do
      sth.nand = 4
    end

    assert_raises Validation::InvalidWritingError do
      sth.nand = 4.5
    end
  
    sth.nand = 2
    assert_equal 2, sth.nand
    assert_equal true, sth.valid?(:nand)
    sth.nand = []
    assert_equal [], sth.nand
  end



  def test_member_of
    sth = Sth.new
    
    assert_raises Validation::InvalidWritingError do
      sth.one_of_member = 4
    end
  
    sth.one_of_member = 3
    assert_equal 3, sth.one_of_member
    assert_equal true, sth.valid?(:one_of_member)
  end
  
  def test_generics
    sth = Sth.new
    
    assert_raises Validation::InvalidWritingError do
      sth.list_only_int = [1, '2']
    end
  
    sth.list_only_int = [1, 2]
    assert_equal [1, 2], sth.list_only_int
    assert_equal true, sth.valid?(:list_only_int)
    sth.list_only_int = []
    assert_equal [], sth.list_only_int
    assert_equal true, sth.valid?(:list_only_int)
    sth.list_only_int << '2'
    assert_equal false, sth.valid?(:list_only_int)
  end
  
  def test_boolean
    sth = Sth.new
    
    assert_raises Validation::InvalidWritingError do
      sth.true_or_false = nil
    end
    
    assert_equal false, sth.valid?(:true_or_false)
  
    sth.true_or_false = true
    assert_equal true, sth.true_or_false
    assert_equal true, sth.valid?(:true_or_false)
    sth.true_or_false = false
    assert_equal false, sth.true_or_false
    assert_equal true, sth.valid?(:true_or_false)
  end
  
  def test_stringable
    sth = Sth.new
    obj = Object.new
    
    assert_raises Validation::InvalidWritingError do
      sth.like_str = obj
    end
  
    sth.like_str = 'str'
    assert_equal true, sth.valid?(:like_str)
    sth.like_str = :sym
    assert_equal true, sth.valid?(:like_str)
    
    obj.singleton_class.class_eval do
      def to_str
      end
    end
    
    sth.like_str = obj
    assert_equal true, sth.valid?(:like_str)
  end

  def test_responsible_arg1
    sth = Sth.new
    obj = Object.new
    
    assert_raises Validation::InvalidWritingError do
      sth.has_x = obj
    end
    
    obj.singleton_class.class_eval do
      def x
      end
    end
    
    sth.has_x = obj
    assert_equal obj, sth.has_x
    assert_equal true, sth.valid?(:has_x)
  end

  def test_responsible_arg2
    sth = Sth.new
    obj = Object.new
    
    assert_raises Validation::InvalidWritingError do
      sth.has_x_and_y = obj
    end
    
    obj.singleton_class.class_eval do
      def x
      end
    end
    
    assert_raises Validation::InvalidWritingError do
      sth.has_x_and_y = obj
    end
    
    obj.singleton_class.class_eval do
      def y
      end
    end
    
    sth.has_x_and_y = obj
    assert_equal obj, sth.has_x_and_y
    assert_equal true, sth.valid?(:has_x_and_y)
  end
end


class TestStructusLock < Test::Unit::TestCase
  Sth = Structus.new :foo, :bar
  Sth.__send__ :close
  
  def test_lock
    sth = Sth.new
    assert_equal false, sth.locked?(:foo)
    assert_equal false, sth.locked?(:bar)
    assert_equal false, sth.secure?
    sth.lock! :bar
    assert_equal true, sth.locked?(:bar)
    assert_equal false, sth.secure?
  
    assert_raises RuntimeError do
     sth.bar = 1
    end
   
    sth.__send__ :unlock, :bar
    
    assert_equal false, sth.locked?(:bar)
    
    sth.bar = 1
    assert_equal 1, sth.bar
    
    sth.lock!
    assert_equal true, sth.locked?(:foo)
    assert_equal true, sth.locked?(:bar)
    assert_equal true, sth.locked?
    
    assert_raises RuntimeError do
      sth.foo = 1
    end
    
    assert_equal true, sth.secure?
  end
end

class TestStructusInherit < Test::Unit::TestCase
  Sth = Structus.define do
    has :foo, is: String
    has :bar, is: OR(nil, Fixnum)
  end
  
  class SubSth < Sth
    has :hoge, is: OR(nil, 1..3)
  end
  
  class SubSubSth < SubSth
    has :rest, is: AND(/\d/, Symbol)
  end
  
  def test_inherit
    assert_equal [*Sth.members, :hoge], SubSth.members
    sth = Sth.new
    substh = SubSth.new

    assert_raises Validation::InvalidWritingError do
      substh.bar = 'str'
    end
    
    assert_raises Validation::InvalidWritingError do
      substh.hoge = 4
    end
    
    assert_raises NoMethodError do
      sth.hoge = 3
    end
    
    assert_raises NoMethodError do
      substh.rest = :a4
    end
    
    subsubsth = SubSubSth.new
    
    assert_raises Validation::InvalidWritingError do
      subsubsth.rest = 4
    end
    
    subsubsth.rest = :a4
    
    assert_equal :a4, subsubsth[:rest]
    
    assert_equal true, Sth.__send__(:closed?)
    assert_equal false, SubSth.__send__(:closed?)
    SubSth.__send__(:close)
    assert_equal true, SubSth.__send__(:closed?)
    assert_equal false, SubSubSth.__send__(:closed?)
    SubSubSth.__send__(:close)
    assert_equal true, SubSubSth.__send__(:closed?)
  end
end

class TestStructusEnum < Test::Unit::TestCase
  Sth = Structus.define do
    member :name
    member :age
  end

  def test_each_pair
    sth = Sth.new 'a', 10
    assert_same sth, sth.each_pair{}
    
    enum = sth.each_pair
    assert_equal [:name, 'a'], enum.next
    assert_equal [:age, 10], enum.next
    assert_raises StopIteration do
      enum.next
    end
  end
 
  def test_each_pair_with_index
    sth = Sth.new 'a', 10
    assert_same sth, sth.each_pair_with_index{}
    
    enum = sth.each_pair_with_index
    assert_equal [:name, 'a', 0], enum.next
    assert_equal [:age, 10, 1], enum.next
    assert_raises StopIteration do
      enum.next
    end
  end
end

class TestStructus_to_Struct < Test::Unit::TestCase
  Sth = Structus.define do
    has :name, is: String
    has :age, is: Integer
  end
  
  def test_to_struct_class
    klass = Sth.to_struct_class
    assert_equal 'Structus::Structs::Sth', klass.to_s
    assert_same klass, Sth.to_struct_class
    assert_kind_of Struct, Sth.new.to_struct
    assert_kind_of Structus::Structs::Sth, Sth.new.to_struct
    
    assert_raises RuntimeError do
      Structus.new.new.to_struct
    end
    
    Structus.new(:a, :b, :c).new.to_struct
    assert_equal 1, Structus::Structs.constants.length
  end
end

class TestStructusFlavors < Test::Unit::TestCase
  class MyClass
    def self.parse(v)
      raise unless /\A[a-z]+\z/ =~ v
      new
    end
  end
  
  Sth = Structus.define do
    has :chomped, is: AND(Symbol, /[^\n]\z/),
    via: WHEN(String, ->v{v.chomp.to_sym})
    has :no_reduced, is: Symbol, via: ->v{v.to_sym}
    has :reduced, is: Symbol, via: INJECT(->v{v.to_s}, ->v{v.to_sym})
    has :integer, is: Integer, via: PARSE(Integer)
    has :myobj, is: ->v{v.instance_of? MyClass}, via: PARSE(MyClass)
  end
  
  def test_WHEN
    sth = Sth.new
    
    assert_raises Validation::InvalidWritingError do
      sth.chomped = :"a\n"
    end
    
    sth.chomped = "a\n"
    
    assert_equal :a, sth.chomped
    
    sth.chomped = :b
    assert_equal :b, sth.chomped
  end

  def test_INJECT
    sth = Sth.new
    
    assert_raises Validation::UnmanagebleError do
      sth.no_reduced = 1
    end
    
    sth.reduced = 1
    
    assert_equal :'1', sth.reduced
  end
  
  def test_PARSE
    sth = Sth.new
    
    assert_raises Validation::UnmanagebleError do
      sth.integer = '1.0'
    end
    
    sth.integer = '1'
    
    assert_equal 1, sth.integer
    
    assert_raises Validation::UnmanagebleError do
      sth.myobj = '1'
    end
    
    sth.myobj = 'a'
    
    assert_kind_of MyClass, sth.myobj
  end
end

class TestNestedDefine < Test::Unit::TestCase
  Bank = Structus.define {
    have :record

    have :account do
      have :person do
        have :name, is: String
        have :age, is: Integer
      end
      
      have :service do
        have :name, is: Symbol
        have :lank, is: 1..10, default: 3
      end
    end
  }

  def test_nested
    bank = Bank.new
    assert_equal [:record, :account], bank.members
    assert_equal [:MEMBER_DEFINES, :Account], Bank.constants(false)
    assert_equal [:MEMBER_DEFINES, :Person, :Service],
    Bank::Account.constants(false)
    assert_raises Validation::InvalidWritingError do
      bank.account.person.age = 'a'
    end
  end
end
