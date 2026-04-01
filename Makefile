.PHONY: test format install-hooks

test:
	./scripts/test

format:
	stylua lua plugin tests

install-hooks:
	./scripts/install-hooks
