#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :MapFileName => [
      '--transformmap <MapFileName>', String,
      '<MapFileName>: Name of the map file corresponding to the transform',
      'Specify the file to take the transformation from.'
    ]
  }
}