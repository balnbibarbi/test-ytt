load("@ytt:struct", "struct")
def _compose(func1, func2):
  if func2 == None:
    return func1
  elif func1 == None:
    return func2
  end
  def _composed(*args, **kwargs):
    return func1(func2(*args, **kwargs))
  end
  return _composed
end
def curry(func, *args_to_curry, **kwargs_to_curry):
  args_to_curry_wrapper = [ args_to_curry ]
  kwargs_to_curry_wrapper = [ kwargs_to_curry ]
  def curried_func(*args, **kwargs):
    args_to_curry = args_to_curry_wrapper[0] + args
    kwargs_to_curry = kwargs_to_curry_wrapper[0]
    kwargs_to_curry.update(kwargs)
    return func(*args_to_curry, **kwargs_to_curry)
  end
  return curried_func
end
def _compose_all(*funcs):
  cur_func = None
  for next_func in funcs:
    cur_func = _compose(cur_func, next_func)
  end
  return cur_func
end
def _(*args):
  return args
end
def _has_attr_with_value(obj, attr_name, attr_value):
  return _create_object(obj).has_attr_with_value(attr_name, attr_value)
end
def _getattrnames(obj):
  return _create_object(obj).getattrnames()
end
def getattrs(obj):
  return _create_object(obj).getattrs()
end
def _extend(original, **new_attrs):
  return _create_object(original).extend(**new_attrs)
end
def merge(obj1, obj2):
  return _create_object(obj1).merge(obj2)
end
def _create_object(*args, **kwargs):
  this = None
  def _getattrnames():
    return dir(this)
  end
  def _getattrs():
    attr_names = this.getattrnames()
    return { attr_name: getattr(this, attr_name) for attr_name in attr_names }
  end
  def merge(other_obj):
    additional_attrs = getattrs(other_obj)
    return _extend(this, **additional_attrs)
  end
  def _has_attr_with_value(attr_name, attr_value):
    return hasattr(this, attr_name) and getattr(this, attr_name) == attr_value
  end
  def _extend(**new_attrs):
    attrs = getattrs(this)
    attrs.update(new_attrs)
    return object.create(**attrs)
  end
  this = struct.make(*args, **kwargs)
  return this
end
object = struct.make(create=_create_object, getattrnames=_getattrnames, has_attr_with_value=_has_attr_with_value, getattrs=getattrs, merge=merge, extend=_extend, _=_, curry=curry, compose=_compose_all)
