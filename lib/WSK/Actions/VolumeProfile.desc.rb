#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :FctFileName => [
      '--function <FunctionFileName>', String,
      '<FunctionFileName>: File that will contain the volume profile',
      'Specify the file to write with the profile function'
    ],
    :Begin => [
      '--begin <BeginPos>', String,
      '<BeginPos>: Position to begin profiling volume from. Can be specified as a sample number or a float seconds (ie. 12.3s).',
      'Specify the beginning of the profile'
    ],
    :End => [
      '--end <EndPos>', String,
      '<EndPos>: Position to end profiling volume to. Can be specified as a sample number or a float seconds (ie. 12.3s). -1 means to the end.',
      'Specify the ending of the profile'
    ],
    :Interval => [
      '--interval <Interval>', String,
      '<Interval>: Number of samples defining an interval for the volume measurement. Can be specified as a sample number or a float seconds (ie. 12.3s).',
      'Specify the granularity of the volume profile'
    ],
    :RMSRatio => [
      '--rmsratio <Ratio>', Float,
      '<Ratio>: Ratio of RMS measure vs Peak level measure, expressed in floats of range [0.0 .. 1.0]. 0.0 = Only Peak. 1.0 = Only RMS.',
      'Specify the way the level is measured.'
    ]
  }
}