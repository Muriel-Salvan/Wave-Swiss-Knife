#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :FctFileName => [
      '--function <FunctionFileName>', String,
      '<FunctionFileName>: File containing the function definition',
      'Specify the function to draw'
    ],
    :UnitDB => [
      '--unitdb <Switch>', Integer,
      '<Switch>: 0 means that units used in the function are ratios. 1 means that units used in the functions are db.',
      'Specify the unit used in the function'
    ]
  }
}