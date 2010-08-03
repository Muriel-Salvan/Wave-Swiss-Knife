# To change this template, choose Tools | Templates
# and open the template in the editor.

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :NbrSilentSamples => [
      '--silentsamples <NumberOfSamples>', Integer,
      '<NumberOfSamples>: Number of samples to insert with silence',
      'Specify the number of samples to insert at the beginning of the audio data'
    ],
    :InsertAtEnd => [
      '--endoffile <Switch>', Integer,
      '<Switch>: 0: insert at the beginning. 1: insert at the end.',
      'Specify where the silent is to be inserted'
    ]
  }
}