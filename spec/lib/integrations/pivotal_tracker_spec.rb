require 'rails_helper'
require 'integrations'

describe Integrations::PivotalTracker do
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
        failed_tests: [
          {
            id: "20",
            name: "Always fails",
            url: "http://www.rainforestqa.com/"
          }
        ]
      }
    end
    let(:settings) do
      [
        {
          key: 'project_id',
          value: '1141528'
        },
        {
          key: 'api_token',
          value: '8537292c903ca580bcd10b800709a136'
        }
      ]
    end
    let(:expected_message) { "Your Rainforest Run (Run #9: rainforest run - http://www.rainforestqa.com/) failed. Time to finish: 12 minutes 30 seconds" }
    let(:expected_url) { "https://www.pivotaltracker.com/services/v5/projects/#{settings.first[:value]}/stories" }
    let(:expected_description) do
      "Failed Tests:\n#{payload[:failed_tests][0][:title]}: #{payload[:failed_tests][0][:frontend_url]}\n"
    end
    let(:expected_params) do
      {
        body: {
          name: expected_message,
          description: expected_description,
          story_type: "bug",
          labels: [{ name: "rainforest" }]
        }.to_json,
        headers: {
          "X-TrackerToken" => "#{settings.last[:value]}",
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      }
    end

    subject { described_class.new(event_type, payload, settings) }

    it "sends a correctly formatted request" do
      expect(HTTParty).to receive(:post).with(expected_url, hash_including(:body, :headers)).and_call_original
      VCR.use_cassette('generic_pivotal_tracker_notification') do
        expect{ subject.send_event }.to_not raise_error
      end
    end

    context "with wrong project ID" do
      before do
        settings.first[:value] = 1337
      end

      it "returns a user configuration error" do
        VCR.use_cassette('pivotal_tracker_wrong_id') do
          expect{ subject.send_event }.to raise_error Integrations::Error
        end
      end
    end

    context "with invalid authorization token" do
      before do
        settings.last[:value] = "foobar"
      end

      it "returns a user configuration error" do
        VCR.use_cassette('pivotal_tracker_wrong_auth_token') do
          expect{ subject.send_event }.to raise_error Integrations::Error
        end
      end
    end

    context "with event that requires no separate description" do
      let(:event_type) { "run_error" }

      before do
        payload[:run][:error_reason] = "This is a test error"
      end

      it "receives a 200 response from API" do
        VCR.use_cassette('pivotal_tracker_no_description') do
          expect{ subject.send_event }.to_not raise_error
        end
      end
    end
  end
end
