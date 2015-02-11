#!/usr/bin/env ruby

require './error.rb'
require './lexer.rb'
require './parser.rb'
require './evaluator.rb'

lexer = RScheme::Lexer.new
parser = RScheme::Parser.new
evaluator = RScheme::Evaluator.new


level = 0
all_lines = ""

loop do

  begin
    print ">>>#{level} " + "\t"

    line = $stdin.gets
    if line.nil?
      puts ""
      exit 0
    end

    line.strip!

    all_lines << line
    tokens = lexer.lex(line)
    syntax_tree = parser.parse(tokens)
    eval_result = evaluator.evaluate(syntax_tree)
    puts eval_result.inspect
  rescue RScheme::RSchemeExprNotTerminatedError => ex
    all_lines << "\n"
    level = ex.message
  rescue RScheme::RSchemeLexingError => ex
    warn "[LEXING ERROR]: #{ex.message}"
  rescue RScheme::RSchemeParsingError => ex
    warn "[PARSING ERROR]: #{ex.message}"
  rescue RScheme::RSchemeRuntimeError => ex
    warn "[RUNTIME ERROR]: #{ex.message}"
  end

end
