load("@ytt:struct", "struct")
load("@ytt:yaml", "yaml")
def dump_one(thing):
  if type(thing) == "yamlfragment":
    # yamlfragments serialise to useless strings
    thing = to_primitive(thing)
  end
  print(thing)
end
def dump(*things):
  for thing in things:
    dump_one(thing)
  end
end
# Found at: https://github.com/carvel-dev/ytt/issues/20
def to_primitive(yaml_fragment):
  return yaml.decode(yaml.encode(yaml_fragment))
end
# Test whether the given object has all of the given
# attributes, with the given values.
def has_attrs(object, attrs):
  for attr_name, attr_value in attrs.items():
    if attr_name not in object:
      return False
    elif object[attr_name] != attr_value:
      return False
    end
  end
  return True
end
# Find the array item that has an attribute of the given name
# whose value is the given value.
# Return a tuple of (element_index, element_value) if found,
# or (None, None) if no matching element was found.
def select(array, **attrs):
  for index in range(len(array)):
    element = array[index]
    if has_attrs(element, attrs):
      return (index, element)
    end
  end
  return (None, None)
end
# FIXME: Violates the DRY principle - thrice!
# Seems no way to import * in ytt
# TODO: Work around this by pre-processing this YAML code,
# appending all functions to each source file, to disuse load
transforms = struct.make(to_primitive=to_primitive, select=select, dump=dump)
