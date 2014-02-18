require 'test_helper'
describe "Mobilize" do
  # enqueues 4 workers on Resque
  it "runs integration test" do

    puts "restart test redis"
    TestHelper.restart_test_redis
    TestHelper.drop_test_db

    puts "restart workers"
    Mobilize::Jobtracker.restart_workers!

    _user                          = TestHelper.owner_user
    _runner                        = _user.runner
    _user_name                     = _user.name
    _gdrive_slot                   = _user.email

    puts "build test runner"
    TestHelper.build_test_runner     _user_name
    assert Mobilize::Jobtracker.workers.length == Mobilize::Resque.config['max_workers'].to_i

    puts "add test code"
    ["code.rb","code.sh","code2.sh"].each do |_fixture_name|
      _target_url                  = "gsheet://#{ _runner.title }/#{ _fixture_name }"
      TestHelper.write_fixture       _fixture_name, _target_url, 'replace'
    end

    puts "add/update jobs"
    _user.jobs.each{|_job| _job.stages.each{|_stage| _stage.delete}; _job.delete}
    _jobs_fixture_name             = "integration_jobs"
    _jobs_target_url               = "gsheet://#{ _runner.title }/jobs"
    TestHelper.write_fixture         _jobs_fixture_name, _jobs_target_url, 'update', {'owner' => _user.name }

    puts "job rows added, force enqueue runner, wait for stages"
    #wait for stages to complete
    _expected_fixture_name         = "integration_expected"
    Mobilize::Jobtracker.stop!
    _runner.enqueue!
    TestHelper.confirm_expected_jobs _expected_fixture_name

    puts "update job status and activity"
    _runner.update_gsheet            _gdrive_slot

    puts "jobtracker posted data to test sheets"
    ['ssh1.out','ssh2.out','ssh4.out'].each do |_out_name|
      _url                         = "gsheet://#{_runner.title}/#{_out_name}"
      assert TestHelper.check_output( _url, 'min_length' => 100) == true
    end

    _url                           = "gsheet://#{_runner.title}/ssh3.out"
    assert TestHelper.check_output( _url, 'min_length' => 3 ) == true
  end
end
