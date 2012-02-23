#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :Value => [
      '--value <Value>', Integer,
      '<Value>: Constant value to compare with',
      'Specify the value to compare with.'
    ],
    :NbrSamples => [
      '--nbrsamples <NbrSamples>', Integer,
      '<NbrSamples>: Number of samples used to compare with',
      'Specify the number of samples the file should have.'
    ]
  }
}