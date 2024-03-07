load("@ytt:struct", "struct")
load("@ytt:yaml", "yaml")
# This converts a yamlfragment instance into a Starlark primitive value.
# This is required because unlike primitives, yamlfragments aren't mutable.
# Found at: https://github.com/carvel-dev/ytt/issues/20
def to_primitive(yaml_fragment):
  return yaml.decode(yaml.encode(yaml_fragment))
end
def _dump_one(thing):
  if type(thing) == "yamlfragment":
    # yamlfragments serialise to useless strings
    thing = to_primitive(thing)
  elif type(thing) == "struct":
    # structs also serialise to useless strings
    if "tostr" in thing and type(thing["tostr"]) == "function":
      thing = thing.tostr()
    else:
      thing = "struct<" + repr(dir(thing)) + ">"
    end
  end
  print(thing)
end
def dump_many(*things):
  for thing in things:
    _dump_one(thing)
  end
end
dump = struct.make(dump=dump_many, to_primitive=to_primitive)
