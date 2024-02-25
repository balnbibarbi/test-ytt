LIBRARY=transforms.star
# Case 1: transform a map/dict/object
INPUT_MAP=input-map.yaml
TRANSFORM_MAP=transform-map.yaml
# Case 2: transform an array/list
INPUT_ARRAY=input-array.yaml
TRANSFORM_ARRAY=transform-array.yaml
# Case 3: select an array entry by attribute value
INPUT_SELECT=input-select.yaml
TRANSFORM_SELECT=transform-select.yaml

.PHONY: all
all: transform_map transform_array transform_select

.PHONY: transform_map
transform_map: $(INPUT_MAP) $(LIBRARY) $(TRANSFORM_MAP)
	ytt -f "$(INPUT_MAP)" -f $(LIBRARY) -f "$(TRANSFORM_MAP)"

.PHONY: transform_array
transform_array: $(INPUT_ARRAY) $(LIBRARY) $(TRANSFORM_ARRAY)
	ytt -f "$(INPUT_ARRAY)" -f $(LIBRARY) -f "$(TRANSFORM_ARRAY)"

.PHONY: transform_select
transform_select: $(INPUT_SELECT_ $(LIBRARY) $(TRANSFORM_SELECT)
	ytt -f "$(INPUT_SELECT)" -f $(LIBRARY) -f "$(TRANSFORM_SELECT)"
