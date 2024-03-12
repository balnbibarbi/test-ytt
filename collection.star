load("@ytt:struct", "struct")
load("@ytt:yaml", "yaml")
load("dump.star", "dump")
load("object.star", "object")
load("step.star", "step")
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
  def first(filter_func=object._, *args, **kwargs):
    remember_last = step.remember_last.create(
      step.null.create()
    )
    pipeline = step.filter.create(
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
    pipeline = step.filter.create(
      step.collect_input.create(
        step.null.create(),
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
    pipeline = step.transform.create(
      step.collect_input.create(
        step.null.create(),
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
    pipeline = step.transform.create(
      step.null.create(),
      func
    )
    ret = this.iterate(pipeline, *args, **kwargs)
    return None
  end
  # Does every member have the given predicate?
  def all(filter_func, *args, **kwargs):
    post_filter_counter = step.count.create(
      step.null.create()
    )
    pre_filter_counter = step.count.create(
      step.filter.create(
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
    post_filter_counter = step.count.create(
      step.null.create()
    )
    pipeline = step.filter.create(
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
  this = object.create(
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
collection = struct.make(create=new_collection, has_entries=has_entries)
