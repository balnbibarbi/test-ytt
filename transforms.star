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
def _make_step(receive_func, tostr_func, **extra_params):
  def tostr():
    return "Step<" + repr(receive_func) + ">"
  end
  return struct.make(receive_item=receive_func, tostr=tostr_func, **extra_params)
end
def _make_null_step():
  def tostr():
    return "NullStep<>"
  end
  def _receive(thing, *args, **kwargs):
    return True
  end
  return _make_step(_receive, tostr)
end
def _make_transform_step(next_step, transform_func, *transform_args, **transform_kwargs):
  def tostr():
    return "TransformStep<" + repr(transform_func) + ">"
  end
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
  return _make_step(_receive, tostr, transform_args=transform_args, transform_kwargs=transform_kwargs)
end
def _make_count_step(next_step):
  def tostr():
    return "CountStep<>"
  end
  count = [ 0 ]
  def _receive(thing, *args, **kwargs):
    count[0] += 1
    return next_step.receive_item(thing, *args, **kwargs)
  end
  def _get_count():
    return count[0]
  end
  return _make_step(_receive, tostr, count=_get_count)
end
def _make_filter_step(next_step, filter_func, stop_on_success=False, stop_on_failure=False):
  def tostr():
    return "FilterStep<" + repr(filter_func) + ">"
  end
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
  return _make_step(_receive, tostr)
end
def _make_collect_input_step(next_step, collection):
  def tostr():
    return "CollectStep<" + repr(collection) + ">"
  end
  def _receive(thing, *args, **kwargs):
    collection.append(thing)
    return next_step.receive_item(thing, *args, **kwargs)
  end
  def _get_collection():
    return collection
  end
  return _make_step(_receive, tostr, collection=_get_collection)
end
def _make_remember_last_step(next_step):
  def tostr():
    return "RememberLastStep<>"
  end
  last_seen = [ None ]
  def _receive(thing, *args, **kwargs):
    last_seen[0] = thing
    return next_step.receive_item(thing, *args, **kwargs)
  end
  def _get_last_seen():
    return last_seen[0]
  end
  return _make_step(_receive, tostr, last_seen=_get_last_seen)
end
# Collection operations
def first(things, filter_func, *args, **kwargs):
  collection = new_collection(things)
  return collection.first(filter_func, *args, **kwargs)
end
def foreach(things, func, *args, **kwargs):
  collection = new_collection(things)
  return collection.foreach(func, *args, **kwargs)
end
def all(things, filter_func, *args, **kwargs):
  collection = new_collection(things)
  return collection.all(filter_func, *args, **kwargs)
end
def any(things, filter_func, *args, **kwargs):
  collection = new_collection(things)
  return collection.any(filter_func, *args, **kwargs)
end
def allnot(things, filter_func, *args, **kwargs):
  collection = new_collection(things)
  return collection.allnot(filter_func, *args, **kwargs)
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
  # First member of collection that has given predicate, or None
  def first(filter_func, *args, **kwargs):
    remember_last = _make_remember_last_step(
      _make_null_step()
    )
    pipeline = _make_filter_step(
      remember_last,
      filter_func,
      stop_on_success=True,
      stop_on_failure=False
    )
    ret = this.iterate(pipeline, *args, **kwargs)
    return remember_last.last_seen()
  end
  # Sub-collection of collection whose members have given predicate
  def select(filter_func, *args, **kwargs):
    if type(this.things) == "list":
      subset = []
    elif type(this.things) == "dict":
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
    ret = this.iterate(pipeline, *args, **kwargs)
    return subset
  end
  # Convert collection to another collection via a transformer function
  def map(transform_func, *args, **kwargs):
    destination = []
    pipeline = _make_transform_step(
      _make_collect_input_step(
        _make_null_step(),
        destination
      ),
      transform_func
    )
    ret = this.iterate(pipeline, *args, **kwargs)
    return new_collection(destination)
  end
  # Pass each member of the collection to a function,
  # without keeping the results of the called function.
  def foreach(func, *args, **kwargs):
    pipeline = _make_transform_step(
      _make_null_step(),
      func
    )
    ret = this.iterate(pipeline, *args, **kwargs)
    return None
  end
  # Does every member have the given predicate?
  def all(filter_func, *args, **kwargs):
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
    ret = this.iterate(pre_filter_counter, *args, **kwargs)
    return post_filter_counter.count() == pre_filter_counter.count();
  end
  # Does any member have the given predicate?
  def any(filter_func, *args, **kwargs):
    post_filter_counter = _make_count_step(
      _make_null_step()
    )
    pipeline = _make_filter_step(
      post_filter_counter,
      filter_func,
      stop_on_success=True,
      stop_on_failure=False
    )
    ret = this.iterate(pipeline, *args, **kwargs)
    return post_filter_counter.count() != 0;
  end
  # Do no members have the given predicate?
  def allnot(filter_func, *args, **kwargs):
    return not this.any(filter_func, *args, **kwargs)
  end
  def select_by_attrs(**attrs):
    return this.select(_object_has_attrs, attrs)
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
  def tostr():
    return "Collection<" + repr(things) + ">"
  end
  this = struct.make(
    tostr=tostr, things=things, iterable=_iterable, first=first, select=select, map=map, foreach=foreach, all=all, any=any, allnot=allnot, select_by_attrs=select_by_attrs, iterate=_iterate
  )
  return this
end
# FIXME: Violates the DRY principle - thrice!
# Seems no way to import * in ytt
# TODO: Work around this by pre-processing this YAML code,
# appending all functions to each source file, to disuse load
transforms = struct.make(first=first, foreach=foreach, all=all, any=any, allnot=allnot, new_collection=new_collection)
