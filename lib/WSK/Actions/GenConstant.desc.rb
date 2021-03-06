#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :Value => [
      '--value <Value>', Integer,
      '<Value>: Constant value to write',
      'Specify the value to write in the wave file.'
    ],
    :NbrSamples => [
      '--nbrsamples <NbrSamples>', Integer,
      '<NbrSamples>: Number of samples used to write this value',
      'Specify the number of samples during the value will be written.'
    ]
  }
}