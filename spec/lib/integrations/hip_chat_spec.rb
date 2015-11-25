require 'rails_helper'
require 'integrations'

describe Integrations::HipChat do
  describe '#send_event' do
    let(:event_type) { "run_completion" }
    let(:payload) do
      {
        run: {
          id: 9,
          state: "failed",
          description: "rainforest run",
          time_taken: 750
        },
        frontend_url: "http://www.rainforestqa.com/",
        failed_tests: {
          name: "Always fails"
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
    let(:expected_message) { "Your Rainforest Run (<a href=\"http://www.rainforestqa.com/\">Run #9: rainforest run</a>) failed. Time to finish: 12 minutes 30 seconds" }
    let(:expected_url) { "https://api.hipchat.com/v2/room/#{settings.first[:value]}/notification" }
    let(:expected_params) do
      {
        body: {
          color: "red",
          message: expected_message,
          notify: true,
          message_format: "html"
        }.to_json,
        headers: {
          "Authorization" => "Bearer #{settings.last[:value]}",
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      }
    end

    subject { described_class.new(event_type, payload, settings) }

    it "sends a correctly formatted request" do
      expect(HTTParty).to receive(:post).with(expected_url, hash_including(:body, :headers)).and_call_original
      VCR.use_cassette('generic_hip_chat_notification') do
        expect(subject.send_event).to be_truthy
      end
    end

    context "with room ID" do
      before do
        settings.first[:value] = "Rainforestqafakeroom"
      end

      it "returns a user configuration error" do
        VCR.use_cassette('hip_chat_wrong_room_id') do
          expect{ subject.send_event }.to raise_error Integrations::Error
        end
      end
    end

    context "with invalid authorization token" do
      before do
        settings.last[:value] = "foobar"
      end

      it "returns a user configuration error" do
        VCR.use_cassette('hip_chat_wrong_auth_token') do
          expect{ subject.send_event }.to raise_error Integrations::Error
        end
      end
    end
  end
end
