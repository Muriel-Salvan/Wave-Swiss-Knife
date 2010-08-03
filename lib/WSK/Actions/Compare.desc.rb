# To change this template, choose Tools | Templates
# and open the template in the editor.

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :InputFileName2 => [
      '--inputfile2 <FileName>', String,
      '<FileName>: Second file name to compare with.',
      'Specify the file to compare with. The resulting file will be (inputfile - inputfile2)*Coefficient.'
    ],
    :Coeff => [
      '--coeff <Coefficient>', Integer,
      '<Coefficient>: Coefficient to multiply the differences [default = 1]',
      'Specify the multiplying coefficient.'
    ],
    :GenMap => [
      '--genmap <Switch>', Integer,
      '<Switch>: 0 or 1, turning off or on the map generation [default = 0]',
      'If 1, a file (named Output.map) will be created, storing the distortion for each encountered value.'
    ]
  }
}