LIBRARY=transforms.star
# Case 1: transform a map/dict/object
# Case 2: transform an array/list
# Case 3: select an array entry by attribute value
TEST_CASES=$(wildcard tests/*)

.PHONY: all
all:
	@set -e ; \
	for case in $(TEST_CASES) ; do \
		ytt -f "$${case}/input.yaml" -f "$(LIBRARY)" -f "$${case}/transform.yaml" > "$${case}/actual-output.yaml" ; \
		if cmp "$${case}/actual-output.yaml" "$${case}/expected-output.yaml" ; then \
			echo "PASS: $${case}" 2>&1 ; \
		else \
			echo "FAIL: $${case}" 2>&1 ; \
			diff -Naurb "$${case}/expected-output.yaml" "$${case}/actual-output.yaml" 2>&1 ; \
		fi ; \
	done
