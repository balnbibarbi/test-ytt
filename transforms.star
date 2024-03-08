load("@ytt:struct", "struct")
load("@ytt:yaml", "yaml")
load("dump.star", dump="dump")
def _make_step(receive_func, tostr_func, **extra_params):
  def step_tostr():
    return "Step<" + repr(receive_func) + ">"
  end
  return struct.make(receive_item=receive_func, tostr=tostr_func, **extra_params)
end
def _make_null_step():
  def null_step_tostr():
    return "NullStep<>"
  end
  def _receive(thing, *args, **kwargs):
    return True
  end
  return _make_step(_receive, null_step_tostr)
end
def _make_transform_step(next_step, transform_func, *transform_args, **transform_kwargs):
  def transform_step_tostr():
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
  return _make_step(_receive, transform_step_tostr, transform_args=transform_args, transform_kwargs=transform_kwargs)
end
def _make_count_step(next_step):
  def count_step_tostr():
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
  return _make_step(_receive, count_step_tostr, count=_get_count)
end
def _make_filter_step(next_step, filter_func, stop_on_success=False, stop_on_failure=False):
  def filter_step_tostr():
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
  return _make_step(_receive, filter_step_tostr)
end
def _make_collect_input_step(next_step, collection):
  def collect_input_step_tostr():
    return "CollectStep<" + repr(collection) + ">"
  end
  def _receive(thing, *args, **kwargs):
    if type(collection) == "list":
      collection.append(thing)
    else:
      (name, value) = thing
      collection[name] = value
    end
    return next_step.receive_item(thing, *args, **kwargs)
  end
  def _get_collection():
    return collection
  end
  return _make_step(_receive, collect_input_step_tostr, collection=_get_collection)
end
def _make_remember_last_step(next_step):
  def remember_last_step_tostr():
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
  return _make_step(_receive, remember_last_step_tostr, last_seen=_get_last_seen)
end
# Collection class
def new_collection(things):
  this = None
  def _iterable():
    if type(this.things) == "yamlfragment":
      iterable = dump.to_primitive(this.things)
    else:
      iterable = this.things
    end
    if type(iterable) == "list":
      iterable = iterable
    elif type(iterable) == "dict":
      iterable = iterable.items()
    elif type(iterable) == "struct":
      iterable = iterable
    else:
      iterable = iterable
    end
    return iterable
  end
  # First member of collection that has given predicate, or None
  def first(filter_func=dump._, *args, **kwargs):
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
    if type(this._iterable()) == "list":
      subset = []
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
    return new_collection(subset)
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
  def _iterate(step, *args, **kwargs):
    # FIXME: Need a distinction between stopping a pipeline run for an object,
    # and stopping further pipeline runs for successive objects.
    keep_iterating = True
    for thing in this._iterable():
      if not keep_iterating:
        break
      end
      keep_iterating = step.receive_item(thing, *args, **kwargs)
    end
  end
  def collection_tostr():
    if this:
      return "Collection<" + repr(this._iterable()) + ">"
    else:
      return "Collection<Empty>"
    end
  end
  def _get_items():
    return this.things
  end
  if type(things) == "yamlfragment":
    things = dump.to_primitive(things)
  end
  this = struct.make(
    things=things, tostr=collection_tostr, first=first, select=select, map=map, foreach=foreach, all=all, any=any, allnot=allnot, _iterable=_iterable, iterate=_iterate, items=_get_items
  )
  return this
end
# Test whether the given dict has all of the given
# entries, with the given values.
def has_entries(the_dict, **entries):
  def _entry_ison_dict(entry, the_dict):
    (entry_name, entry_value) = entry
    if entry_name not in the_dict:
      return False
    elif the_dict[entry_name] != entry_value:
      return False
    end
    return True
  end
  collection = new_collection(entries)
  return collection.all(_entry_ison_dict, the_dict)
end
# FIXME: Violates the DRY principle - thrice!
# Seems no way to import * in ytt
# TODO: Work around this by pre-processing this YAML code,
# appending all functions to each source file, to disuse load
transforms = struct.make(new_collection=new_collection, has_entries=has_entries)
