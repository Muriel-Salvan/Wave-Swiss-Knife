require 'mkmf'
$CFLAGS += ' -Wall '
create_makefile('AnalyzeUtils')
system('make')
