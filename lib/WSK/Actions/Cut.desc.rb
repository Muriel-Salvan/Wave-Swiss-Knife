# To change this template, choose Tools | Templates
# and open the template in the editor.

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :BeginSample => [
      '--begin <BeginSample>', String,
      '<BeginSample>: Index of sample to begin with [default = 0]. Can be specified in float seconds (ie. 12.3s).',
      'Specify the first sample to write'
    ],
    :EndSample => [
      '--end <EndSample>', String,
      '<EndSample>: Index of sample to end with [default = 256]. Can be specified in float seconds (ie. 12.3s).',
      'Specify the last sample to write'
    ]
  }
}