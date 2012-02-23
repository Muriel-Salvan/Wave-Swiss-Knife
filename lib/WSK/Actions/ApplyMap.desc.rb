#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
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