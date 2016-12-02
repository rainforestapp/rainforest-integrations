# frozen_string_literal: true
require 'rails_helper'

describe Integrations::PivotalTracker do
  subject { described_class.new(event_type, payload, settings, oauth_consumer) }

  let(:event_type) { 'run_test_failure' }
  let(:oauth_consumer) { {} }
  let(:project_id) { '12345' }
  let(:api_token) { 'foobarbaz' }
  let(:base_url) { "#{described_class::PIVOTAL_API_URL}/projects/#{project_id}" }
  let(:payload) do
    {
      run: {
        id: 3,
        status: 'failed',
        description: 'Contains a test that always fails',
        environment: {
          name: 'Testing Env'
        }
      },
      failed_test: failed_test,
      frontend_url: 'http://www.rainforestqa.com/'
    }
  end
  let(:settings) do
    [
      { key: 'project_id', value: project_id },
      { key: 'api_token', value: api_token }
    ]
  end
  let(:failed_test) do
    {
      id: '20',
      title: 'Always fails'
    }
  end
  let(:stories_queried) { [] }
  let(:query_response) do
    # NOTE: response body is nested because of omitted meta-data
    {
      status: 200,
      body: { stories: { stories: stories_queried } }.to_json
    }
  end

  describe '#send_event' do
    before do
      stub_request(:get, "#{base_url}/search")
        .with(query: hash_including(:query))
        .to_return(query_response)
    end

    context 'with an unsupported event type' do
      let(:event_type) { 'run_completion' }

      it 'returns without doing anything' do
        expect_any_instance_of(described_class).to_not receive(:create_story)
        expect_any_instance_of(described_class).to_not receive(:update_story)
        subject.send_event
      end
    end

    context 'when there is an authentication error' do
      let(:query_response) { {status: 403} }

      it 'raises a Integrations::Error' do
        expect { subject.send_event }.to raise_error(Integrations::Error)
      end
    end

    context 'the project id is incorrect' do
      let(:query_response) { {status: 404} }

      it 'raises a Integrations::Error' do
        expect { subject.send_event }.to raise_error(Integrations::Error)
      end
    end

    context 'for any other error' do
      let(:query_response) { {status: 500} }

      it 'raises a Integrations::Error' do
        expect { subject.send_event }.to raise_error(Integrations::Error)
      end
    end

    context 'when no matching stories are found' do
      let(:new_story_url) { "#{base_url}/stories" }
      before do
        stub_request(:post, new_story_url)
          .with(body: instance_of(String))
          .to_return(status: 200)
      end

      context 'run_test_failure' do
        it 'posts useful information in the story' do
          subject.send_event
          expect(WebMock).to have_requested(:post, new_story_url).with { |req|
            body = Rack::Utils.parse_nested_query(req.body).with_indifferent_access
            expect(body[:name]).to include(failed_test[:title])
            expect(body[:description]).to include(failed_test[:title], payload[:frontend_url])
            expect(body[:story_type]).to eq('bug')
            expect(body[:labels]).to eq(["RfTest#{failed_test[:id]}"])
            expect(body[:comments].first).to eq('text' => "Environment: #{payload[:run][:environment][:name]}")
          }
        end
      end

      context 'webhook_timeout' do
        let(:event_type) { 'webhook_timeout' }

        it 'posts useful information' do
          subject.send_event
          expect(WebMock).to have_requested(:post, new_story_url).with { |req|
            body = Rack::Utils.parse_nested_query(req.body).with_indifferent_access
            run = payload[:run]
            expect(body[:name]).to eq('Your Rainforest webhook has timed out')
            expect(body[:description]).to include(run[:description], run[:id].to_s)
            expect(body[:story_type]).to eq('bug')
            expect(body[:labels]).to eq(["RfRun#{run[:id]}"])
            expect(body[:comments].first).to eq('text' => "Environment: #{run[:environment][:name]}")
          }
        end
      end

      context 'integration_test' do
        let(:event_type) { 'integration_test' }

        it 'posts useful information' do
          subject.send_event
          expect(WebMock).to have_requested(:post, new_story_url).with { |req|
            body = Rack::Utils.parse_nested_query(req.body).with_indifferent_access
            run = payload[:run]
            expect(body[:name]).to eq('Integration Test')
            expect(body[:description]).to eq 'Your slack integration works!'
            expect(body[:story_type]).to eq('bug')
            expect(body[:labels]).to eq(["Integration Test"])
            expect(body[:comments]).to be nil
          }
        end
      end
    end

    context 'with an existing identical issue' do
      let(:stories_queried) { [{ 'id' => '101' }] }
      let(:story_url) { "#{base_url}/stories/101" }
      before do
        stub_request(:put, story_url)
          .with(body: instance_of(String))
          .to_return(status: 200)
      end

      it 'edits the existing issue' do
        subject.send_event
        expect(WebMock).to have_requested(:put, story_url).with { |req|
          body = Rack::Utils.parse_nested_query(req.body).with_indifferent_access
          expect(body[:labels].length).to eq(2)
          expect(body[:labels]).to include('RepeatedFailures')
        }
      end
    end

    context 'when the necessary settings are blank' do
      let(:settings) do
        [
          { key: 'project_id', value: '' },
          { key: 'api_token', value: '' }
        ]
      end

      it 'does not try to communicate with pivotal' do
        response = double(:response)
        expect(described_class).to_not receive(:post)
        subject.send_event
      end
    end
  end
end
