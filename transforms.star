load("@ytt:struct", "struct")
load("@ytt:yaml", "yaml")
def dump_one(thing):
  if type(thing) == "yamlfragment":
    # yamlfragments serialise to useless strings
    thing = to_primitive(thing)
  end
  print(thing)
end
def map(func, *things):
  results = []
  for thing in things:
    result = func(thing)
    results.append(result)
  end
  return results
end
def filter(func, *things):
  results = []
  for thing in things:
    result = func(thing)
    if result:
      results.append(thing)
    end
  end
  return results
end
def dump(*things):
  map(dump_one, *things)
end
# This converts a yamlfragment instance into a Starlark primitive value.
# This is required because unlike primitives, yamlfragments aren't mutable.
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
# Find the first element in the given array that has all of the given
# attribute names and values.
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
# Find all elements in the given array that have all of the given
# attribute names and values.
# Return a tuple of tuples of (element_index, element_value),
# or an empty tuple if no matching elements were found.
def select_all(array, **attrs):
  ret = []
  for index in range(len(array)):
    element = array[index]
    if has_attrs(element, attrs):
      ret += (index, element)
    end
  end
  return tuple(ret)
end
# FIXME: Violates the DRY principle - thrice!
# Seems no way to import * in ytt
# TODO: Work around this by pre-processing this YAML code,
# appending all functions to each source file, to disuse load
transforms = struct.make(to_primitive=to_primitive, select=select, dump=dump, dump_one=dump_one, map=map, filter=filter)
