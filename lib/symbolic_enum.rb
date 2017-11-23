require 'symbolic_enum/version'
require 'active_support/concern'
require 'active_support/inflector'

module SymbolicEnum
  extend ActiveSupport::Concern

  module ClassMethods
    def symbolic_enum(params)
      raise ArgumentError.new("argument has to be a Hash of field and mapping of unique Symbols to numbers, with optional configuration params") unless params.is_a?(Hash) && params.keys.count <= 2 && params.keys.count >= 1 && params.keys.first.is_a?(Symbol) && params.values.first.is_a?(Hash)

      field = params.keys.first
      mapping = params[field]

      mapping.keys.each do |enum_name|
        raise ArgumentError.new("'#{enum_name}' clashes with existing methods") if self.instance_methods.include?(:"#{enum_name}!")
        raise ArgumentError.new("'#{enum_name}' clashes with existing methods") if self.instance_methods.include?(:"#{enum_name}?")
        raise ArgumentError.new("'#{enum_name}' clashes with existing methods") if self.singleton_methods.include?(:"#{enum_name}!")
      end

      options = params.reject{ |k,v| k == field }

      raise ArgumentError.new("argument has to be a Hash of field and mapping of unique Symbols to numbers, with optional configuration params") unless mapping.keys.count == mapping.keys.uniq.count && mapping.values.count == mapping.values.uniq.count && mapping.keys.map(&:class).uniq == [Symbol] && (mapping.values.map(&:class).uniq == [Integer] || mapping.values.map(&:class).uniq == [Fixnum])
      options.each_pair do |key, value|
        case key
        when :array
          raise ArgumentError.new("'array' option can be only true/false") unless [true, false].include?(value)
        else
          raise ArgumentError.new("'#{ key }' is not a valid option")
        end
      end

      is_array = options[:array]

      # Replicating enum functionality (partially)
      define_singleton_method("#{ field.to_s.pluralize }") do
        mapping
      end

      reverse_mapping = mapping.map{|v| [v[1],v[0]]}.to_h

      if is_array
        define_method(field) do
          return nil if self[field].nil?

          return self[field].map{ |v| reverse_mapping[v] }
        end
      else
        define_method(field) do
          reverse_mapping[self[field]]
        end
      end

      if is_array
        define_method("#{ field }=") do |value|
          raise ArgumentError.new("can only assign a valid array of enums") unless value.nil? || value.is_a?(Array) && value.map(&:class).uniq == [Symbol] && value.to_set.subset?(mapping.keys.to_set)
          self[field] = value.nil? ? nil : value.map{|s| mapping[s] }
        end
      else
        define_method("#{ field }=") do |value|
          raise ArgumentError.new("can only assign a valid enum") unless value.nil? || mapping.keys.include?(value)
          self[field] = mapping[value]
        end
      end

      mapping.each_pair do |state_name, state_value|
        scope state_name, -> { where(field => state_value) }

        define_method("#{ state_name }?".to_sym) do
          self[field] == state_value
        end

        define_method("#{ state_name }!".to_sym) do
          self.update_attributes!(field => state_value)
        end
      end
    end
  end
end
