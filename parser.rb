#!usr/bin/env ruby

module RScheme

  class LexerParser

    class RSchemeLexingError < StandardError
    end

    class RSchemeParsingError < StandardError
    end

    def initialize
      @current_string = ""
    end

    def process_line(line)
      @current_string << line

      # Check if parentheses are balanced
      token_strs = @current_string.gsub("(", " ( ")
                                  .gsub(")", " ) ")
                                  .split
      lparen_count = token_strs.inject(0) do |acc, item|
        if item == "("
          acc + 1
        else
          acc
        end
      end
      rparen_count = token_strs.inject(0) do |acc, item|
        if item == ")"
          acc + 1
        else
          acc
        end
      end

      return :expr_not_terminated if lparen_count > rparen_count
      return _lex(token_strs)
    rescue RSchemeLexingError => ex
      warn ex.message
      @current_string = ""
    end

    # DEBUG
    def _readline(line)
      @current_string << line
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
          list_stack.last << [:LIST_TYPE, current_list]
          current_list = list_stack.pop

        # Reserved words section
        when "quote"
          current_list << :QUOTE
        when "define"
          current_list << :DEFINE
        when "set!"
          current_list << :ASSIGN
        when "lambda"
          current_list << :LAMBDA
        when "if"
          current_list << :IF
        when "let"
          current_list << :LET
        when "letrec"
          current_list << :LETREC
        when "+"
          current_list << :PLUS
        when "-"
          current_list << :MINUS
        when "*"
          current_list << :MULT
        when "/"
          current_list << :DIV
        when "="
          current_list << :EQUAL
        when "<"
          current_list << :LT
        when "<="
          current_list << :LE
        when ">"
          current_list << :GT
        when ">="
          current_list << :GE

        # Literal
        when /[0-9]+/             # Integer
          current_list << [:INTEGER_TYPE, token.to_i]
        when /[0-9]*.[0-9]+/      # Float
          current_list << [:REAL_TYPE, token.to_float]
        when /#t/                 # Boolean
          current_list << [:BOOLEAN_TYPE, true]
        when /#f/
          current_list << [:BOOLEAN_TYPE, false]
        when %r(".+")
          current_list << [:STRING_TYPE, token]

        # Identifier
        when %r([A-Za-z_][A-Za-z0-9\.+-?!]*)
          current_list << [:IDENT_TYPE, token.downcase]
        else
          raise RSchemeLexingError, "Syntax error: unrecognized token #{token}"
        end
      end

      @current_string = ""
      current_list
    end

  end

end
