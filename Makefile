LIBRARY=transforms.star
INPUT_MAP=input-map.yaml
INPUT_ARRAY=input-array.yaml
TRANSFORM_MAP=transform-map.yaml
TRANSFORM_ARRAY=transform-array.yaml

.PHONY: all
all: transform_map transform_array

.PHONY: transform_map
transform_map: $(INPUT_MAP) $(LIBRARY) $(TRANSFORM_MAP)
	ytt -f "$(INPUT_MAP)" -f $(LIBRARY) -f "$(TRANSFORM_MAP)"

.PHONY: transform_array
transform_array: $(INPUT_ARRAY) $(LIBRARY) $(TRANSFORM_ARRAY)
	ytt -f "$(INPUT_ARRAY)" -f $(LIBRARY) -f "$(TRANSFORM_ARRAY)"
