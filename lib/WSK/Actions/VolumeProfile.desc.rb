# To change this template, choose Tools | Templates
# and open the template in the editor.

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
    ]
  }
}