load("@ytt:struct", "struct")
load("@ytt:yaml", "yaml")
def dump_one(thing):
  if type(thing) == "yamlfragment":
    # yamlfragments serialise to useless strings
    thing = to_primitive(thing)
  elif type(thing) == "struct":
    # structs also serialise to useless strings
    thing = "struct<" + repr(dir(thing)) + ">"
  end
  print(thing)
end
def dump(*things):
  for thing in things:
    dump_one(thing)
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
def _make_null_step():
  def _receive(thing, *args, **kwargs):
    return True
  end
  step = struct.make(receive_item=_receive)
  return step
end
def _iterate(things, step, *args, **kwargs):
  if type(things) == "list":
    iterable = things
  elif type(things) == "dict":
    iterable = things.items()
  else:
    iterable = things
  end
  for thing in iterable:
    keep_iterating = step.receive_item(thing, *args, **kwargs)
    if not keep_iterating:
      break
    end
  end
end
def _make_transform_step(next_step, transform_func, *transform_args, **transform_kwargs):
  def _receive(thing, *args, **kwargs):
    return next_step.receive_item(
      transform_func(
        thing,
        *transform_args,
        **transform_kwargs
      ),
      *args,
      **kwargs
    )
  end
  step = struct.make(receive_item=_receive, transform_args=transform_args, transform_kwargs=transform_kwargs)
  return step
end
def _make_count_step(next_step):
  count = [ 0 ]
  def _receive(thing, *args, **kwargs):
    count[0] += 1
    return next_step.receive_item(thing, *args, **kwargs)
  end
  def _get_count():
    return count[0]
  end
  step = struct.make(receive_item=_receive, count=_get_count)
  return step
end
def _make_filter_step(next_step, filter_func):
  def _receive(thing, *args, **kwargs):
    filter_success = filter_func(thing, *args, **kwargs)
    if filter_success:
      return next_step.receive_item(thing, *args, **kwargs)
    end
    return False  # Stop iterating
  end
  step = struct.make(receive_item=_receive)
  return step
end
def _make_stop_step(next_step):
  def _receive(thing, *args, **kwargs):
    # Ignore return value
    next_step.receive_item(thing, *args, **kwargs)
    return False
  end
  step = struct.make(receive_item=_receive)
  return step
end
def _make_continue_step(next_step):
  def _receive(thing, *args, **kwargs):
    # Ignore return value
    next_step.receive_item(thing, *args, **kwargs)
    return True
  end
  step = struct.make(receive_item=_receive)
  return step
end
def _make_collect_input_step(next_step, collection):
  def _receive(thing, *args, **kwargs):
    collection.append(thing)
    return next_step.receive_item(thing, *args, **kwargs)
  end
  step = struct.make(receive_item=_receive)
  return step
end
def _make_remember_last_step(next_step):
  last_seen = None
  def _receive(thing, *args, **kwargs):
    last_seen = thing
    return next_step.receive_item(thing, *args, **kwargs)
  end
  step = struct.make(receive_item=_receive, last_seen=last_seen)
  return step
end
# Collection operations
# First member of collection that has given predicate, or None
def first(things, filter_func, *args, **kwargs):
  remember_last = _make_remember_last_step(
    _make_filter_step(
      _make_null_step(),
      filter_func
    )
  )
  pipeline = _make_stop_step(remember_last)
  ret = _iterate(things, pipeline, *args, **kwargs)
  return remember_last.last_seen
end
# Sub-collection of collection whose members have given predicate
def select(things, filter_func, *args, **kwargs):
  if type(things) == "list":
    subset = []
  elif type(things) == "dict":
    subset = {}
  else:
    subset = {}
  end
  pipeline = _make_continue_step(
    _make_filter_step(
      _make_collect_input_step(
        _make_null_step(),
        subset
      ),
      filter_func
    )
  )
  ret = _iterate(things, pipeline, *args, **kwargs)
  return subset
end
# Convert collection to another collection via a transformer function
def map(collection, transform_func, *args, **kwargs):
  destination = []
  pipeline = _make_transform_step(
    _make_collect_input_step(
      _make_null_step(),
      destination
    ),
    transform_func
  )
  ret = _iterate(collection, pipeline, *args, **kwargs)
  return destination
end
# Pass each member of the collection to a function,
# without keeping the results of the called function.
def foreach(collection, func, *args, **kwargs):
  pipeline = _make_continue_step(
    _make_null_step()
  )
  ret = _iterate(collection, pipeline, *args, **kwargs)
end
# Does every member have the given predicate?
def all(things, filter_func, *args, **kwargs):
  pre_filter_counter = _make_count_step(
    _make_null_step()
  )
  filter_step = _make_filter_step(
    pre_filter_counter,
    filter_func
  )
  post_filter_counter = _make_count_step(
    filter_step
  )
  ret = _iterate(things, post_filter_counter, *args, **kwargs)
  return pre_filter_counter.count() == post_filter_counter.count();
end
# Does any member have the given predicate?
def any(things, filter_func, *args, **kwargs):
  post_filter_counter = _make_count_step(
    _make_stop_step(
      _make_filter_step(
        _make_null_step(),
        filter_func
      )
    )
  )
  ret = _iterate(things, post_filter_counter, *args, **kwargs)
  return post_filter_counter.count != 0;
end
# Do no members have the given predicate?
def allnot(things, filter_func, *args, **kwargs):
  return not any(things, filter_func, *args, **kwargs)
end
# This converts a yamlfragment instance into a Starlark primitive value.
# This is required because unlike primitives, yamlfragments aren't mutable.
# Found at: https://github.com/carvel-dev/ytt/issues/20
def to_primitive(yaml_fragment):
  return yaml.decode(yaml.encode(yaml_fragment))
end
# Test whether the given object has all of the given
# attributes, with the given values.
def _object_has_attrs(object, attrs):
  def _attr_ison_object(attr, object):
    (attr_name, attr_value) = attr
    if attr_name not in object:
      return False
    elif object[attr_name] != attr_value:
      return False
    end
    return True
  end
  return all(attrs, _attr_ison_object, object)
end
def select_by_attrs(objects, **attrs):
  return select(objects, _object_has_attrs, attrs)
end
# FIXME: Violates the DRY principle - thrice!
# Seems no way to import * in ytt
# TODO: Work around this by pre-processing this YAML code,
# appending all functions to each source file, to disuse load
transforms = struct.make(to_primitive=to_primitive, dump=dump, dump_one=dump_one, first=first, select=select, map=map, foreach=foreach, all=all, any=any, allnot=allnot, select_by_attrs=select_by_attrs)
