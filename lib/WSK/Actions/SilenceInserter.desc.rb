# To change this template, choose Tools | Templates
# and open the template in the editor.

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :BeginSilenceLength => [
      '--begin <SilenceLength>', String,
      '<SilenceLength>: Length of silence to insert in samples or in float seconds (ie. 234 or 25.3s)',
      'Specify the number of samples to insert at the beginning of the audio data'
    ],
    :EndSilenceLength => [
      '--end <SilenceLength>', String,
      '<SilenceLength>: Length of silence to insert in samples or in float seconds (ie. 234 or 25.3s)',
      'Specify the number of samples to insert at the end of the audio data'
    ]
  }
}