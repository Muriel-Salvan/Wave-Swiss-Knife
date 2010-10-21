# To change this template, choose Tools | Templates
# and open the template in the editor.

{
  :OutputInterface => 'DirectStream',
  :Options => {
    :FctFileName => [
      '--function <FunctionFileName>', String,
      '<FunctionFileName>: File containing the function definition',
      'Specify the function to draw'
    ],
    :UnitDB => [
      '--unitdb <Switch>', Integer,
      '<Switch>: 0 means that units used in the function are ratios. 1 means that units used in the functions are db.',
      'Specify the unit used in the function'
    ]
  }
}