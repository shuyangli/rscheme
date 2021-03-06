require './error.rb'

module RScheme

  class Lexer

    def tokenize(str)
      # Split token_strs on " to prepare for further splits
      token_strs = str.gsub("(", " ( ")
                      .gsub(")", " ) ")
                      .split(/\"/)
                      .collect { |x| x.strip }

      # Split on spaces, preserve quotes strings
      (1..token_strs.size).zip(token_strs).collect { |i, x|
        if (i & 1).zero?
          %("#{x}")       # All odd items are quoted, and we add the quotes back
        else
          x.split         # We split on every even item
        end
      }.flatten           # Flatten back to a flat array
    end

    def lex(str)
      _lex(tokenize(str))
    end

    def _lex(token_strs)
      list_stack = []
      current_list = []

      token_strs.each do |token|
        case token

        # Parentheses
        when "("
          current_list << [:PAREN, :LPAREN]
        when ")"
          current_list << [:PAREN, :RPAREN]

        # Reserved words section
        when "quote"
          current_list << [:KEYWORD, :QUOTE]
        when "define"
          current_list << [:KEYWORD, :DEFINE]
        when "set!"
          current_list << [:KEYWORD, :ASSIGN]
        when "lambda"
          current_list << [:KEYWORD, :LAMBDA]
        when "if"
          current_list << [:KEYWORD, :IF]
        when "let"
          current_list << [:KEYWORD, :LET]
        when "let*"
          current_list << [:KEYWORD, :LETSEQ]
        when "letrec"
          current_list << [:KEYWORD, :LETREC]
        when "car"
          current_list << [:KEYWORD, :CAR]
        when "cdr"
          current_list << [:KEYWORD, :CDR]
        when "cons"
          current_list << [:KEYWORD, :CONS]

        # Operators
        when "+"
          current_list << [:OPERATOR, :PLUS]
        when "-"
          current_list << [:OPERATOR, :MINUS]
        when "*"
          current_list << [:OPERATOR, :MULT]
        when "/"
          current_list << [:OPERATOR, :DIV]
        when "="
          current_list << [:OPERATOR, :EQUAL]
        when "<"
          current_list << [:OPERATOR, :LT]
        when "<="
          current_list << [:OPERATOR, :LE]
        when ">"
          current_list << [:OPERATOR, :GT]
        when ">="
          current_list << [:OPERATOR, :GE]
        when "and"
          current_list << [:OPERATOR, :AND]
        when "or"
          current_list << [:OPERATOR, :OR]
        when "not"
          current_list << [:OPERATOR, :NOT]

        # Built-in type checks
        # when "null?"
        #   current_list << [:OPERATOR, :NULL_Q]
        # when "pair?"
        #   current_list << [:OPERATOR, :PAIR_Q]

        # Literal
        when /^[0-9]*\.[0-9]+/                 # Float
          current_list << [:REAL_TYPE, token.to_f]
        when /^[0-9]+/                         # Integer
          current_list << [:INTEGER_TYPE, token.to_i]
        when /^#t/                             # Boolean
          current_list << [:BOOLEAN_TYPE, true]
        when /^#f/
          current_list << [:BOOLEAN_TYPE, false]
        when %r(^"([^"]*)")   # String, using named capture group to extract value
          current_list << [:STRING_TYPE, $1]

        # Identifier
        when %r(^[A-Za-z_][A-Za-z0-9\.+-?!]*)
          current_list << [:IDENT, token.downcase]

        # Error
        else
          raise RSchemeLexingError, "Lexing error: unrecognized token #{token}"
        end
      end
      current_list
    end

  end

end
