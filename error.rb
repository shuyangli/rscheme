module RScheme
  class RSchemeError < StandardError; end
  class RSchemeLexingError < RSchemeError; end

  class RSchemeParsingError < RSchemeError; end
  class RSchemeExprNotTerminatedError < RSchemeParsingError; end

  class RSchemeRuntimeError < RSchemeError; end
  class RSchemeNameError < RSchemeRuntimeError; end
end
