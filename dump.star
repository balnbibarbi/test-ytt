load("@ytt:struct", "struct")
load("@ytt:yaml", "yaml")
load("object.star", object="object")
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
  _dump_one(object.getattrs(obj))
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
dump = struct.make(dump=dump_many, dump_attrs=dump_attrs_many, to_primitive=to_primitive)
