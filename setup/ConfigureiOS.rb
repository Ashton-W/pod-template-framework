module Pod

  class ConfigureIOS
    attr_reader :configurator

    def self.perform(options)
      new(options).perform
    end

    def initialize(options)
      @configurator = options.fetch(:configurator)
    end

    def perform

      keep_example = configurator.ask_with_answers("Would you like to include an example application with your library", ["Yes", "No"]).to_sym

      framework = configurator.ask_with_answers("Which testing frameworks will you use", ["Specta", "Kiwi", "None"]).to_sym
      case framework
        when :specta
          configurator.add_pod_to_podfile "Specta"
          configurator.add_pod_to_podfile "Expecta"

          configurator.add_line_to_pch "#define EXP_SHORTHAND"
          configurator.add_line_to_pch "#import <Specta/Specta.h>"
          configurator.add_line_to_pch "#import <Expecta/Expecta.h>"

          configurator.set_test_framework("specta")

        when :kiwi
          configurator.add_pod_to_podfile "Kiwi"
          configurator.add_line_to_pch "#import <Kiwi/Kiwi.h>"
          configurator.set_test_framework("kiwi")

        when :none
          configurator.set_test_framework("xctest")
      end

      prefix = nil

      loop do
        prefix = configurator.ask("What is your class prefix")

        if prefix.include?(' ')
          puts 'Your class prefix cannot contain spaces.'.red
        else
          break
        end
      end

      Pod::ProjectManipulator.new({
        :configurator => @configurator,
        :xcodeproj_path => "templates/ios/PROJECT.xcodeproj",
        :platform => :ios,
        :remove_example_project => (keep_example == :no),
        :prefix => prefix,
        :example => false
      }).run

      Pod::ProjectManipulator.new({
        :configurator => @configurator,
        :xcodeproj_path => "templates/ios/Example/PROJECT-Example.xcodeproj",
        :platform => :ios,
        :remove_example_project => (keep_example == :no),
        :prefix => nil,
        :example => true
      }).run

      `mv ./templates/ios/* ./`
    end
  end

end
