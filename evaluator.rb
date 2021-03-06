require './error.rb'

module RScheme

  class Evaluator

    def initialize
      @global_env = {}                  # Global environment storing bindings
    end

    def eval(token_tree)
      res = []
      token_tree.each do |expr|
        res = evaluate_in_env(@global_env, expr)
      end
      res
    end

    def evaluate_in_env(env, token_tree)
      # Handwritten grammar!
      case token_tree[0]
      when :INTEGER_TYPE, :REAL_TYPE, :BOOLEAN_TYPE, :STRING_TYPE # Value literal
        token_tree                      # Return literal value
      when :IDENT                       # Identifier
        identifier = token_tree[1]
        env_lookup(env, identifier)     # Return value bound to identifier
      when :LIST_TYPE                   # List
        _, *xs = token_tree
        case xs[0][0]
        when :KEYWORD
          keyword_item = xs[0][1]
          case keyword_item             # Dispatch on each keyword
          when :QUOTE
            xs[1]                       # If it's quote, we return the literal value
          when :DEFINE, :ASSIGN         # They are basically the same
            # [[:KEYWORD, :DEFINE], [:IDENT, name], [expr]]
            identifier = xs[1][1]                         # identifier
            env_extend(env, identifier)                   # extend env first for recursion
            expr_value = evaluate_in_env(env, xs[2])      # evaluate expr
            env_bind(env, identifier, expr_value)         # bind
            nil
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
              env_bind(let_env, binding[1][1], evaluate_in_env(env, binding[2]))
            end
            body = xs[2]
            return evaluate_in_env(let_env, body)         # evaluate body in new env
          when :LETSEQ
            # [:KEYWORD, :LETSEQ],
            #   [:LIST_TYPE,
            #     [:LIST_TYPE, [:IDENT, name], [value]], ...],
            #   [body]
            let_env = env.clone                           # clone environment
            _, *binding_list = xs[1]                      # extract bindings
            binding_list.each do |binding|
              env.bind(let_env, binding[1][1], evaluate_in_env(let_env, binding[2]))
            end
            body = xs[2]
            return evaluate_in_env(let_env, body)         # evaluate body in new env
          when :LETREC
            # [:KEYWORD, :LETREQ],
            #   [:LIST_TYPE,
            #     [:LIST_TYPE, [:IDENT, name], [value]], ...],
            #   [body]
            let_env = env.clone
            _, *binding_list = xs[1]
            binding_list.each do |binding|                # first round extends the environment
              env.extend(let_env, binding[1][1])
            end
            binding_list.each do |binding|                # second round binds the values
              env.bind(let_env, binding[1][1], evaluate_in_env(let_env, binding[2]))
            end
            body = xs[2]
            return evaluate_in_env(let_env, body)
          when :CAR
            list = evaluate_in_env(env, xs[1])
            raise RSchemeRuntimeError, "CAR applied to non-list #{xs[1]}" if list[0] != :LIST_TYPE
            list[1]
          when :CDR
            list = evaluate_in_env(env, xs[1])
            raise RSchemeRuntimeError, "CAR applied to non-list #{xs[1]}" if list[0] != :LIST_TYPE
            [:LIST_TYPE].concat(list[2..list.length])
          when :CONS
            value = evaluate_in_env(env, xs[1])
            list = evaluate_in_env(env, xs[2])
            raise RSchemeRuntimeError, "CONS applied to non-list #{xs[2]}" if list[0] != :LIST_TYPE
            [:LIST_TYPE, value].concat(list[1..list.length])
          else
            raise RSchemeRuntimeError, "Unrecognized keyword #{keyword_item}"
          end
        when :IDENT                     # Identifier, hopefully a closure
          identifier = xs[0][1]
          closure = env_lookup(env, identifier)         # Look up the closure first
          evaluated_token_tree = [:LIST_TYPE, closure].concat xs[1..token_tree.length]
          evaluate_in_env(env, evaluated_token_tree)    # Then evaluate the whole tree
        when :LIST_TYPE
          evaluated_list = evaluate_in_env(env, xs[0])  # Evaluate the list first
          evaluated_token_tree = [:LIST_TYPE, evaluated_list].concat xs[1..token_tree.length]
          evaluate_in_env(env, evaluated_token_tree)    # Then evaluate the whole tree
        when :OPERATOR
          op = xs[0][1]
          case op
          when :PLUS
            _, *args = xs

            # Evaluate arguments
            args_evaluated = args.map { |item| evaluate_in_env(env, item) }

            types, values = args_evaluated.transpose
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

            # Evaluate arguments
            arg1 = evaluate_in_env(env, arg1)
            args_evaluated = args.map { |item| evaluate_in_env(env, item) }

            # Handle one-arg case
            raise RSchemeRuntimeError, "- operator applied to non-number #{arg1}" unless arg1[0] == :INTEGER_TYPE or arg1[0] == :REAL_TYPE
            return [arg1[0], -arg1[1]] if args_evaluated.empty?

            types, values = args_evaluated.transpose
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

            # Evaluate arguments
            args_evaluated = args.map { |item| evaluate_in_env(env, item) }

            types, values = args_evaluated.transpose
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

            # Evaluate arguments
            arg1 = evaluate_in_env(env, arg1)
            args_evaluated = args.map { |item| evaluate_in_env(env, item) }

            # Handle one-arg case
            raise RSchemeRuntimeError, "/ operator applied to non-number #{arg1}" unless arg1[0] == :INTEGER_TYPE or arg1[0] == :REAL_TYPE
            raise RSchemeRuntimeError, "Division by zero" if arg1[1] == 0 and args_evaluated.empty?
            return [:REAL_TYPE, 1 / arg1[1].to_f] if args_evaluated.empty?

            types, values = args_evaluated.transpose
            types_legal = types.inject(true) do |acc, item|
              if !acc
                false
              else
                item == :INTEGER_TYPE or item == :REAL_TYPE
              end
            end

            raise RSchemeRuntimeError, "- operator applied to non-numbers: #{arg1}, #{values}" unless types_legal
            values.unshift arg1[1]
            value_res = values.map(&:to_f).inject(&:/)
            return [:REAL_TYPE, value_res]
          when :EQUAL
            _, *args = xs

            # Evaluate arguments
            args_evaluated = args.map { |item| evaluate_in_env(env, item) }
            type, value = args_evaluated[0]

            args_evaluated[1..args_evaluated.length].each do |item|
              item_type, item_value = item
              raise RSchemeRuntimeError, "Wrong type: = expected #{type}, received #{item_type}" unless item_type == type or [item_type, type] == [:INTEGER_TYPE, :REAL_TYPE] or [item_type, type] == [:REAL_TYPE, :INTEGER_TYPE]
              return [:BOOLEAN_TYPE, false] if item_value != value
              type, value = item_type, item_value
            end
            return [:BOOLEAN_TYPE, true]
          when :LT
            _, *args = xs

            # Evaluate arguments
            args_evaluated = args.map { |item| evaluate_in_env(env, item) }
            type, value = args_evaluated[0]

            raise RSchemeRuntimeError, "Wrong type: < expected #{:INTEGER_TYPE} or #{:REAL_TYPE}, received #{type}" unless type == :INTEGER_TYPE or type == :REAL_TYPE

            args_evaluated[1..args_evaluated.length].each do |item|
              item_type, item_value = item
              raise RSchemeRuntimeError, "Wrong type: < expected #{:INTEGER_TYPE} or #{:REAL_TYPE}, received #{type}" unless item_type == :INTEGER_TYPE or type == :REAL_TYPE
              return [:BOOLEAN_TYPE, false] unless value < item_value
              type, value = item_type, item_value
            end
            return [:BOOLEAN_TYPE, true]
          when :LE
            _, *args = xs

            # Evaluate arguments
            args_evaluated = args.map { |item| evaluate_in_env(env, item) }
            type, value = args_evaluated[0]

            raise RSchemeRuntimeError, "Wrong type: <= expected #{:INTEGER_TYPE} or #{:REAL_TYPE}, received #{type}" unless type == :INTEGER_TYPE or type == :REAL_TYPE

            args_evaluated[1..args_evaluated.length].each do |item|
              item_type, item_value = item
              raise RSchemeRuntimeError, "Wrong type: <= expected #{:INTEGER_TYPE} or #{:REAL_TYPE}, received #{type}" unless item_type == :INTEGER_TYPE or type == :REAL_TYPE
              return [:BOOLEAN_TYPE, false] unless value <= item_value
              type, value = item_type, item_value
            end
            return [:BOOLEAN_TYPE, true]
          when :GT
            _, *args = xs

            # Evaluate arguments
            args_evaluated = args.map { |item| evaluate_in_env(env, item) }
            type, value = args_evaluated[0]

            raise RSchemeRuntimeError, "Wrong type: > expected #{:INTEGER_TYPE} or #{:REAL_TYPE}, received #{type}" unless type == :INTEGER_TYPE or type == :REAL_TYPE

            args_evaluated[1..args_evaluated.length].each do |item|
              item_type, item_value = item
              raise RSchemeRuntimeError, "Wrong type: > expected #{:INTEGER_TYPE} or #{:REAL_TYPE}, received #{type}" unless item_type == :INTEGER_TYPE or type == :REAL_TYPE
              return [:BOOLEAN_TYPE, false] unless value > item_value
              type, value = item_type, item_value
            end
            return [:BOOLEAN_TYPE, true]
          when :GE
            _, *args = xs

            # Evaluate arguments
            args_evaluated = args.map { |item| evaluate_in_env(env, item) }
            type, value = args_evaluated[0]

            raise RSchemeRuntimeError, "Wrong type: >= expected #{:INTEGER_TYPE} or #{:REAL_TYPE}, received #{type}" unless type == :INTEGER_TYPE or type == :REAL_TYPE

            args_evaluated[1..args_evaluated.length].each do |item|
              item_type, item_value = item
              raise RSchemeRuntimeError, "Wrong type: >= expected #{:INTEGER_TYPE} or #{:REAL_TYPE}, received #{type}" unless item_type == :INTEGER_TYPE or type == :REAL_TYPE
              return [:BOOLEAN_TYPE, false] unless value >= item_value
              type, value = item_type, item_value
            end
            return [:BOOLEAN_TYPE, true]
          when :AND
            _, *args = xs
            # Evaluate arguments in order, short-circuiting
            args[1..args.length].each do |arg|
              type, value = evaluate_in_env(env, arg)
              raise RSchemeRuntimeError, "Wrong type: = expected BOOLEAN_TYPE, received #{type}" unless type == :BOOLEAN_TYPE
              return [:BOOLEAN_TYPE, false] unless value
            end
            return [:BOOLEAN_TYPE, true]
          when :OR
            _, *args = xs
            # Evaluate arguments in order, short-circuiting
            args[1..args.length].each do |arg|
              type, value = evaluate_in_env(env, arg)
              raise RSchemeRuntimeError, "Wrong type: = expected BOOLEAN_TYPE, received #{type}" unless type == :BOOLEAN_TYPE
              return [:BOOLEAN_TYPE, true] if value
            end
            return [:BOOLEAN_TYPE, false]
          when :NOT
            _, *args = xs
            raise RSchemeRuntimeError, "Wrong number of arguments" if args.length != 1
            # Evaluate arguments in order, short-circuiting
            type, value = evaluate_in_env(env, args[0])
            raise RSchemeRuntimeError, "Wrong type: = expected BOOLEAN_TYPE, received #{type}" unless type == :BOOLEAN_TYPE
            return [:BOOLEAN_TYPE, !value]
          end
        when :CLOSURE
          closure = xs[0]
          # [:CLOSURE, { :ENVIRONMENT  => env.clone,
          #              :FORMAL_LIST  => formal_list,
          #              :CLOSURE_BODY => closure_body }]
          clos_env = closure[1][:ENVIRONMENT]
          clos_formal_list = closure[1][:FORMAL_LIST]
          clos_body = closure[1][:CLOSURE_BODY]
          raise RSchemeRuntimeError, "Invalid closure: #{closure}" unless closure[0] == :CLOSURE

          # Evaluate the actual list
          actual_list = xs[1..xs.length].map { |token| evaluate_in_env(env, token) }

          # Bind the formals to the actuals
          raise RSchemeRuntimeError, "#{identifier} called with wrong number of arguments: expected #{clos_formal_list.length}, received #{actual_list.length}" if clos_formal_list.length != actual_list.length

          zipped_formals = clos_formal_list.zip(actual_list)
          zipped_formals.each do |formal, actual|
            env_bind(clos_env, formal[1], actual)   # formal[1]: actual identifier
          end

          # Evaluate closure body with the closure environment
          evaluate_in_env(clos_env, clos_body)
        else
          raise RSchemeRuntimeError, "Cannot apply #{token_tree[0][1]}"
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

