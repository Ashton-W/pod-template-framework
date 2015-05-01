require 'xcodeproj'

module Pod

  class ProjectManipulator
    attr_reader :configurator, :xcodeproj_path, :platform, :remove_example_project, :string_replacements, :prefix, :example

    def self.perform(options)
      new(options).perform
    end

    def initialize(options)
      @xcodeproj_path = options.fetch(:xcodeproj_path)
      @configurator = options.fetch(:configurator)
      @platform = options.fetch(:platform)
      @remove_example_project = options.fetch(:remove_example_project)
      @prefix = options.fetch(:prefix)
      @prefix ||= ''
      @example = options.fetch(:example)
    end

    def run
      @string_replacements = {
        "PROJECT_OWNER" => @configurator.user_name,
        "TODAYS_DATE" => @configurator.date,
        "PROJECT" => @configurator.pod_name,
        "CPD" => @prefix
      }
      replace_internal_project_settings

      @project = Xcodeproj::Project.open(@xcodeproj_path)
      add_podspec_metadata unless @example
      remove_example_project_files if @remove_example_project
      @project.save

      rename_files
      rename_project_folder
    end

    def add_podspec_metadata
      project_metadata_item = @project.root_object.main_group.children.select { |group| group.name == "Podspec Metadata" }.first
      project_metadata_item.new_file @configurator.pod_name  + ".podspec"
      project_metadata_item.new_file "README.md"
      project_metadata_item.new_file "LICENSE"
    end

    def remove_example_project_files
      `rm -rf templates/ios/Example/`
    end

    def project_folder
      File.dirname @xcodeproj_path
    end

    def xcodeproj_name
      File.basename(@xcodeproj_path, '.*')
    end

    def rename_files
      project = xcodeproj_name

      # shared schemes have project specific names
      scheme_path = project_folder + "/#{project}.xcodeproj/xcshareddata/xcschemes/"

      File.rename(scheme_path + "#{project}.xcscheme", scheme_path +  templated_string(project) + ".xcscheme")

      # rename xcproject
      File.rename(project_folder + "/#{project}.xcodeproj", project_folder + "/" +  templated_string(project) + ".xcodeproj")

      unless @remove_example_project
        # rename project related files
        ["#{project}-Info.plist", "#{project}-Prefix.pch"].each do |file|
          before = project_folder + "/#{project}/" + file
          after = project_folder + "/#{project}/" + templated_string(project)
          File.rename before, after if File.file? before
        end
      end

    end

    def rename_project_folder
      if Dir.exist? project_folder + "/#{xcodeproj_name}"
        File.rename(project_folder + "/#{xcodeproj_name}", project_folder + "/" + templated_string(xcodeproj_name))
      end
    end

    def templated_string(text)
      for find, replace in @string_replacements
          text = text.gsub(find, replace)
      end
      text
    end

    def replace_internal_project_settings
      Dir.glob(project_folder + "/**/**/**/**").each do |name|
        next if Dir.exists? name
        text = File.read(name)

        for find, replace in @string_replacements
            text = text.gsub(find, replace)
        end

        File.open(name, "w") { |file| file.puts text }
      end
    end

  end

end
