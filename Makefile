
# Variables
LUA_MINIFY=luamin
LUA_DIR=lua            # Directory containing Lua files
MIN_EXT=.min.lua       # Extension for minified files

# Default target
all: minify

# Minify Lua files
minify:
	@echo "Starting Lua minification..."
	@find $(LUA_DIR) -type f -name "*.lua" ! -name "*$(MIN_EXT)" | while read file; do \
		min_file="$$file$(MIN_EXT)"; \
		echo "Minifying $$file to $$min_file"; \
		$(LUA_MINIFY) "$$file" > "$$min_file"; \
	done
	@echo "Lua minification completed."

# Clean minified files
clean:
	@echo "Cleaning minified Lua files..."
	@find $(LUA_DIR) -type f -name "*$(MIN_EXT)" -delete
	@echo "Cleaned."

.PHONY: all minify clean
