#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :SilenceThreshold => [
      '--silencethreshold <SilenceThreshold>', String,
      '<SilenceThreshold>: Threshold to use to identify silent parts [default = 0]. It is possible to specify several values, for each channel, sperated with | (ie. 34|35). It is also possible to specify a range instead of a threshold with , (ie. -128,126 or -128,126|-127,132)',
      'Specify the silence threshold'
    ],
    :NoiseFFTFileName => [
      '--noisefft <FFTFile>', String,
      '<FFTFile>: File containing the FFT profile of the reference noise. Can be set to \'none\' if no file.',
      'This is used to compare potential noise profile with the real noise profile.'
    ],
    :SilenceMin => [
      '--silencemin <SilenceDuration>', String,
      '<SilenceDuration>: Silence duration in samples or in float seconds (ie. 234 or 25.3s).',
      'Specify the minimum duration a silent part must have to be interpreted as a silence.'
    ],
  }
}