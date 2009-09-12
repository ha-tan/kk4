# -*- ruby -*-

require 'rake/clean'

task :default => 'kk4.exe'

file 'kk4.exe' => ['kk4.rb', 'kk4.exy'] do
  sh "exerb kk4.exy"
end

task 'release' => ['kk4.exe'] do
  sh '"C:/Program Files/Inno Setup 5/ISCC.exe" release.iss'
end

CLEAN.include('kk4.exe')
CLOBBER.include('kk4.exe')
