module Moose
  class TestCase
    class Reporter
      attr_reader :test_case

      TYPE_MAP = { 
        failure: :fatal,
        error: :error,
      }

      def initialize(test_case)
        @test_case = test_case
      end

      def final_report!
        return if test_case.passed?
        with_details do
          if test_case.failed?
            failure_script
            rerun_dialog
          end
        end
      end

      def report!
        with_details do
          if test_case.failed?
            failure_script
          elsif test_case.passed?
            passed_script
          end
        end
      end

      def rerun_dialog
        newline
        message_with(:info, "To Rerun")
        rerun_script
      end

      def rerun_script
        message_with(:info, "#{environment_variables} bundle exec moose #{Moose.environment} #{test_case.trimmed_filepath}")
      end

      def add_strategy(logger)
        raise "Loggers must respond to write" unless logger.respond_to?(:write)
        log_strategies << logger
      end

      private

      def log_strategies
        @log_strategies ||= []
      end

      def err
        test_case.exception
      end

      def trimmed_backtrace
        Helpers::BacktraceHelper.new(err.backtrace).filtered_backtrace
      end

      def environment_variables
        memo = ""
        Array(Moose.configuration.environment_variables).each do |var_name|
          value = ENV[var_name]
          memo += "#{var_name}=#{value} " if value
        end
        memo
      end

      def with_details(&block)
        newline
        message_with(:name, test_case.trimmed_filepath)
        message_with(:info, "time: #{test_case.time_elapsed}")
        newline

        block.call

        newline
      end

      def failure_script
        message_with(:failure, "TEST failed")
        if err
          message_with(:error, err.class)
          message_with(:error, err.message)
          Moose.msg.report_array(:error, trimmed_backtrace, true)
        end
      end

      def passed_script
        message_with(:pass, "TEST Passed!")
      end

      def newline
        msg = Moose.msg.newline("", true)
        log_strategies.map { |logger| logger.info(msg) }
      end

      def message_with(type, message)
        logger_type = TYPE_MAP.fetch(type, :info)
        msg = "\t#{message}"
        formatted_message = Moose.msg.send(type, msg, true)
        log_strategies.map { |logger| logger.send(logger_type, formatted_message) }
      end

      def gem_dir
        @gem_dir ||= gem_spec.gem_dir
      end

      def gem_spec
        @gem_spec ||= Moose.world.gem_spec
      end
    end
  end
end
