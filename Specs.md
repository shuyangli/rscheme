# Types
- boolean
- pair
- symbol
- number
- char
- string
- vector
- port
- procedure

# Primitive expressions / reserved words
- Literal
    + (quote <datum>)
    + '<datum>
    + <constant>: numerical constants, 
- Procedure calls
    + (<operator> <expr> ...)
- Procedure
    + (lambda <formals> <expr>)
    + <formals>: (<variable> ...): fixed amount of args
               | <variable>: any amount of args
               | (<variable> ... <variable> . <variable>): n or more args
    + store its environment as well
    + when called, extend environment by binding formals to actual arguments
    + evaluate body and return result of last expression
    + tagged with storage location to make eqv? and eq? work
- Conditionals
    + (if <expr-test> <expr-consequent> [<expr-alternate>])
    + Short-circuiting
- Assignments
    + (set! <identifier> <expr>)
    + evaluate <expr>, then bind <identifier> to value
    + (define <identifier> <expr>) is equivalent to assignment in a program structure

# Derived expressions
- Conditionals
    + (cond <clause> <clause>)
