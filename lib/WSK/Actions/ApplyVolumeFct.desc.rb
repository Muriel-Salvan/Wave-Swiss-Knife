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
      'Specify the function to apply'
    ],
    :Begin => [
      '--begin <BeginPos>', String,
      '<BeginPos>: Position to apply volume transformation from. Can be specified as a sample number or a float seconds (ie. 12.3s).',
      'Specify the first sample that will have the function applied'
    ],
    :End => [
      '--end <EndPos>', String,
      '<EndPos>: Position to apply volume transformation to. Can be specified as a sample number or a float seconds (ie. 12.3s). -1 means to the end of file.',
      'Specify the last sample that will have the function applied'
    ],
    :UnitDB => [
      '--unitdb <Switch>', Integer,
      '<Switch>: 0 means that units used in the function are ratios. 1 means that units used in the functions are db.',
      'Specify the unit used in the function'
    ]
  }
}