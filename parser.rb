module RScheme

  class RSchemeError < StandardError; end

  class Parser

    class RSchemeParsingError < RSchemeError; end
    class RSchemeExprNotTerminatedError < RSchemeParsingError; end

    def parse(tokens)
      list_stack = []
      current_list = []

      tokens.each do |token|
        case token[0]
        when ":PAREN"               # Parenthesis
          if token[1] == :LPAREN
            list_stack.push(current_list)
            current_list = []
          elsif token[1] == :RPAREN
            raise RSchemeParsingError, "Syntax error: unmatched )" if list_stack.empty?
            list_stack.last << [:LIST_TYPE, *current_list]
            current_list = list_stack.pop
          end
        else
          current_list << token
        end
      end

      raise RSchemeExprNotTerminatedError, list_stack.length unless list_stack.empty?

      current_list
    end

  end

end
