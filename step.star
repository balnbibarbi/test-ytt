load("object.star", "object")
def _make_abstract_step(receive_func, tostr_func, **extra_params):
  this = None
  def step_tostr():
    return "Step<" + repr(receive_func) + ">"
  end
  this = object.create(receive_item=receive_func, tostr=tostr_func, **extra_params)
  return this
end
abstract_step = object.create(create=_make_abstract_step)
def _make_null_step():
  this = None
  def null_step_tostr():
    return "NullStep<>"
  end
  def _receive(thing, *args, **kwargs):
    return True
  end
  this = _make_abstract_step(_receive, null_step_tostr)
  return this
end
null_step = object.create(create=_make_null_step)
def _make_transform_step(next_step, transform_func, *transform_args, **transform_kwargs):
  this = None
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
  this = _make_abstract_step(_receive, transform_step_tostr, transform_args=transform_args, transform_kwargs=transform_kwargs)
  return this
end
transform_step = object.create(create=_make_transform_step)
def _make_count_step(next_step):
  this = None
  counter = [ 0 ]
  def count_step_tostr():
    return "CountStep<>"
  end
  def _receive(thing, *args, **kwargs):
    counter[0] += 1
    return next_step.receive_item(thing, *args, **kwargs)
  end
  def _get_count():
    return counter[0]
  end
  this = _make_abstract_step(_receive, count_step_tostr, count=_get_count)
  return this
end
count_step = object.create(create=_make_count_step)
def _make_filter_step(next_step, filter_func, stop_on_success=False, stop_on_failure=False):
  this = None
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
  this = _make_abstract_step(_receive, filter_step_tostr)
  return this
end
filter_step = object.create(create = _make_filter_step)
def _make_collect_input_step(next_step, collection):
  this = None
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
  this = _make_abstract_step(_receive, collect_input_step_tostr, collection=_get_collection)
  return this
end
collect_input_step = object.create(create=_make_collect_input_step)
def _make_remember_last_step(next_step):
  this = None
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
  this = _make_abstract_step(_receive, remember_last_step_tostr, last_seen=_get_last_seen)
  return this
end
remember_last_step = object.create(create=_make_remember_last_step)
step = object.create(null=null_step, transform=transform_step, count=count_step, filter=filter_step, collect_input=collect_input_step, remember_last=remember_last_step)
