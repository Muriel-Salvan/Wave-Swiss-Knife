# To change this template, choose Tools | Templates
# and open the template in the editor.

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :Frequency => [
      '--frequency <Frequency>', Integer,
      '<Frequency>: Frequency of the sine wave (in Hz)',
      'Specify the frequency of the generated sine wave.'
    ],
    :NbrSamples => [
      '--nbrsamples <NbrSamples>', Integer,
      '<NbrSamples>: Number of samples used to write this value',
      'Specify the number of samples during the value will be written.'
    ]
  }
}