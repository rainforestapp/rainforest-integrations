require 'rails_helper'

describe Integrations::Base do
  describe '#send_event' do
    it 'should be overwritten by child classes' do
      expect do
        Integrations::Base.new('foo', {}, []).send_event
      end.to raise_error
    end
  end
end
