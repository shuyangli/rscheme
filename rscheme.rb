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
    tokens = lexer.lex(all_lines)
    syntax_tree = parser.parse(tokens)
    eval_result = evaluator.eval(syntax_tree)
    puts eval_result.inspect

    all_lines = ""
    level = 0

  rescue RScheme::RSchemeExprNotTerminatedError => ex
    all_lines << "\n"
    level = ex.message
  rescue RScheme::RSchemeLexingError => ex
    warn "[LEXING ERROR]: #{ex.message}"
    all_lines = ""
    level = 0
  rescue RScheme::RSchemeParsingError => ex
    warn "[PARSING ERROR]: #{ex.message}"
    all_lines = ""
    level = 0
  rescue RScheme::RSchemeRuntimeError => ex
    warn "[RUNTIME ERROR]: #{ex.message}"
    all_lines = ""
    level = 0
  end

end
