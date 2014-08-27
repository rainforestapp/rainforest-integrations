module Rainforest
  module Integrations
    describe Hipchat do
      let(:config) do
        {
          hipchat_room: "My Room",
          hipchat_token: "My Token",
        }
      end

      subject { described_class.new config }

      it "posts to the Hipchat API" do
        stub_request(:post, described_class::URL)
        subject.on_event sample_event
      end

      it "posts job failures to the Hipchat API" do
        stub_request(:post, described_class::URL)
        subject.on_event sample_job_failure_event
      end
    end
  end
end