#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :BeginSilenceLength => [
      '--begin <SilenceLength>', String,
      '<SilenceLength>: Length of silence to insert in samples or in float seconds (ie. 234 or 25.3s)',
      'Specify the number of samples to insert at the beginning of the audio data'
    ],
    :EndSilenceLength => [
      '--end <SilenceLength>', String,
      '<SilenceLength>: Length of silence to insert in samples or in float seconds (ie. 234 or 25.3s)',
      'Specify the number of samples to insert at the end of the audio data'
    ]
  }
}