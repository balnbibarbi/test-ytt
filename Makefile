INPUT=input.yaml
TRANSFORM=transform.yaml

.PHONY: all
all: transform

.PHONY: transform
transform: $(INPUT) $(TRANSFORM)
	ytt -f "$(INPUT)" -f "$(TRANSFORM)"
