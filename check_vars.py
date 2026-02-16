import re
import os
import glob

def get_defined_variables(variables_file):
    with open(variables_file, 'r') as f:
        content = f.read()
    # Regex to find variable "name" {
    matches = re.findall(r'variable\s+"([^"]+)"', content)
    return set(matches)

def get_used_variables(directory):
    used_vars = set()
    tf_files = glob.glob(os.path.join(directory, "*.tf"))
    for file_path in tf_files:
        with open(file_path, 'r') as f:
            content = f.read()
        # Regex to find var.name
        matches = re.findall(r'var\.([a-zA-Z0-9_-]+)', content)
        used_vars.update(matches)
    return used_vars

def get_variables_without_defaults(variables_file):
    with open(variables_file, 'r') as f:
        content = f.read()
    # Find variables that do NOT have a default value
    # rigorous parsing is hard with regex, but we can try to split by 'variable "'
    # and check if the block contains 'default'
    docs = content.split('variable "')
    no_default = []
    for doc in docs[1:]: # skip first empty chunk
        name = doc.split('"')[0]
        # find closing brace of variable block? tricky.
        # simpler: check if 'default' is present in the first few lines or before the next 'variable "'
        # This is a heuristic.
        body = doc.split('}')[0] # assuming no nested braces in default value... but maps can have them.
        # better: use hcl parser if available, but unlikely.
        # naive check: look for 'default =' or 'default='
        if 'default' not in doc:
             no_default.append(name)
    return set(no_default)

def main():
    directory = "infra/terraform"
    variables_file = os.path.join(directory, "variables.tf")
    
    if not os.path.exists(variables_file):
        print(f"Error: {variables_file} not found")
        return

    defined_vars = get_defined_variables(variables_file)
    used_vars = get_used_variables(directory)

    missing_vars = used_vars - defined_vars
    
    if missing_vars:
        print("Missing variables (used but not defined):")
        for var in sorted(missing_vars):
            print(f"- {var}")
    else:
        print("No missing variables (used but not defined) found.")

    unused_vars = defined_vars - used_vars
    if unused_vars:
        print("\nUnused variables (defined but not used):")
        for var in sorted(unused_vars):
            print(f"- {var}")
            
    no_default_vars = get_variables_without_defaults(variables_file)
    if no_default_vars:
        print("\nVariables without defaults:")
        for var in sorted(no_default_vars):
            print(f"- {var}")

if __name__ == "__main__":
    main()
