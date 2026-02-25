PORT ?= 8080

.PHONY: serve dev

serve:
	@echo "Serving at http://localhost:$(PORT) — press Ctrl+C to stop"
	@python3 -m http.server $(PORT)

dev:
	@echo "Serving at http://localhost:$(PORT) — press Ctrl+C to stop"
	@open http://localhost:$(PORT) &
	@python3 -m http.server $(PORT)
