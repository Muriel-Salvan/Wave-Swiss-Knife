#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :Offset => [
      '--offset <DCOffset>', String,
      '<DCOffset>: Offset to use for the shift [default = 0]. It is possible to specify several values, for each channel, sperated with | (ie. 34|35).',
      'Specify the offset'
    ]
  }
}