# frozen_string_literal: true
require 'rails_helper'

describe Integrations::Base do
  describe '#send_event' do
    it 'should be overwritten by child classes' do
      expect do
        Integrations::Base.new('foo', {}, []).send_event
      end.to raise_error
    end
  end

  describe '#valid?' do
    before do
      allow(described_class).to receive(:required_settings).and_return(['foo'])
    end

    context 'missing settings' do
      subject { described_class.new('event', {}, []) }
      it { is_expected.to_not be_valid }
    end

    context 'empty settings' do
      subject { described_class.new('event', {}, [{key: 'foo', value: ''}]) }
      it { is_expected.to_not be_valid }
    end

    context 'present settings' do
      subject { described_class.new('event', {}, [{key: 'foo', value: 'val'}]) }
      it { is_expected.to be_valid }
    end
  end
end
