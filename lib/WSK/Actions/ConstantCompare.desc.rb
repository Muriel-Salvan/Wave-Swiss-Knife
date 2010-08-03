# To change this template, choose Tools | Templates
# and open the template in the editor.

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :Value => [
      '--value <Value>', Integer,
      '<Value>: Constant value to compare with',
      'Specify the value to compare with.'
    ],
    :NbrSamples => [
      '--nbrsamples <NbrSamples>', Integer,
      '<NbrSamples>: Number of samples used to compare with',
      'Specify the number of samples the file should have.'
    ]
  }
}