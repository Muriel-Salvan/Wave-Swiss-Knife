# To change this template, choose Tools | Templates
# and open the template in the editor.

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :Offset => [
      '--offset <DCOffset>', String,
      '<DCOffset>: Offset to use for the shift [default = 0]. It is possible to specify several values, for each channel, sperated with | (ie. 34|35).',
      'Specify the offset'
    ]
  }
}