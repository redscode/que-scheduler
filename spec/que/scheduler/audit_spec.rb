require 'spec_helper'

RSpec.describe Que::Scheduler::Audit do
  describe '.append' do
    def append_test_jobs(enqueued, executed_at, job_id)
      described_class.append(job_id, executed_at, enqueued)

      audit = Que::Scheduler::VersionSupport.execute('select * from que_scheduler_audit')
      expect(audit.count).to eq(1)
      expect(audit.first[:scheduler_job_id]).to eq(job_id)
      expect(audit.first[:executed_at]).to eq(executed_at)

      db_jobs =
        Que::Scheduler::VersionSupport.execute('select * from que_scheduler_audit_enqueued')
      DbSupport.convert_args_column(db_jobs)
      expect(db_jobs.count).to eq(enqueued.count)
      db_jobs
    end

    it 'appends an audit line' do
      Timecop.freeze do
        scheduler_job_id = 1234
        executed_at = Time.zone.now.change(usec: 0)
        enqueued = [
          Que::Scheduler::ToEnqueue.create(job_class: HalfHourlyTestJob, args: 5, queue: 'something1', run_at: executed_at - 1.hour).enqueue,
          Que::Scheduler::ToEnqueue.create(job_class: HalfHourlyTestJob, priority: 80, run_at: executed_at - 2.hour).enqueue,
          Que::Scheduler::ToEnqueue.create(job_class: DailyTestJob, args: 3, queue: 'something3', run_at: executed_at - 3.hour).enqueue
        ]
        db_jobs = append_test_jobs(enqueued, executed_at, scheduler_job_id)
        expect(db_jobs).to eq(
          [
            {
              scheduler_job_id: scheduler_job_id,
              job_class: 'HalfHourlyTestJob',
              queue: 'something1',
              priority: 100,
              args: [5],
              job_id: Que::Scheduler::ToEnqueue.job_id(enqueued[0]),
              run_at: executed_at - 1.hour,
            },
            {
              scheduler_job_id: scheduler_job_id,
              job_class: 'HalfHourlyTestJob',
              queue: Que::Scheduler.configuration.que_scheduler_queue,
              priority: 80,
              args: [],
              job_id: Que::Scheduler::ToEnqueue.job_id(enqueued[1]),
              run_at: executed_at - 2.hours,
            },
            {
              scheduler_job_id: scheduler_job_id,
              job_class: 'DailyTestJob',
              queue: 'something3',
              priority: 100,
              args: [3],
              job_id: Que::Scheduler::ToEnqueue.job_id(enqueued[2]),
              run_at: executed_at - 3.hours,
            },
          ]
        )
      end
    end
  end
end
