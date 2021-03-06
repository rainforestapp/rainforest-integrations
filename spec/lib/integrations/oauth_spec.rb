# frozen_string_literal: true
require 'rails_helper'

describe Integrations::Oauth do
  class Klass
    include Integrations::Oauth
    attr_accessor :settings, :oauth_consumer

    def initialize
      @settings = { oauth_settings: {} }
      @oauth_consumer = { secrets: { 'RSA-SHA1' => 'consumer secret' } }
    end
  end

  subject { Klass.new }
  let(:required_keys) { described_class::REQUIRED_KEYS }

  before do
    [OAuth::Consumer, OAuth::AccessToken, OpenSSL::PKey::RSA].each do |klass|
      allow(klass).to receive(:new)
    end
  end

  context 'with blank oauth settings' do
    it 'raises Integrations::Error with missing keys' do
      expect do
        subject.oauth_access_token
      end.to raise_error(Integrations::Error)
    end
  end

  context 'with some missing oauth settings' do
    let(:supplied_keys) { required_keys.first(2) }
    let(:missing_keys) { required_keys.drop(2) }
    let(:oauth_settings) do
      {}.tap do |settings|
        supplied_keys.each { |supplied_key| settings[supplied_key] = 'foo' }
      end
    end

    before do
      subject.settings = { oauth_settings: oauth_settings }
    end

    it 'raises Integrations::Error with missing keys' do
      expect do
        subject.oauth_access_token
      end.to raise_exception(Integrations::Error)
    end
  end

  context 'with complete oauth settings' do
    let(:oauth_settings) do
      {}.tap do |settings|
        required_keys.each { |required_key| settings[required_key] = 'foo' }
      end
    end

    before do
      subject.settings = { oauth_settings: oauth_settings }
    end

    it 'does not raise an error' do
      expect do
        subject.oauth_access_token
      end.not_to raise_error
    end
  end
end
