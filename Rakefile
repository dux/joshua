require 'awesome_print'

task :env do
  require './spec/base'
end

task :default do
  system 'rake -T'
end

desc 'Load console'
task console: :env do
  pry
end

desc 'Dump raw JSON from fixtures'
task dump: :env do
  for klass in CleanApi::ACTIVATED
    puts klass
      ap klass.opts
    puts
  end
end

desc 'Sinatra demo web'
task :web do
  system 'find . | grep -v .git | entr -r ruby web/loader.rb'
end