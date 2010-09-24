# To change this template, choose Tools | Templates
# and open the template in the editor.

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :SilenceLength => [
      '--silence <SilenceLength>', Integer,
      '<SilenceLength>: Length of silence to insert in samples or in float seconds (ie. 234 or 25.3s)',
      'Specify the number of samples to insert at the beginning of the audio data'
    ],
    :InsertAtEnd => [
      '--endoffile <Switch>', Integer,
      '<Switch>: 0: insert at the beginning. 1: insert at the end.',
      'Specify where the silent is to be inserted'
    ]
  }
}