describe Integrations::Settings do
  subject { described_class.new(settings_array) }
  let(:settings_array) { [{key: 'foo', value: 'bar'}] }

  describe '#keys' do
    let(:settings_array) do
      [
        {key: 'foo'},
        {key: 'bar', value: ''},
        {key: 'baz', value: 'val'}
      ]
    end

    it 'does not return key values that are nil' do
      expect(subject.keys).to_not include('foo')
    end

    it 'does not return key values that are empty' do
      expect(subject.keys).to_not include('bar')
    end

    it 'does return key values that are present' do
      expect(subject.keys).to include('baz')
    end
  end

  describe '#to_s' do
    # asserting for logging purposes
    it 'returns the inspect value of the settings instance variable' do
      expect(subject.to_s).to eq(settings_array.inspect)
    end
  end
end
