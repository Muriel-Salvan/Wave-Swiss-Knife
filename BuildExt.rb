#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

lRootDir = File.expand_path(Dir.getwd)
[
  'external/CommonUtils',
  'ext/WSK/AnalyzeUtils',
  'ext/WSK/ArithmUtils',
  'ext/WSK/FFTUtils',
  'ext/WSK/FunctionUtils',
  'ext/WSK/SilentUtils',
  'ext/WSK/VolumeUtils'
].each do |iExtPath|
  puts "===== Building #{iExtPath} ..."
  Dir.chdir("#{lRootDir}/#{iExtPath}")
  if (!system('ruby -w build.rb'))
    raise RuntimeError.new("Error while building #{iExtPath}: #{$?}")
  end
  Dir.chdir(lRootDir)
  puts "===== #{iExtPath} built ok."
  puts ''
end
