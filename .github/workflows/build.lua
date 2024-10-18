# .github/workflows/build.yml

name: Lua Project Build and Minify

# Trigger the workflow on pushes and pull requests affecting the lua/ directory
on:
  push:
    paths:
      - 'lua/**'
  pull_request:
    paths:
      - 'lua/**'

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      # Step 1: Checkout the repository
      - name: Checkout Repository
        uses: actions/checkout@v3

      # Step 2: Install Dependencies (Lua, LuaRocks)
      - name: Install Lua and LuaRocks
        run: |
          sudo apt-get update
          sudo apt-get install -y lua5.3 luarocks

      # Step 3: Install LuaFileSystem (required by build.lua)
      - name: Install LuaFileSystem
        run: |
          sudo luarocks install luafilesystem

      # Step 4: Install LuaMinify
      # Assuming LuaMinify is not available via LuaRocks, install it manually
      - name: Install LuaMinify
        run: |
          git clone https://github.com/ysc3839/lua-minify.git
          cd lua-minify
          make  # Assuming Makefile exists for LuaMinify
          sudo make install  # Installs LuaMinify to a standard location

      # Step 5: Verify Installation of LuaMinify
      - name: Verify LuaMinify Installation
        run: |
          which luamin
          luamin -h

      # Step 6: Run Makefile Targets
      - name: Run Makefile to Minify Lua Files
        run: |
          make minify

      # Step 7: (Optional) Upload Minified Lua Files as Artifacts
      - name: Upload Minified Lua Files
        uses: actions/upload-artifact@v3
        with:
          name: minified-lua
          path: |
            lua/**/*.lua

      # Step 8: (Optional) Create GitHub Release with Artifacts
      # - name: Create GitHub Release
      #   id: create_release
      #   uses: actions/create-release@v1
      #   env:
      #     GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      #   with:
      #     tag_name: v1.0.${{ github.run_number }}
      #     release_name: Release v1.0.${{ github.run_number }}
      #     draft: false
      #     prerelease: false

      # - name: Upload Release Asset
      #   uses: actions/upload-release-asset@v1
      #   env:
      #     GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      #   with:
      #     upload_url: ${{ steps.create_release.outputs.upload_url }}
      #     asset_path: ./lua
      #     asset_name: minified-lua.zip
      #     asset_content_type: application/zip
