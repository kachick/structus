require_relative 'class/class'
require_relative 'instance/instance'

class Structus; class << self
  # @group Constructor
  
  alias_method :new_instance, :new
  private :new_instance
  
  # @param [Symbol, String] *names
  # @return [Class] - with Subclass, Subclass:Eigen
  def new(*names, &block)
    ::Class.new(self) {
      names.each do |name|
        member name
      end

      class_eval(&block) if block_given?
    }
  end

  # @yieldreturn [Class] (see Structus.new) - reject floating class
  # @return [void]
  def define(&block)
    raise ArgumentError, 'must with block' unless block_given?

    new(&block).tap {|subclass|
      subclass.instance_eval do
        raise 'not yet finished' if members.empty?
        close
      end
    }
  end

  # @groupend

  private
  
  alias_method :original_inherited, :inherited 

  def inherited(subclass)
    eigen = self

    subclass.class_eval do
      original_inherited subclass

      if eigen.equal? ::Structus
        extend  ::Structus::Class
        include ::Structus::Instance
        attrs = {}
      else
        attrs = eigen::MEMBER_DEFINES.dup
      end

      const_set :MEMBER_DEFINES, attrs
    end
  end

end; end
