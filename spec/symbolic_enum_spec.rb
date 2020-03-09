# frozen_string_literal: true

RSpec.describe SymbolicEnum do
  it 'has a version number' do
    expect(SymbolicEnum::VERSION).not_to be nil
  end

  context 'checks params structure' do
    after do
      Object.send(:remove_const, :SampleClass)
    end

    it 'should not allow without args' do
      expect {
        class SampleClass
          include SymbolicEnum

          symbolic_enum
        end
      }.to raise_error(ArgumentError)
    end

    it 'should only allow with a Hash' do
      expect {
        class SampleClass
          include SymbolicEnum

          symbolic_enum :field
        end
      }.to raise_error(ArgumentError, 'argument has to be a Hash of field and mapping of unique Symbols to numbers, with optional configuration params')
    end

    it 'should only allow a field and mappings' do
      expect {
        class SampleClass
          include SymbolicEnum

          symbolic_enum field: :value
        end
      }.to raise_error(ArgumentError, 'argument has to be a Hash of field and mapping of unique Symbols to numbers, with optional configuration params')
    end

    it 'should only allow a mapping of symbols to numbers' do
      expect {
        class SampleClass
          include SymbolicEnum

          symbolic_enum field: {
            1 => 'a',
            :x => false,
          }
        end
      }.to raise_error(ArgumentError, 'argument has to be a Hash of field and mapping of unique Symbols to numbers, with optional configuration params')
    end

    it 'should only allow a mapping of unique symbols to unique numbers' do
      expect {
        class SampleClass
          include SymbolicEnum

          symbolic_enum field: {
            foo: 1,
            bar: 1,
          }
        end
      }.to raise_error(ArgumentError, 'argument has to be a Hash of field and mapping of unique Symbols to numbers, with optional configuration params')
    end

    it 'should only allow whitelisted options' do
      expect {
        class SampleClass
          include SymbolicEnum

          symbolic_enum field: {
            foo: 1,
            bar: 2
          }, foo: 2
        end
      }.to raise_error(ArgumentError, "'foo' is not a valid option")
    end

    it 'should not allow enums where setter clashes with existing methods' do
      expect {
        class SampleClass
          include SymbolicEnum

          def foo!
          end

          symbolic_enum field: {
            foo: 1
          }
        end
      }.to raise_error(ArgumentError, "'foo' clashes with existing methods")
    end

    it 'should not allow enums where getter clashes with existing methods' do
      expect {
        class SampleClass
          include SymbolicEnum

          def foo?
          end

          symbolic_enum field: {
            foo: 1
          }
        end
      }.to raise_error(ArgumentError, "'foo' clashes with existing methods")
    end

    it 'should not allow enums where scope clashes with existing methods' do
      expect {
        class SampleClass
          include SymbolicEnum

          def self.foo
          end

          symbolic_enum field: {
            foo: 1
          }
        end
      }.to raise_error(ArgumentError, "'foo' clashes with existing methods")
    end
  end

  context 'mimics Rails enum behaviour for non-array' do
    after do
      Object.send(:remove_const, :SampleClass)
    end

    it 'generates the state map, getter and scopes' do
      class SampleClass; end

      expect(SampleClass).to receive(:scope).with(:abc, instance_of(Proc))
      expect(SampleClass).to receive(:scope).with(:def, instance_of(Proc))

      SampleClass.class_eval do
        include SymbolicEnum

        symbolic_enum state: {
          abc: 1,
          def: 2,
        }
      end

      expect(SampleClass.symbolic_enums).to eq({ state: { abc: 1, def: 2 } })
      expect(SampleClass.states).to eq({ abc: 1, def: 2 })

      a = SampleClass.new

      allow(a).to receive(:[]).and_return(1)
      expect(a.state).to eq :abc
      expect(a).to have_received(:[]).with(:state)

      allow(a).to receive(:"[]=")
      expect {
        a.state = :def
      }.to_not raise_error
      expect(a).to have_received(:"[]=").with(:state, 2)

      expect {
        a.state = :foo
      }.to raise_error(ArgumentError, 'can only assign a valid enum')

      allow(a).to receive(:"[]=")
      allow(a).to receive(:update_attributes!).with({ state: 2 }).and_return(true)
      expect {
        a.def!
      }.to_not raise_error
      expect(a).to have_received(:"[]=").with(:state, 2)
      expect(a).to have_received(:update_attributes!).with(state: 2)

      allow(a).to receive(:[]).and_return(2)
      expect(a.state).to eq :def
      expect(a).to have_received(:[]).with(:state).at_least(:once)
    end
  end

  context 'generates appropriate behaviour for array' do
    after do
      Object.send(:remove_const, :SampleClass)
    end

    it 'generates the state map, getter and scopes' do
      class SampleClass; end

      expect(SampleClass).to receive(:scope).with(:abc, instance_of(Proc))
      expect(SampleClass).to receive(:scope).with(:def, instance_of(Proc))

      SampleClass.class_eval do
        include SymbolicEnum

        symbolic_enum states: {
          abc: 1,
          def: 2,
        }, array: true
      end

      expect(SampleClass.states).to eq({ abc: 1, def: 2 })

      a = SampleClass.new

      allow(a).to receive(:[]).and_return([1, 2])
      expect(a.states.to_set).to eq [:abc, :def].to_set
      expect(a).to have_received(:[]).with(:states).at_least(:once)

      expect {
        a.states = :abc
      }.to raise_error(ArgumentError, 'can only assign a valid array of enums')

      expect {
        a.states = [:foo]
      }.to raise_error(ArgumentError, 'can only assign a valid array of enums')

      allow(a).to receive(:"[]=")
      expect {
        a.states = [:abc, :def]
      }.to_not raise_error
      expect(a).to have_received(:"[]=").with(:states, [1, 2])
    end
  end

  context 'allows disabling of setters, scopes' do
    after do
      Object.send(:remove_const, :SampleClass)
    end

    it 'should allow scopes to be disabled' do
      class SampleClass; end

      expect(SampleClass).to_not receive(:scope)

      SampleClass.class_eval do
        include SymbolicEnum

        symbolic_enum state: {
          foo: 1,
        }, disable_scopes: true
      end

      expect(SampleClass).to_not respond_to(:foo)
    end

    it 'should allow setters to be disabled' do
      class SampleClass; end

      expect(SampleClass).to receive(:scope).with(:foo, instance_of(Proc))

      SampleClass.class_eval do
        include SymbolicEnum

        symbolic_enum state: {
          foo: 1,
        }, disable_setters: true
      end

      expect(SampleClass.new).to_not respond_to(:foo!)
    end
  end
end
