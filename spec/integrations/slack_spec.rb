require "active_support/core_ext/string"

describe Rainforest::Integrations::Slack do

  let(:config) do
    {slack_url: "http://example.com/slack"}
  end

  let(:event) { load_event_json("test_failure") }
  let(:response_body) { '{"ok": true}' }
  let(:response) { {body: response_body, status: 200, headers: {"content-type"=>"application/json; charset=utf-8"}} }

  subject(:integration) { described_class.new config }

  it "posts to the Slack API" do
    stub_request(:post, subject.url).to_return(response)
    integration.on_event event
  end

  describe '#completion_text' do
    it 'includes the duration of the run' do
      expect( integration.completion_text(event) ).to eq 'Your Rainforest Run <http://app.rainforest.dev/runs/11388|#11388> failed. Time to finish: 32 minutes 51 seconds'
    end

    it 'includes de description of the run' do
      event.run["description"] = "some description"
      expect( integration.completion_text(event) ).to eq 'Your Rainforest Run <http://app.rainforest.dev/runs/11388|#11388> (some description) failed. Time to finish: 32 minutes 51 seconds'
    end
  end

  describe '#error_text' do
    let(:event) { load_event_json("run_error") }

    it 'includes the duration of the run' do
      expect( integration.error_text(event) ).to include 'Time to finish: 6 hours 36 minutes 44 seconds'
    end
  end

  context "of_text_failure" do
    let(:event) { load_event_json("test_failure") }

    describe "message_text" do
      subject(:text) { integration.message_text(event) }

      it { should include "failed" }

      it "should include the failing test title" do
        expect(text).to include "Switch to a pricing plan"
      end

      it "should include a link to the ui" do
        expect(text).to include event.ui_link
      end
    end

    describe '#attachments' do
      subject { integration.attachments(event) }

      context 'for a run_failure event' do
        let(:event) { load_event_json("run_error") }

        it 'should only have one attachment' do
          expect(subject.count).to eq 1
        end

        it 'should be colored red' do
          expect(subject.first[:color]).to eq 'danger'
        end
      end

      context 'for a of_run_completion event' do
        context 'with a failure' do
          let(:event) { sample_event }

          it 'should be colored red' do
            expect(subject.first[:color]).to eq 'danger'
          end
        end

        context 'with a success' do
          let(:event) { sample_success_event }

          it 'should be colored green' do
            expect(subject.first[:color]).to eq 'good'
          end
        end
      end
    end

    describe "failed_step_attachments" do
      subject(:attachments) { integration.failed_step_attachments(event) }

      it "should have an attachment for each failed step" do
        expect(attachments.size).to eq(1)
      end

      describe "the attachment" do
        subject(:attachment) { attachments.first }

        describe ":text" do
          subject(:text) { attachment[:text] }

          it "should include the step number" do
            expect(text).to include("Step #2")
          end

          it "should include the result" do
            expect(text).to include "failed"
          end

          it "should include the truncated action" do
            expect(text).to include "Locate a pricing plan that..."
          end

          it "should include the truncated expected response" do
            expect(text).to include "Did you get a success message?"
          end
        end

      end

    end
  end

  context "with an error response" do
    let(:response_body) { '{ "ok": false, "error": "not_authed" }' }

    it "should raise a ConfigurationError" do
      stub_request(:post, subject.url).to_return(response)

      expect {
        subject.on_event event
      }.to raise_error(Rainforest::Integrations::ConfigurationError)
    end
  end

  context "with a bogus URI" do
    let(:config) { {slack_url: "bogus.slack.com"} }

    it "shold raise a ConfigurationError" do
      expect {
        subject.on_event event
      }.to raise_error(Rainforest::Integrations::ConfigurationError)
    end
  end

  context "with a blank URI" do
    let(:config) { { slack_url: '' } }

    it 'does nothing' do
      expect { subject.on_event event }.to_not raise_error
    end
  end

  context "with no not found response" do
    let(:config) { {slack_url: 'https://hooks.slack.com/disabled_hooks' } }

    it 'should raise a ConfigurationError' do
      stub_request(:post, config[:slack_url]).to_return(status: 404, body: "Not found")

      expect { subject.on_event event }.to raise_error(Rainforest::Integrations::ConfigurationError)
    end
  end
end
