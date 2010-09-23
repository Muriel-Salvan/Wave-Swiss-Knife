lRootDir = File.expand_path(Dir.getwd)
[
  'external/CommonUtils',
  'ext/WSK/AnalyzeUtils',
  'ext/WSK/ArithmUtils',
  'ext/WSK/FFTUtils',
  'ext/WSK/SilentUtils'
].each do |iExtPath|
  puts "===== Building #{iExtPath} ..."
  Dir.chdir("#{lRootDir}/#{iExtPath}")
  system('ruby -w build.rb')
  Dir.chdir(lRootDir)
  puts "===== #{iExtPath} built ok."
  puts ''
end
