module Moose
  module TestSuite
    class Instance < Base
      attr_accessor :start_time, :end_time, :has_run
      attr_reader :directory, :test_group_collection, :runner, :moose_configuration
      include Utilities::Inspectable
      inspector(:name)

      def initialize(directory:, moose_configuration:, runner:)
        @directory = directory
        @moose_configuration = moose_configuration
        @runner = runner
      end

      def build_dependencies
        Dir.glob(File.join(directory, "*")) { |test_dir|
          if test_dir =~ /#{test_group_directory_pattern}/
            build_test_groups_from(test_dir)
          elsif test_dir =~ /.*_configuration\.rb/
            configuration.load_file(test_dir)
          end
        }
        self
      end

      def configuration
        @configuration ||= ::Moose::TestSuite::Configuration.new(runner)
      end

      def run!(opts = {})
        return self unless test_group_collection
        self.start_time = Time.now
        self.has_run = true
        msg.banner("Running Test Suite: #{name}") if name
        configuration.suite_hook_collection.call_hooks_with_entity(entity: self) do
          test_group_collection.run!(opts)
        end
        self.end_time = Time.now
        self
      end

      def rerun_failed!(opts = {})
        return self unless test_group_collection
        return self unless has_failed_tests?
        if name
          msg.newline
          msg.invert("Rerunning failed tests for #{name}")
          msg.newline
        end
        configuration.suite_hook_collection.call_hooks_with_entity(entity: self) do
          test_group_collection.rerun_failed!(opts)
        end
        self.end_time = Time.now
        self
      end

      def report!(opts = {})
        reporter.report!(opts)
      end

      def time_summary_report
        reporter.time_summary_report
      end

      def name
        @name ||= begin
          reg = /(.*)#{moose_configuration.suite_pattern.gsub(/\*/, '')}/
          directory_minus_suite_pattern = reg.match(directory)[1]
          File.basename(directory_minus_suite_pattern)
        rescue
          nil
        end
      end

      def base_url
        configuration.base_url
      end

      def filter_from_options!(options)
        test_group_collection.filter_from_options!(options) if test_group_collection
      end

      def has_available_tests?
        test_group_collection.has_available_tests? if test_group_collection
      end

      def metadata
        [:time_elapsed,:start_time,:end_time,:directory,:name].inject({}) do |memo, method|
          begin
            memo.merge!(method => send(method))
            memo
          rescue => e
            # drop error for now
            memo
          end
        end
      end

      def time_elapsed
        return unless end_time && start_time
        end_time - start_time
      end

      TestStatus::POSSIBLE_STATUSES.each do |meth|
        define_method("#{meth}_tests") do
          test_group_collection.send("#{meth}_tests")
        end

        define_method("has_#{meth}_tests?") do
          test_group_collection.send("has_#{meth}_tests?")
        end
      end

      def tests
        test_group_collection.tests
      end

      def msg
        @msg ||= Utilities::Message::Delegator.new(moose_configuration)
      end

      private

      def reporter
        @reporter ||= Reporter.new(self)
      end

      def test_group_directory_pattern
        moose_configuration.moose_test_group_directory_pattern.gsub('**', '*')
      end

      def build_test_groups_from(directory)
        test_group_builder = TestGroup::Builder.new(
          directory: directory,
          test_suite: self,
          moose_configuration: moose_configuration
        )
        @test_group_collection = test_group_builder.build_list.collection
      end
    end
  end
end
