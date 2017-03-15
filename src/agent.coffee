# agent.coffee

module.exports =
  name: "PromoBot"
  inputs:
    hasAccount:
      no: [0, 0.5]
      yes: [0.5, 1]
    tutorial:
      no: [0, 0.5]
      yes: [0.5, 1]
    lastAPICall:
      never: [0, 1]
      thisWeek: [1, 7]
      thisMonth: [1, 31]
      older: [31, 100]
  outputs:
    discount:
      none: [0, 5]
      low: [5, 10]
      medium: [10, 15]
      high: [15, 20]
  rules: [
    '''IF hasAccount IS no THEN discount IS high'''
    '''IF hasAccount IS yes THEN discount IS low'''
    '''IF tutorial IS no THEN discount IS high'''
    '''IF tutorial IS yes THEN discount IS low'''
    '''lastAPICall INCREASES discount'''
  ]
  performance:
    discount: "maximize"
