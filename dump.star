load("@ytt:struct", "struct")
load("@ytt:yaml", "yaml")
# This converts a yamlfragment instance into a Starlark primitive value.
# This is required because unlike primitives, yamlfragments aren't mutable.
# Found at: https://github.com/carvel-dev/ytt/issues/20
def to_primitive(yaml_fragment):
  return yaml.decode(yaml.encode(yaml_fragment))
end
def _dump_one(thing, **thing_kwargs):
  if type(thing) == "yamlfragment":
    # yamlfragments serialise to useless strings
    thing = to_primitive(thing)
  elif type(thing) == "struct":
    # structs also serialise to useless strings
    if hasattr(thing, "tostr") and type(getattr(thing, "tostr")) == "function":
      tostr_func = getattr(thing, "tostr")
      thing = tostr_func()
    else:
      thing = "struct<" + repr(dir(thing)) + ">"
    end
  end
  print(thing)
end
def _dump_attrs_one(obj):
  print("*** Beginning detailed dump of object:")
  _dump_one(type(obj))
  _dump_one(obj)
  _dump_one(getattrs(obj))
  print("*** End detailed dump of object")
end
def dump_many(*things, **thing_kwargs):
  for thing in things:
    _dump_one(thing, **thing_kwargs)
  end
end
def dump_attrs_many(*things):
  for thing in things:
    _dump_attrs_one(thing)
  end
end
def _compose(func1, func2):
  def _composed(*args, **kwargs):
    return func1(func2(*args, **kwargs))
  end
  return _composed
end
def _(*args):
  return args
end
def has_attr_with_value(obj, attr_name, attr_value):
  return hasattr(obj, attr_name) and getattr(obj, attr_name) == attr_value
end
def _getattrnames(obj):
  return dir(obj)
end
def getattrs(obj):
  attr_names = _getattrnames(obj)
  return { attr_name: getattr(obj, attr_name) for attr_name in attr_names }
end
def extend(original, **new_attrs):
  attrs = getattrs(original)
  attrs.update(new_attrs)
  return struct.make(**attrs)
end
def merge(obj1, obj2):
  additional_attrs = getattrs(obj2)
  return extend(obj1, **additional_attrs)
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
def _create_object(*args, **kwargs):
  this = None
  def _getattrnames():
    return dir(this)
  end
  this = struct.make(*args, **kwargs)
  return this
end
object = struct.make(create=_create_object, getattrnames=_getattrnames)
dump = struct.make(dump=dump_many, dump_attrs=dump_attrs_many, getattrs=getattrs, merge=merge, extend=extend, _=_, to_primitive=to_primitive, curry=curry, object=object)
