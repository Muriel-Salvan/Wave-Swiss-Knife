# To change this template, choose Tools | Templates
# and open the template in the editor.

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
      '<EndPos>: Position to apply volume transformation to. Can be specified as a sample number or a float seconds (ie. 12.3s).',
      'Specify the last sample that will have the function applied'
    ]
  }
}