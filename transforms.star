load("@ytt:struct", "struct")
load("@ytt:yaml", "yaml")
load("dump.star", dump="dump")
def _compose(func1, func2):
  def _composed(*args, **kwargs):
    return func1(func2(*args, **kwargs))
  end
  return _composed
end
def _(*args):
  return args
end
def _make_step(receive_func, **extra_params):
  return struct.make(receive_item=receive_func, **extra_params)
end
def _make_null_step():
  def _receive(thing, *args, **kwargs):
    return True
  end
  return _make_step(_receive)
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
  return _make_step(_receive, transform_args=transform_args, transform_kwargs=transform_kwargs)
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
  return _make_step(_receive, count=_get_count)
end
def _make_filter_step(next_step, filter_func, stop_on_success=False, stop_on_failure=False):
  def _receive(thing, *args, **kwargs):
    filter_success = filter_func(thing, *args, **kwargs)
    if filter_success:
      # Filter succeeded. Call next step.
      next_step_ret = next_step.receive_item(thing, *args, **kwargs)
      if stop_on_success:
        ret = False # Stop on first success
      else:
        ret = next_step_ret # Propagate next step's continue-iteration flag
      end
    else:
      # Filter failed. Don't call next step.
      if stop_on_failure:
        ret = False # Stop on first failure
      else:
        ret = True # Continue iterating
      end
    end
    return ret
  end
  return _make_step(_receive)
end
def _make_collect_input_step(next_step, collection):
  def _receive(thing, *args, **kwargs):
    collection.append(thing)
    return next_step.receive_item(thing, *args, **kwargs)
  end
  def _get_collection():
    return collection
  end
  return _make_step(_receive, collection=_get_collection)
end
def _make_remember_last_step(next_step):
  last_seen = [ None ]
  def _receive(thing, *args, **kwargs):
    last_seen[0] = thing
    return next_step.receive_item(thing, *args, **kwargs)
  end
  def _get_last_seen():
    return last_seen[0]
  end
  return _make_step(_receive, last_seen=_get_last_seen)
end
# Collection operations
# First member of collection that has given predicate, or None
def first(things, filter_func, *args, **kwargs):
  remember_last = _make_remember_last_step(
    _make_null_step()
  )
  pipeline = _make_filter_step(
    remember_last,
    filter_func,
    stop_on_success=True,
    stop_on_failure=False
  )
  collection = new_collection(things)
  ret = collection.iterate(pipeline, *args, **kwargs)
  return remember_last.last_seen()
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
  pipeline = _make_filter_step(
    _make_collect_input_step(
      _make_null_step(),
      subset
    ),
    filter_func,
    stop_on_success=False,
    stop_on_failure=False
  )
  collection = new_collection(things)
  ret = collection.iterate(pipeline, *args, **kwargs)
  return subset
end
# Convert collection to another collection via a transformer function
def map(things, transform_func, *args, **kwargs):
  destination = []
  pipeline = _make_transform_step(
    _make_collect_input_step(
      _make_null_step(),
      destination
    ),
    transform_func
  )
  collection = new_collection(things)
  ret = collection.iterate(pipeline, *args, **kwargs)
  return destination
end
# Pass each member of the collection to a function,
# without keeping the results of the called function.
def foreach(things, func, *args, **kwargs):
  pipeline = _make_transform_step(
    _make_null_step(),
    func
  )
  collection = new_collection(things)
  ret = collection.iterate(pipeline, *args, **kwargs)
end
# Does every member have the given predicate?
def all(things, filter_func, *args, **kwargs):
  post_filter_counter = _make_count_step(
    _make_null_step()
  )
  pre_filter_counter = _make_count_step(
    _make_filter_step(
        post_filter_counter,
        filter_func,
        stop_on_success=False,
        stop_on_failure=True
      )
  )
  collection = new_collection(things)
  ret = collection.iterate(pre_filter_counter, *args, **kwargs)
  return post_filter_counter.count() == pre_filter_counter.count();
end
# Does any member have the given predicate?
def any(things, filter_func, *args, **kwargs):
  post_filter_counter = _make_count_step(
    _make_null_step()
  )
  pipeline = _make_filter_step(
    post_filter_counter,
    filter_func,
    stop_on_success=True,
    stop_on_failure=False
  )
  collection = new_collection(things)
  ret = collection.iterate(pipeline, *args, **kwargs)
  return post_filter_counter.count() != 0;
end
# Do no members have the given predicate?
def allnot(things, filter_func, *args, **kwargs):
  return not any(things, filter_func, *args, **kwargs)
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
def new_collection(things):
  this = None
  def _iterable():
    if type(this.things) == "yaml_fragment":
      iterable = dump.to_primitive(this.things)
    elif type(this.things) == "list":
      iterable = this.things
    elif type(this.things) == "dict":
      iterable = this.things.items()
    else:
      iterable = this.things
    end
    return iterable
  end
  def _first(*args, **kwargs):
    return first(this.things, *args, **kwargs)
  end
  def _select(*args, **kwargs):
    return select(this.things, *args, **kwargs)
  end
  def _map(*args, **kwargs):
    return map(this.things, *args, **kwargs)
  end
  def _foreach(*args, **kwargs):
    return foreach(this.things, *args, **kwargs)
  end
  def _all(*args, **kwargs):
    return all(this.things, *args, **kwargs)
  end
  def _any(*args, **kwargs):
    return any(this.things, *args, **kwargs)
  end
  def _allnot(*args, **kwargs):
    return allnot(this.things, *args, **kwargs)
  end
  def _select_by_attrs(*args, **kwargs):
    return select_by_attrs(this.things, *args, **kwargs)
  end
  def _iterate(step, *args, **kwargs):
    # FIXME: Need a distinction between stopping a pipeline run for an object,
    # and stopping further pipeline runs for successive objects.
    keep_iterating = True
    for thing in this.iterable():
      if not keep_iterating:
        break
      end
      keep_iterating = step.receive_item(thing, *args, **kwargs)
    end
  end
  this = struct.make(
    things=things, iterable=_iterable, first=_first, select=_select, map=_map, foreach=_foreach, all=_all, any=_any, allnot=_allnot, select_by_attrs=_select_by_attrs, iterate=_iterate
  )
  return this
end
# FIXME: Violates the DRY principle - thrice!
# Seems no way to import * in ytt
# TODO: Work around this by pre-processing this YAML code,
# appending all functions to each source file, to disuse load
transforms = struct.make(first=first, select=select, map=map, foreach=foreach, all=all, any=any, allnot=allnot, select_by_attrs=select_by_attrs, new_collection=new_collection)
