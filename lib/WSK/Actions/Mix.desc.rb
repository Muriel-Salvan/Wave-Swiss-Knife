#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :MixFiles => [
      '--files <FilesList>', String,
      '<FilesList>: List of files to mix with the input file, with floating coefficients, separated with | (example: File1.wav|2|File2.wav|1.4|File3.wav|-1)',
      'Specify the list of files to mix along with their coefficient. The input file has the coefficient 1. The coefficient can be negative to invert the file while mixing.'
    ]
  }
}