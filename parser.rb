module RScheme

  class RSchemeError < StandardError; end

  class Parser

    # Used when we encounter a lexing error
    class RSchemeLexingError < RSchemeError; end

    class RSchemeParsingError < RSchemeError; end

    def initialize
      @current_string = ""
    end

    def process_str(str)
      process_result = process_line(str)
      @current_string = ""
      process_result
    end

    def process_line(line)
      @current_string << line

      # Split token_strs on " to prepare for further splits
      token_strs = @current_string.gsub("(", " ( ")
                                  .gsub(")", " ) ")
                                  .split(/\"/).collect { |x| x.strip }

      # Split on spaces, preserve quotes strings
      token_strs = (1..token_strs.size).zip(token_strs).collect { |i, x|
        if (i & 1).zero?
          %("#{x}")       # All odd items are quoted, and we add the quotes back
        else
          x.split         # We split on every even item
        end
      }.flatten           # Flatten back to a flat array

      # Lex tokens
      return _lex(token_strs)
    rescue RSchemeLexingError => ex
      warn ex.message
      @current_string = ""
      return nil
    end

    def _lex(token_strs)
      list_stack = []
      current_list = []

      token_strs.each do |token|
        case token
        when "("                    # Left parenthesis
          list_stack.push(current_list)
          current_list = []
        when ")"                    # Right parenthesis
          raise RSchemeLexingError, "Syntax error: unmatched )" if list_stack.empty?
          list_stack.last << [:LIST_TYPE, *current_list]
          current_list = list_stack.pop

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

        # Literal
        when /^[0-9]+/                         # Integer
          current_list << [:INTEGER_TYPE, token.to_i]
        when /^[0-9]*.[0-9]+/                  # Float
          current_list << [:REAL_TYPE, token.to_float]
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
          raise RSchemeLexingError, "Syntax error: unrecognized token #{token}"
        end
      end

      return :expr_not_terminated unless list_stack.empty?

      @current_string = ""
      current_list
    end

  end

end
