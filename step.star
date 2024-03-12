load("object.star", "object")
def _make_step(receive_func, tostr_func, **extra_params):
  def step_tostr():
    return "Step<" + repr(receive_func) + ">"
  end
  return object.create(receive_item=receive_func, tostr=tostr_func, **extra_params)
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
step = object.create(create_null=_make_null_step, create_transform=_make_transform_step, create_count=_make_count_step, create_filter=_make_filter_step, create_collector=_make_collect_input_step, create_remember_last=_make_remember_last_step)
