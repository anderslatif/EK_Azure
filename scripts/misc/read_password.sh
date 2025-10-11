#!/bin/bash

# Function to read password with asterisk feedback
# Usage: read_password "prompt text" variable_name
read_password() {
    local prompt="$1"
    local password=""
    local char

    printf "%s" "$prompt"

    # Disable terminal echoing
    stty -echo

    while IFS= read -r -n1 -s char; do
        # Break on Enter (empty char)
        if [[ -z "$char" ]]; then
            break
        fi

        # Handle backspace
        if [[ "$char" == $'\x7f' ]] || [[ "$char" == $'\x08' ]]; then
            if [ ${#password} -gt 0 ]; then
                password="${password%?}"
                printf '\b \b'
            fi
        else
            password+="$char"
            printf '*'
        fi
    done

    # Re-enable terminal echoing
    stty echo
    printf '\n'

    # Return password via the variable name passed as second argument
    eval "$2='$password'"
}
