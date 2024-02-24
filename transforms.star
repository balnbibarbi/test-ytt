load("@ytt:struct", "struct")
load("@ytt:yaml", "yaml")
def dump(thing):
  print(thing)
  for val in thing:
    print(val)
    print(thing[val])
  end
end
# Found at: https://github.com/carvel-dev/ytt/issues/20
def to_primitive(yaml_fragment):
  return yaml.decode(yaml.encode(yaml_fragment))
end
def yamlfragment_type(yaml_fragment):
  return type(to_primitive(yaml_fragment))
end
# FIXME: Violates the DRY principle - thrice!
# Seems no way to import * in ytt
# TODO: Work around this by pre-processing this YAML code,
# appending all functions to each source file, to disuse load
transforms = struct.make(to_primitive=to_primitive, dump=dump)
