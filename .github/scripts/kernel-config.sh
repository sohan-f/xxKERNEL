#!/usr/bin/env bash

# Apply a kernel config line to a defconfig file idempotently.
# Handles: CONFIG_FOO=y, CONFIG_FOO=m, CONFIG_FOO="str", and # CONFIG_FOO is not set
apply_line() {
    local line="$1"
    local defconfig="$2"

    # Trim leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    if [[ ! -f "$defconfig" ]]; then
        echo "::error::apply_line: defconfig not found: $defconfig" >&2
        return 1
    fi

    # Skip blank lines and non-config comments
    [[ -z "$line" || ( "$line" == \#* && ! "$line" =~ is[[:space:]]+not[[:space:]]+set$ ) ]] && return 0

    local key value is_disable=0

    # Match `# CONFIG_FOO is not set`
    if [[ "$line" =~ ^#[[:space:]]*(CONFIG_[A-Za-z0-9_]+)[[:space:]]+is[[:space:]]+not[[:space:]]+set$ ]]; then
        key="${BASH_REMATCH[1]}"
        is_disable=1
    # Match `CONFIG_FOO=bar` or `CONFIG_FOO`
    elif [[ "$line" == *"="* ]]; then
        key="${line%%=*}"
        value="${line#*=}"
        [[ "$value" == "n" ]] && is_disable=1
    else
        key="$line"
        value="y"
    fi

    # Execute disable logic for both `# CONFIG_FOO is not set` and `CONFIG_FOO=n`
    if [[ $is_disable -eq 1 ]]; then
        if grep -qE "^# ${key} is not set$" "$defconfig"; then
            return 0
        elif grep -qE "^${key}=" "$defconfig"; then
            sed -i "s|^${key}=.*|# ${key} is not set|" "$defconfig"
        else
            echo "# ${key} is not set" >> "$defconfig"
        fi
        return 0
    fi

    # Escape special characters (\, &, and |) for safe sed replacement
    local escaped_val
    escaped_val=$(printf '%s\n' "$value" | sed -e 's/[\&|]/\\&/g')

    # Apply enable/update logic
    if grep -qE "^${key}=" "$defconfig"; then
        sed -i "s|^${key}=.*|${key}=${escaped_val}|" "$defconfig"
    elif grep -qE "^# ${key} is not set$" "$defconfig"; then
        sed -i "s|^# ${key} is not set$|${key}=${escaped_val}|" "$defconfig"
    else
        echo "${key}=${value}" >> "$defconfig"
    fi
}

export -f apply_line
