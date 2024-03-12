load("@ytt:struct", "struct")

def _create_clazz(constructor):
  def create(*args, **kwargs):
    return constructor(*args, **kwargs)
  end
  return create
end

clazz = struct.make(create=_create_clazz)
