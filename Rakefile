require 'amazing_print'

task :env do
  require './spec/base'
end

task :default do
  system 'rake -T'
end

desc 'Load console'
task console: :env do
  require 'byebug'

  load './spec/base'

  byebug
end

desc 'Dump raw JSON from fixtures'
task dump: :env do
  for klass in Joshua.documented
    puts klass
        puts JSON.pretty_generate klass.opts
    puts
  end
end

desc 'Sinatra demo web'
task :web do
  system 'find . | grep -v .git | entr -r ruby web/sinatra.rb'
end

desc 'Dump JSON schema'
task json: :env do
  puts JSON.pretty_generate UserApi.opts
  # for klass in Joshua.documented
  #   puts klass
  #       puts `pretty_generate klass.opts
  #   puts
  # end
end
