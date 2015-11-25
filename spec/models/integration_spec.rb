require 'rails_helper'

describe Integration do
  let(:key) { 'slack' }

  describe '.find' do
    subject { Integration.find(key) }

    context 'with a valid key' do
      it 'returns a hash with the integration schema data' do
        expect(subject).to be_a Hash
        expect(subject['key']).to eq 'slack'
        expect(subject['title']).to eq 'Slack'
        expect(subject['settings'].first).to eq({
                                                       'title' => 'Slack webhook URL',
                                                       'key' => 'url',
                                                       'required' => true
                                                     })
      end
    end

    context 'with an invalid key' do
      let(:key) { 'borland' }

      it 'raises an Integration::NotFound error' do
        expect { subject }.to raise_error Integration::NotFound
      end
    end
  end

  describe '.exists?' do
    subject { Integration.exists? key }

    context 'with a valid key' do
      it { is_expected.to be true }
    end

    context 'with an invalid key' do
      let(:key) { 'borland' }

      it { is_expected.to be false }
    end
  end

  describe '.supported_integrations' do
    let(:all_integrations) do
      {
        'slack' => { 'title' => 'Slack', 'settings' => [] },
        'hipchat' => { 'title' => 'HipChat', 'settings' => [] }
      }
    end

    let(:expected_result) do
      [
        { 'key' => 'slack', 'title' => 'Slack', 'settings' => [] },
        { 'key' => 'hipchat', 'title' => 'HipChat', 'settings' => [] }
      ]
    end

    subject { Integration.supported_integrations }

    before do
      stub_const 'Integration::INTEGRATIONS', all_integrations
    end

    it 'returns all of the supported integrations' do
      expect(subject).to eq expected_result
    end
  end
end
