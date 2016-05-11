# frozen_string_literal: true
require 'rails_helper'
require 'integrations'

describe Integrations::HipChat do
  describe '#send_event' do
    let(:event_type) { 'run_completion' }
    let(:payload) do
      {
        run: {
          id: 9,
          state: 'failed',
          description: 'rainforest run',
          time_taken: 750
        },
        frontend_url: 'http://www.rainforestqa.com/',
        failed_tests: {
          name: 'Always fails'
        }
      }
    end
    let(:settings) do
      [
        {
          key: 'room_id',
          value: 'Rainforestqa'
        },
        {
          key: 'room_token',
          value: 'SFLaaWu13VxCd7ew4FqNnNJeCcoAZ8MF4kofX3GZ'
        }
      ]
    end
    let(:expected_message) { 'Your Rainforest Run (<a href="http://www.rainforestqa.com/">Run #9: rainforest run</a>) failed. Time to finish: 12 minutes 30 seconds' }
    let(:expected_url) { "https://api.hipchat.com/v2/room/#{settings.first[:value]}/notification" }
    let(:expected_params) do
      {
        body: {
          color: 'red',
          message: expected_message,
          notify: true,
          message_format: 'html'
        }.to_json,
        headers: {
          'Authorization' => "Bearer #{settings.last[:value]}",
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      }
    end
    let(:fake_room) { instance_double('HipChat::Room') }

    subject { described_class.new(event_type, payload, settings) }

    before do
      allow(HipChat::Room).to receive(:new).and_return(fake_room)
      allow(fake_room).to receive(:send).and_return(true)
    end

    it 'sets up room with all the proper options' do
      expect(HipChat::Room).to receive(:new).with(
        settings.last[:value],
        room_id: settings.first[:value],
        api_version: 'v2',
        server_url: 'https://api.hipchat.com'
      ).and_return(fake_room)
      expect(subject.send_event).to be_truthy
    end

    context 'with room ID' do
      before do
        expect(fake_room).to receive(:send).and_raise(HipChat::ServiceError)
      end

      it 'returns a user configuration error' do
        expect { subject.send_event }.to raise_error(Integrations::Error)
      end
    end

    context 'with a blank room token or room id' do
      let(:settings) do
        [
          {
            key: 'room_id',
            value: ''
          },
          {
            key: 'room_token',
            value: ''
          }
        ]
      end

      it 'does not send the message' do
        expect(fake_room).to_not receive(:send)

        subject.send_event
      end
    end
  end
end
