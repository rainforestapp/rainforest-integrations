require 'erb'

desc 'Generate documentation for the project'
task :doc do
  @events = YAML.load File.read(Rails.root.join('data', 'events.yml'))
  @integrations = YAML.load File.read(Rails.root.join('data', 'integrations.yml'))

  out = File.open('README.md', 'w')
  out << ERB.new(File.read('doc/README.md.erb')).result(binding)
  out.close
end
