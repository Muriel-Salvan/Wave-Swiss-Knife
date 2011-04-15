#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :BeginSample => [
      '--begin <BeginSample>', String,
      '<BeginSample>: Index of sample to begin with [default = 0]. Can be specified in float seconds (ie. 12.3s).',
      'Specify the first sample to write'
    ],
    :EndSample => [
      '--end <EndSample>', String,
      '<EndSample>: Index of sample to end with [default = 256]. Can be specified in float seconds (ie. 12.3s).',
      'Specify the last sample to write'
    ]
  }
}