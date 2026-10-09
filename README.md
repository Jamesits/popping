# Popping

![Works - On My Machine](https://img.shields.io/badge/Works-On_My_Machine-2ea44f)
![100% Written by AI](https://img.shields.io/badge/Written_by_AI-100%25-blue)
![Project Status - Feature Complete](https://img.shields.io/badge/Project_Status-Feature_Complete-2ea44f)

Ashamed of not using SOTA models? No worries anymore!
Popping appends "Co-Authored-By" to the Git commit message automatically even if you are writing code with your own brain and hands.

## Usage

```shell
# Use a built-in model signature
./popping.sh claude-fable-5-1

# List built-in models
./popping.sh --list

# Use a custom signature
./popping.sh "name <email>"

# Other usage
./popping.sh --help

# Uninstall
./popping.sh --uninstall
```

Notes:

- Setup is per Git repository
- Windows users please use Git bash: `bash.exe ./popping.sh [...options]`

