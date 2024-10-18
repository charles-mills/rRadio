# Variables
LUA_MINIFY=luamin
LUA_DIR=lua

# Default target
all: minify

# Minify all Lua files in the lua/ directory
minify:
	@echo "Starting minification process..."
	@find $(LUA_DIR) -type f -name "*.lua" ! -name "*.min.lua" -exec $(LUA_MINIFY) "{}" \; -exec bash -c 'mv "$$0" "$${0%.lua}.min.lua"' {} \;
	@echo "Minification completed."

# Clean minified files
clean:
	@echo "Cleaning minified Lua files..."
	@find $(LUA_DIR) -type f -name "*.min.lua" -delete
	@echo "Cleaned."

.PHONY: all minify clean