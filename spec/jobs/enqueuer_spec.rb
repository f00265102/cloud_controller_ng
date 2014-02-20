require "spec_helper"

module VCAP::CloudController::Jobs
  describe Enqueuer do
    describe "#enqueue" do
      let(:job) { Runtime::DropletDeletion.new("one", "two") }
      let(:opts) { {:queue => "my-queue"} }

      it "delegates to Delayed::Job" do
        expect(Delayed::Job).to receive(:enqueue)
        Enqueuer.new(job, opts).enqueue()
      end
    end
  end

  describe TimeoutJob do
    let(:job) { double( :job_name => "my-job") }
    let(:timeout_job) { TimeoutJob.new(job) }

    it "runs the provided job" do
      expect(job).to receive(:perform)
      timeout_job.perform
    end

    context "when the job takes longer than its timeout" do
      before do
        job.stub(:perform) { sleep(2) }
      end

      it "doesn't allow the job to exceed the timeout" do
        expect(timeout_job).to receive(:max_run_time).with("my-job").and_return(1)
        expect{
          timeout_job.perform
        }.to raise_error(Timeout::Error)
      end
    end

    describe "max_timeout" do
      let(:config) do
        {
          jobs: {
            global: {
              timeout_in_seconds: 4.hours
            }
          }
        }
      end

      before do
        VCAP::CloudController::Config.stub(:config).and_return(config)
      end

      context "by default" do
        it "uses the configured global timeout" do
          expect(timeout_job.max_run_time(:app_bits_packer)).to eq(4.hours)
        end
      end

      context "when an override is specified for this job" do
        let(:overridden_timeout) { 5.minutes }

        before do
          config[:jobs].merge!(app_bits_packer: {
            timeout_in_seconds: overridden_timeout
          })
        end

        it "uses the overridden timeout" do
          expect(timeout_job.max_run_time(:app_bits_packer)).to eq(overridden_timeout)
        end
      end
    end
  end
end