import os
import re

ui_constants_path = 'lib/core/constants/ui_constants.dart'
lib_dir = 'lib'

# Read constants
constants = []
with open(ui_constants_path, 'r') as f:
    content = f.read()
    
# Match const String NAME = 'value'; or "value";
pattern = r"const\s+String\s+([A-Z0-9_]+)\s*=\s*(['\"])(.*?)\2;"
matches = re.finditer(pattern, content, flags=re.DOTALL)
for match in matches:
    name = match.group(1)
    val = match.group(3)
    constants.append((name, val))

# Special interpolated cases
special_cases = [
    (r"'\$tagName saved with \$\{keywordsToSave\.length\} keyword\$\{keywordsToSave\.length > 1 \? \"s\" : \"\"\}\.'", 
     r"SUCCESS_TAG_CREATED_DESC.replaceAll('{tagName}', tagName).replaceAll('{count}', keywordsToSave.length.toString()).replaceAll('{s}', keywordsToSave.length > 1 ? 's' : '')"),
    (r"'\$\{model\.tagName\} updated\.'", r"SUCCESS_TAG_UPDATED_DESC.replaceAll('{tagName}', model.tagName)"),
    (r"'Transactions tagged with \"\$tagName\"\\nwill appear here\.'", r"EMPTY_STATE_TAG_TRANSACTIONS.replaceAll('{tagName}', tagName)"),
    (r"'\$\{model\.bankName\} account added\.'", r"SUCCESS_ACCOUNT_ADDED_DESC.replaceAll('{bankName}', model.bankName)"),
    (r"'\$\{model\.bankName\} updated\.'", r"SUCCESS_ACCOUNT_UPDATED_DESC.replaceAll('{bankName}', model.bankName)")
]

def escape_regex(s):
    # Escape special regex chars
    return re.escape(s)

def process_file(filepath):
    if filepath == ui_constants_path:
        return
        
    with open(filepath, 'r') as f:
        original_content = f.read()
        
    new_content = original_content
    replaced = False
    
    # 1. Special cases
    for regex_pattern, replacement in special_cases:
        new_content, count = re.subn(regex_pattern, replacement, new_content)
        if count > 0:
            replaced = True
            
    # 2. Regular constants
    for name, val in constants:
        if '{' in val and name not in ['SNACKBAR_MESSAGE_SUCCESS', 'SNACKBAR_MESSAGE_WARNING', 'SNACKBAR_MESSAGE_ERROR', 'SNACKBAR_MESSAGE_INFO']:
            # Skip templates not handled by special cases (if any)
            continue
            
        # We want to match exactly 'val' or "val"
        # We need to escape the val for regex
        escaped_val = escape_regex(val)
        
        # Match 'val' or "val" 
        # Using negative lookbehind/lookahead to ensure it's not part of a larger string
        # Actually just matching the literal string with quotes
        pattern_single = r"'" + escaped_val + r"'"
        pattern_double = r'"' + escaped_val + r'"'
        
        new_content, count1 = re.subn(pattern_single, name, new_content)
        new_content, count2 = re.subn(pattern_double, name, new_content)
        
        if count1 > 0 or count2 > 0:
            replaced = True
            
    if replaced:
        # Add import if not present
        import_stmt = "import 'package:ledger_sync/core/constants/ui_constants.dart';"
        if import_stmt not in new_content:
            # Find the last import statement
            imports = list(re.finditer(r"^import\s+.*;$", new_content, flags=re.MULTILINE))
            if imports:
                last_import = imports[-1]
                insert_pos = last_import.end()
                new_content = new_content[:insert_pos] + "\n" + import_stmt + new_content[insert_pos:]
            else:
                new_content = import_stmt + "\n\n" + new_content
                
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
