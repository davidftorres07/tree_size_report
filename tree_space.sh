#!/bin/bash
# Check if a path is provided as a command-line argument
if [ "$#" -eq 0 ]; then
    echo "Error: Please provide a directory path as a command-line argument."
    exit 1
fi

# Get the current path from the command-line argument
current_path="$1"

# Display the current date
date

# Display disk space information using the df command for the specified path
df -h "$current_path" 2>/dev/null;echo

# Initialize the list to store directories and sizes
declare -a directory_list

get_numeric_size() {
    echo "$1" | awk '{gsub(/[^0-9.]/,""); print}'
}

# Global array to track the count at each recursion level
declare -a recursion_counts

print_tree() {
    local size="$1"
    local path="$2"
    local indent="$3"
    local recursion_level="$4"

    # Extract numeric part of size
    numeric_size=$(get_numeric_size "$size")

    print_full_path="0"
    # Determine color based on suffix
    case "${size,,}" in
        *t)
            color="\e[95m"  # Red for TeraBytes
            print_full_path="1"
            full_path_color="\e[103m" ;;  # Magenta for full path when TeraBytes option is selected
        *g)
            color="\e[91m"  # Red for GigaBytes
            print_full_path="1"
            full_path_color="\e[103m" ;;  # Red for full path when GigaBytes option is selected
        *m) color="\e[93m" ;;  # Yellow for MegaBytes
        *k) color="\e[92m" ;;  # Green for KiloBytes
        *)  color="\e[94m" ;;  # Blue for other sizes
    esac

    # Reset color after printing
    reset_color="\e[0m"

    # Extract only the folder name from the path
    folder_name=$(basename "$path")
    parent_path=$(dirname "$path")

    # Check if there's only a single folder element in the current directory 
    local folder_count=$(ls -1d "$parent_path"/*/ "$parent_path"/.*/ 2>/dev/null | wc -l)

    local tree_connector=""

    ((recursion_counts[$recursion_level]++))

    if [ "$folder_count" -eq 1 ] || [ "$folder_count" -eq "${recursion_counts[$recursion_level]}" ]; then
        tree_connector="└─"
    else
        tree_connector="├─"
    fi
    
    # Print the tree structure with colored size, depth indicators, and "|" for indentation and print the full path only when GigaBytes option is selected
    if [ $print_full_path -eq "1" ]; then
        echo -e "${indent}${indent:+$tree_connector}│${color}${size}${reset_color} ${folder_name} - ${full_path_color}${path}${reset_color}"
        # Add directory, size, and parent folder to the list
        directory_list+=("$path,$numeric_size,$parent_path")
    else
        # echo -e "${indent}${indent:+$tree_connector}│${color}${size}${reset_color} ${folder_name} - \e[93mPF:$folder_count${reset_color},\e[94mRL:$recursion_level${reset_color},\e[90mC:${recursion_counts[$recursion_level]}${reset_color}"
        echo -e "${indent}${indent:+$tree_connector}│${color}${size}${reset_color} ${folder_name}"
    fi

    local last_rl=$recursion_level
    ((recursion_level++))

    for item in $(ls -1d "$path"/* "$path"/.* 2>/dev/null | grep -v -e '/\.$' -e '/\.\.$'); do
        if [ -d "$item" ]; then            
            print_tree "$(du -sh "$item" 2>/dev/null | cut -f1)" "$item" "${indent}│    " "$recursion_level"
        fi
    done

    if [ "$folder_count" -eq 1 ] || [ "$folder_count" -eq "${recursion_counts[$last_rl]}" ]; then
         recursion_counts[$last_rl]=0
        #  echo "Count set to ${recursion_counts[$last_rl]} on RL:$last_rl"
    fi
}

# Set the initial count for the first recursion level
recursion_counts[0]=0

# Get the size of the current path
total_size=$(du -sh "$current_path" 2>/dev/null | cut -f1)

# Check if directory exists
if [ -z "$total_size" ]; then
    echo "Error: The specified directory does not exist or cannot be accessed."
    exit 1
fi

# Print the tree structure with colored size
print_tree "$total_size" "$current_path" "" "0"

# Print the list sorted by size and parent folder
if [ ${#directory_list[@]} -gt 0 ]; then
    echo -e "\n\n\e[93m:::Directories sorted by size and parent folder:::\e[0m"
    for entry in $(IFS=$'\n'; echo "${directory_list[*]}" | sort -t',' -k2,2nr -k3,3); do
        path=$(echo "$entry" | cut -d',' -f1)
        size=$(echo "$entry" | cut -d',' -f2)
        size_suffix=""

        # Determine size suffix (GB or TB)
        if (( $(echo "$size > 1024" | bc -l) )); then
            size=$(echo "scale=2; $size / 1024" | bc)
            size_suffix="TB"
        else
            size_suffix="GB"
        fi

        # Print entry with size in red color
        echo -e "\e[90m${size} ${size_suffix}\e[0m - ${path}"
    done
fi