load("@ytt:struct", "struct")

def _create_clazz(constructor, **extra_params):
  def _get_constructor():
    return constructor
  end
  return struct.make(create=constructor, constructor=_get_constructor(), **extra_params)
end

clazz = struct.make(create=_create_clazz)
