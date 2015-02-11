load "./parser.rb"

module RScheme

  class Evaluator

    class RSchemeRuntimeError < RSchemeError; end

    # Used when an identifier is not defined in the current environment
    class RSchemeNameError < RSchemeError; end

    def initialize
      @parser = Parser.new   # Parser
      @global_env = {}            # Global environment storing bindings
    end

    def evaluate_string(str)
      token_tree = @parser.process_line(str)
      return if token_tree == :expr_not_terminated
      evaluate_in_env(@global_env, token_tree[0])
    end

    def evaluate_in_env(env, token_tree)
      # Handwritten grammar!
      case token_tree[0]
      when :INTEGER_TYPE, :REAL_TYPE, :BOOLEAN_TYPE, :STRING_TYPE # Value literal
        return token_tree[0][1]         # Return literal value
      when :IDENT                       # Identifier
        identifier = token_tree[0][1]
        return env_lookup(env, identifier)     # Return value bound to identifier
      when :LIST_TYPE                   # List
        _, *xs = token_tree
        case xs[0][0]
        when :KEYWORD
          keyword_item = xs[0][1]
          warn keyword_item.inspect
          case keyword_item             # Dispatch on each keyword
          when :QUOTE
            return xs[1]                # If it's quote, we return the literal value
          when :DEFINE, :ASSIGN         # They are basically the same
            # [[:KEYWORD, :DEFINE], [:IDENT, name], [expr]]
            identifier = xs[1][1]                         # identifier
            env_extend(env, identifier)                   # extend env first for recursion
            expr_value = evaluate_in_env(env, xs[2])      # evaluate expr
            env_bind(env, identifier, expr_value)         # bind
            return nil
          when :LAMBDA
            # [[:LIST_TYPE,
            #   [:KEYWORD, :LAMBDA],
            #   [:LIST_TYPE, [:IDENT, name], ...],
            #  [body]]]
            _, *formal_list = xs[1]
            closure_body = xs[2]
            return [:CLOSURE, { :ENVIRONMENT  => env.clone,
                                :FORMAL_LIST  => formal_list,
                                :CLOSURE_BODY => closure_body }]
          when :IF
            # [:KEYWORD, :IF],
            #   [test_expr],
            #   [true_expr],
            #   [false_expr]
            type, test_result = evaluate_in_env(env, xs[1])     # evaluate test_expr
            if test_result == false                             # Scheme treats anything but #f as truthy
              return evaluate_in_env(env, xs[3])
            else
              return evaluate_in_env(env, xs[2])
            end
          when :LET
            # [:KEYWORD, :LET],
            #   [:LIST_TYPE,
            #     [:LIST_TYPE, [:IDENT, name], [value]], ...],
            #   [body]
            let_env = env.clone                           # clone environment
            _, *binding_list = xs[1]                      # extract bindings
            binding_list.each do |binding|
              env.bind(let_env, binding[1][1], evaluate_in_env(env, binding[2]))
            end
            body = xs[2]
            evaluate_in_env(let_env, body)                # evaluate body in new env
          when :LETSEQ
            let_env = env.clone                           # clone environment
            _, *binding_list = xs[1]                      # extract bindings
            binding_list.each do |binding|
              env.bind(let_env, binding[1][1], evaluate_in_env(let_env, binding[2]))
            end
            body = xs[2]
            evaluate_in_env(let_env, body)                # evaluate body in new env
          when :LETREC
            let_env = env.clone
            _, *binding_list = xs[1]
            binding_list.each do |binding|                # first round extends the environment
              env.extend(let_env, binding[1][1])
            end
            binding_list.each do |binding|                # second round binds the values
              env.bind(let_env, binding[1][1], evaluate_in_env(let_env, binding[2]))
            end
            body = xs[2]
            evaluate_in_env(let_env, body)
          else
            raise RSchemeRuntimeError "Unrecognized keyword #{keyword_item}"
          end
        when :IDENT                     # Identifier, hopefully a closure
          identifier = xs[0][1]
          closure = env_lookup(env, identifier)
          # [:CLOSURE, { :ENVIRONMENT  => env.clone,
          #              :FORMAL_LIST  => formal_list,
          #              :CLOSURE_BODY => closure_body }]
          clos_env = closure[1][:ENVIRONMENT]
          clos_formal_list = closure[1][:FORMAL_LIST]
          clos_body = closure[1][:CLOSURE_BODY]
          raise RSchemeRuntimeError, "#{identifier} is not bound to a closure" unless closure[0] == :CLOSURE
          # Bind the closure's identifier to its body
          env_bind(clos_env, identifier, closure)

          # Evaluate the actual list
          actual_list = xs[1..xs.length].map { |token| evaluate_in_env(env, token) }

          # Bind the formals to the actuals
          raise RSchemeRuntimeError, "#{identifier} called with wrong number of arguments: expected #{clos_formal_list.length}, received #{actual_list.length}" if clos_formal_list.length != actual_list.length
          zipped_formals = clos_formal_list.zip(actual_list)
          zipped_formals.each do |formal, actual|
            env_bind(clos_env, formal, actual)
          end

          # Evaluate closure body with the closure environment
          evaluate_in_env(env, clos_body)
        when :OPERATOR
          op = xs[0][1]
          case op
          when :PLUS
            _, *args = xs
            types, values = args.transpose
            types_legal = types.inject(true) do |acc, item|
              if !acc
                false
              else
                item == :INTEGER_TYPE or item == :REAL_TYPE
              end
            end

            raise RSchemeRuntimeError, "+ operator applied to non-numbers: #{values}" unless types_legal
            value_sum = values.inject(&:+)

            return [:INTEGER_TYPE, value_sum] if value_sum.is_a? Integer
            return [:REAL_TYPE, value_sum]
          when :MINUS
            _, arg1, *args = xs

            # Handle one-arg case
            raise RSchemeRuntimeError, "- operator applied to non-number #{arg1}" unless arg1[0] == :INTEGER_TYPE or arg1[0] == :REAL_TYPE
            return [arg1[0], -arg1[1]] if args.empty?

            types, values = args.transpose
            types_legal = types.inject(true) do |acc, item|
              if !acc
                false
              else
                item == :INTEGER_TYPE or item == :REAL_TYPE
              end
            end

            raise RSchemeRuntimeError, "- operator applied to non-numbers: #{arg1}, #{values}" unless types_legal
            value_sum = arg1[1] - values.inject(&:+)

            return [:INTEGER_TYPE, value_sum] if value_sum.is_a? Integer
            return [:REAL_TYPE, value_sum]
          when :MULT
            _, *args = xs
            types, values = args.transpose
            types_legal = types.inject(true) do |acc, item|
              if !acc
                false
              else
                item == :INTEGER_TYPE or item == :REAL_TYPE
              end
            end

            raise RSchemeRuntimeError, "* operator applied to non-numbers: #{values}" unless types_legal
            value_prod = values.inject(&:*)

            return [:INTEGER_TYPE, value_prod] if value_prod.is_a? Integer
            return [:REAL_TYPE, value_prod]
          when :DIV
            _, arg1, *args = xs

            # Handle one-arg case
            raise RSchemeRuntimeError, "/ operator applied to non-number #{arg1}" unless arg1[0] == :INTEGER_TYPE or arg1[0] == :REAL_TYPE
            raise RSchemeRuntimeError, "Division by zero" if arg1[1] == 0 and args.empty?
            return [:REAL_TYPE, 1 / arg1[1].to_f] if args.empty?

            types, values = args.transpose
            types_legal = types.inject(true) do |acc, item|
              if !acc
                false
              else
                item == :INTEGER_TYPE or item == :REAL_TYPE
              end
            end

            raise RSchemeRuntimeError, "- operator applied to non-numbers: #{arg1}, #{values}" unless types_legal
            values.unshift arg1[1]
            values_res = values.map(&:to_f).inject(&:/)
            return [:REAL_TYPE, value_res]
          when :EQUAL
          when :LT
          when :LE
          when :GT
          when :GE
          end
        end
      else
        raise RSchemeRuntimeError, "Unrecognized token type #{token_tree[0]}"
      end
    end


    def env_lookup(env, identifier)
      raise RSchemeNameError, "Unbound identifier #{identifier}" unless env.include?(identifier)
      env[identifier]
    end
    def env_extend(env, identifier)
      env[identifier] ||= nil
      nil
    end
    def env_bind(env, identifier, value)
      env[identifier] = value
      env
    end

  end

end
