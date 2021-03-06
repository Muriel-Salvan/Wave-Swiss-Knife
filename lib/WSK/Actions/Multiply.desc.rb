#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :Coeff => [
      '--coeff <Coeff>', String,
      '<Coeff>: Coefficient to apply in the form X/Y (ie. 4/3) or in db (ie. -3db)',
      'Specify the multiplying coefficient'
    ]
  }
}