ALL_DOCS := $(shell find . -name '*.md' -type f | sort)
MARKDOWN_LINT=markdownlint

.PHONY: markdown-lint
markdown-lint:
	@for f in $(ALL_DOCS); do echo $$f; $(MARKDOWN_LINT) -c .markdownlint.yaml $$f; done
