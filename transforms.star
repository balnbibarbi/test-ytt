load("@ytt:struct", "struct")
load("@ytt:yaml", "yaml")
def dump(thing):
  print(thing)
  for val in thing:
    print(val)
    print(thing[val])
  end
end
def copy_all_except_map(src, dst, omissions):
  for name in src:
    if name not in omissions:
      dst[name] = src[name]
    end
  end
end
def copy_all_except_array(src, dst, omitted_indices):
  for index in range(len(src)):
    if index not in omitted_indices:
      dst[index] = src[index]
    end
  end
end
# make_modified_copy_map and make_modified_copy_array
# are both workarounds for the following not working:
# input["somename"] = "newvalue"
# which fails with:
# ytt: Error: Overlaying (in following order: transform.yaml):
#   Document on line transform.yaml:14: yamlfragment.SetKey:
#     Not implemented
# Primitive values in {Star|Sky}Lark can, by contrast, be modified in-place.
# However, there is no way to convert a yamlfragment into a primitive value,
# and input values are always yamlfragments not primitive values.
# These restrictions together make it impossible to modify our input values in place.
def make_modified_copy_map(src, attr_name, new_attr_value):
  dst = {}
  copy_all_except_map(src, dst, [ attr_name ])
  dst[attr_name] = new_attr_value
  return dst
end
def make_modified_copy_array(src, index, new_value):
  dst = [None] * len(src)
  copy_all_except_array(src, dst, [ index ])
  dst[index] = new_value
  return dst
end
# Found at: https://github.com/carvel-dev/ytt/issues/20
def to_primitive(yaml_fragment):
  return yaml.decode(yaml.encode(yaml_fragment))
end
def yamlfragment_type(yaml_fragment):
  return type(to_primitive(yaml_fragment))
end
def make_modified_copy(src, replace_at, replace_with):
  replace_at_type = yamlfragment_type(src)
  if replace_at_type == "dict":
    return make_modified_copy_map(src, replace_at, replace_with)
  elif replace_at_type == "list":
    return make_modified_copy_array(src, replace_at, replace_with)
  else:
    # starskylark does not support exceptions
    fail("Unsupported type " + replace_at_type)
  end
end

# FIXME: Violates the DRY principle - thrice!
# Seems no way to import * in ytt
# TODO: Work around this by pre-processing this YAML code,
# appending all functions to each source file, to disuse load
transforms = struct.make(make_modified_copy_map=make_modified_copy_map, make_modified_copy_array=make_modified_copy_array, make_modified_copy=make_modified_copy, dump=dump)
