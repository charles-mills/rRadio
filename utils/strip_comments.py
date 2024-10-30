import os
import re
from typing import List, Tuple
import shutil
from datetime import datetime

def get_lua_files(directory: str) -> List[str]:
    """
    Recursively find all Lua files in the given directory, ignoring stations directory.
    
    Args:
        directory (str): Root directory to search in
        
    Returns:
        List[str]: List of paths to Lua files
    """
    lua_files = []
    stations_path = os.path.join('radio', 'client', 'stations')
    
    for root, _, files in os.walk(directory):
        # Skip if this directory is the stations directory
        if stations_path in os.path.relpath(root, directory):
            continue
            
        for file in files:
            if file.endswith('.lua'):
                lua_files.append(os.path.join(root, file))
    return lua_files

def format_size(size_bytes: int) -> str:
    """
    Format size in bytes to human readable format.
    
    Args:
        size_bytes (int): Size in bytes
        
    Returns:
        str: Formatted size string
    """
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} TB"

def get_directory_size(directory: str) -> int:
    """
    Calculate total size of a directory.
    
    Args:
        directory (str): Directory path
        
    Returns:
        int: Total size in bytes
    """
    total_size = 0
    for dirpath, _, filenames in os.walk(directory):
        for filename in filenames:
            filepath = os.path.join(dirpath, filename)
            total_size += os.path.getsize(filepath)
    return total_size

def remove_comments_and_whitespace(content: str) -> str:
    """
    Remove comments and normalize whitespace in Lua code.
    
    Args:
        content (str): Original Lua code content
        
    Returns:
        str: Clean code content
    """
    # Remove multi-line comments
    content = re.sub(r'--\[\[.*?\]\]', '', content, flags=re.DOTALL)
    
    # Remove single-line comments (but not --[[ or --]])
    content = re.sub(r'--(?!\[|\])[^\n]*', '', content)
    
    # Split into lines and process each line
    lines = content.split('\n')
    clean_lines = []
    
    for line in lines:
        # Strip whitespace from both ends
        line = line.strip()
        
        # Skip empty lines
        if not line:
            continue
            
        # Normalize internal whitespace
        # Replace multiple spaces with single space, except in strings
        parts = re.split(r'(["\'].*?["\'])', line)
        for i in range(0, len(parts), 2):
            parts[i] = re.sub(r'\s+', ' ', parts[i])
        line = ''.join(parts)
        
        clean_lines.append(line)
    
    # Join lines with single newlines
    return '\n'.join(clean_lines)

def backup_directory(src_dir: str) -> str:
    """
    Create a backup of the source directory.
    
    Args:
        src_dir (str): Directory to backup
        
    Returns:
        str: Path to backup directory
    """
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_dir = f"{src_dir}_backup_{timestamp}"
    shutil.copytree(src_dir, backup_dir)
    return backup_dir

def process_files(lua_files: List[str], dry_run: bool = True) -> List[Tuple[str, int, int]]:
    """
    Process Lua files to remove comments and normalize whitespace.
    
    Args:
        lua_files (List[str]): List of Lua file paths
        dry_run (bool): If True, don't modify files
        
    Returns:
        List[Tuple[str, int, int]]: List of (file_path, original_size, new_size)
    """
    results = []
    
    for file_path in lua_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                original_content = f.read()
                original_size = len(original_content)
                
            new_content = remove_comments_and_whitespace(original_content)
            new_size = len(new_content)
            
            if not dry_run:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                    
            results.append((file_path, original_size, new_size))
            
        except Exception as e:
            print(f"Error processing {file_path}: {str(e)}")
            
    return results

def main():
    # Get the project root directory (two levels up from this script)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(os.path.dirname(script_dir))
    lua_dir = os.path.join(project_root, "rRadio", "lua")
    
    if not os.path.exists(lua_dir):
        print(f"Error: Lua directory not found at {lua_dir}")
        return
    
    # Get initial project size
    initial_project_size = get_directory_size(project_root)
    initial_lua_size = get_directory_size(lua_dir)
    
    print(f"\nInitial Project Size: {format_size(initial_project_size)}")
    print(f"Initial Lua Directory Size: {format_size(initial_lua_size)}")
    
    # Get all Lua files
    lua_files = get_lua_files(lua_dir)
    
    if not lua_files:
        print("No Lua files found!")
        return
    
    print(f"\nFound {len(lua_files)} Lua files")
    
    # First do a dry run
    print("\nPerforming dry run...")
    results = process_files(lua_files, dry_run=True)
    
    total_original = sum(orig for _, orig, _ in results)
    total_new = sum(new for _, _, new in results)
    total_saved = total_original - total_new
    
    print("\nDry run results:")
    print(f"Total files: {len(results)}")
    print(f"Total Lua size before: {format_size(total_original)}")
    print(f"Total Lua size after: {format_size(total_new)}")
    print(f"Total bytes saved: {format_size(total_saved)} ({(total_saved/total_original)*100:.1f}%)")
    
    print("\nFile-by-file preview:")
    for file_path, orig_size, new_size in results:
        rel_path = os.path.relpath(file_path, project_root)
        saved = orig_size - new_size
        saved_percent = (saved/orig_size)*100 if orig_size > 0 else 0
        print(f"{rel_path}: {format_size(saved)} saved ({saved_percent:.1f}%)")
    
    # Ask for confirmation
    response = input("\nDo you want to proceed with removing comments and whitespace? (y/N): ").lower()
    
    if response != 'y':
        print("Operation cancelled")
        return
    
    # Create backup
    print("\nCreating backup...")
    backup_dir = backup_directory(lua_dir)
    print(f"Backup created at: {backup_dir}")
    
    # Process files for real
    print("\nRemoving comments and whitespace...")
    results = process_files(lua_files, dry_run=False)
    
    # Get final sizes
    final_project_size = get_directory_size(project_root)
    final_lua_size = get_directory_size(lua_dir)
    
    print("\nOperation completed successfully!")
    print(f"Backup location: {backup_dir}")
    print("\nFinal Results:")
    print(f"Project Size Before: {format_size(initial_project_size)}")
    print(f"Project Size After: {format_size(final_project_size)}")
    print(f"Total Project Size Reduction: {format_size(initial_project_size - final_project_size)} ({((initial_project_size - final_project_size)/initial_project_size)*100:.1f}%)")
    print(f"\nLua Directory Size Before: {format_size(initial_lua_size)}")
    print(f"Lua Directory Size After: {format_size(final_lua_size)}")
    print(f"Total Lua Size Reduction: {format_size(initial_lua_size - final_lua_size)} ({((initial_lua_size - final_lua_size)/initial_lua_size)*100:.1f}%)")

if __name__ == "__main__":
    main() 