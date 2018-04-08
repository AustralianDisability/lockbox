#!/bin/bash

# setup Bash environment
set -euf -o pipefail


###############################################################################
# constants
###############################################################################

# version of this script
VERSION=1.1.0


###############################################################################
# functions
###############################################################################

# Prints script usage to stderr
# Arguments:
#   None
# Returns:
#   None
print_usage() {
    cat <<EOF >&2
Maintain an encrypted lockbox of data, accessible only by you.
Performs fast file-by-file encryption on every file in a directory recursively.

This script should be capable of running in macOS or in Linux.

Usage:  $0 (-e lockbox_dir|-d (manifest_file|lockbox_dir)) key
        $0 -v
        $0 -h
    -e lockbox_dir
        Encrypt mode.  Encrypts all files in lockbox_dir, recursively.
        Manifest file is written to stdout.
    -d manifest_file
        Decrypt mode.  Decrypts all files listed in manifest_file.
        This is the preferred decryption method.
    -d lockbox_dir
        Expert use only.  Decrypts all files in lockbox_dir, recursively, even
        if they were not originally encrypted.  If new plaintext files were
        added to lockbox_dir since it was encrypted, then this operation will
        corrupt them.  Please use '-d manifest_file' whenever possible.
    -h
        Display help information and exit.
    -v
        Display version information and exit.
    key
        Key to be used for encryption/decryption.
        Must be represented as a string comprised of exactly 64 hex characters,
        corresponding to a 256-bit (or 32-byte) key.
        Most easily generated by included gen_key.sh.

Example 1:
  Encrypt:
    $0 -e /tmp/lockbox aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | tee manifest.txt
  Decrypt:
    $0 -d manifest.txt aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

Example 2:
  Encrypt:
    $0 -e /tmp/lockbox \$(xxd -p test.key | tr -d '\n') | tee manifest.txt
  Decrypt:
    $0 -d manifest.txt \$(xxd -p test.key | tr -d '\n')
EOF
}


# Calculates IV for given file path
# Arguments:
#   Absolute file path
# Returns:
#   128-bit IV, represented in hex
function get_iv_hex {
    set -euf -o pipefail

    FILE_PATH=$1

    # MD5 is safe here because it's not being used for cryptographic reasons.
    # we just need something 128 bits wide that is likely to be different for
    # each input file path.
    FILE_PATH_HASH_HEX=$(echo -n "$FILE_PATH" | md5sum | cut -d ' ' -f 1)

    # ECB is safe here because we're implementing an ESSIV (of sorts),
    # and we need access to a raw, single-block encryption.  instead of
    # encrypting the sector number, we encrypt a hash of the full file path.
    openssl enc -aes-256-ecb -in <(echo "$FILE_PATH_HASH_HEX" | xxd -r -p) -e -K "$KEY_HASH_HEX" -nopad | xxd -p | tr -d '\n'
}
# export function for use by child processes
export -f get_iv_hex


# Encrypts or decrypts a file
# Arguments:
#   Absolute file path
# Returns:
#   None
function crypt {
    set -euf -o pipefail

    FILE_PATH=$1

    if [[ "$OPERATION_SWITCH" == '-e' ]]; then
        # calculate the hsah for the file, before we encrypt it
        HASH_OUTPUT=$(sha512sum "$FILE_PATH")
    fi

    # CTR mode ensures that *crypted file remains same size as original.
    # 8192 is chosen to match OpenSSL enc "bsize" buffer size.
    openssl enc -aes-256-ctr -in "$FILE_PATH" "$OPERATION_SWITCH" -K "$KEY_HEX" -iv "$(get_iv_hex "$FILE_PATH")" | dd of="$FILE_PATH" bs=8192 conv=notrunc status=none

    # assuming *cryption succeeded...
    if [[ "$OPERATION_SWITCH" == '-e' ]]; then
        # echo the hash output to stdout, enabling creation of manifest file
        echo "$HASH_OUTPUT"
    else
        # echo the file path to stdout, so the user can view decryption progress
        echo "$FILE_PATH"
    fi
}
# export function for use by child processes
export -f crypt


###############################################################################
# set default options
###############################################################################

OPERATION=""
OPERATION_SWITCH=""
ROOT_DIR=""
MANIFEST_PATH=""

# reset in case getopts has been used previously in the shell
OPTIND=1


###############################################################################
# parse options
###############################################################################

while getopts ":e:d:vh" opt; do
    case $opt in
        e)
            OPERATION="Encrypt"
            OPERATION_SWITCH='-e'

            if [[ -d "$OPTARG" ]]; then
                ROOT_DIR="$OPTARG"
            else
                echo "[-] $OPTARG is an invalid directory" >&2
                exit 1
            fi
            ;;
        d)
            OPERATION="Decrypt"
            OPERATION_SWITCH='-d'

            # test for directory first
            if [[ -d "$OPTARG" ]]; then
                ROOT_DIR="$OPTARG"
            elif [[ -r "$OPTARG" ]]; then
                MANIFEST_PATH="$OPTARG"
            else
                echo "[-] $OPTARG is an invalid file or directory" >&2
                exit 1
            fi
            ;;
        v)
            echo "lockbox $VERSION"
            echo "https://github.com/JElchison/lockbox"
            echo "Copyright (C) 2018 Jonathan Elchison <JElchison@gmail.com>"
            exit 0
            ;;
        h)
            print_usage
            exit 0
            ;;
        \?)
            echo "[-] Invalid option '-$OPTARG'" >&2
            print_usage
            exit 1
            ;;
        :)
            echo "[-] Option '-$OPTARG' requires an argument" >&2
            print_usage
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))
([[ "$1" = "--" ]] 2>/dev/null && shift) || true

# export variable for use by child processes
export OPERATION_SWITCH


###############################################################################
# validate arguments
###############################################################################

echo "[+] Validating arguments..." >&2

if [[ -z "$OPERATION" ]]; then
    echo "[-] Either option '-e' or '-d' is required" >&2
    print_usage
    exit 1
fi

# require exactly 1 argument
if [[ $# -ne 1 ]]; then
    echo "[-] key is a required argument" >&2
    print_usage
    exit 1
fi

# setup variables for arguments
KEY_HEX=$1

# verify that key is valid
echo -n "$KEY_HEX" | grep -Eq '[a-fA-F0-9]{64}' || (echo "[-] Provided key is invalid or incorrectly formatted" >&2; false)
echo -n "$KEY_HEX" | grep -Eq '[a]{64}' && (echo "[-] Provided key is only valid as example.  Please use gen_key.sh." >&2; false)

# export variable for use by child processes
export KEY_HEX


###############################################################################
# test dependencies
###############################################################################

echo "[+] Testing dependencies..." >&2
if [[ ! -x $(which openssl 2>/dev/null) ]] ||
    [[ ! -x $(which md5sum 2>/dev/null) ]] ||
    [[ ! -x $(which sha256sum 2>/dev/null) ]] ||
    [[ ! -x $(which sha512sum 2>/dev/null) ]] ||
    [[ ! -x $(which cat 2>/dev/null) ]] ||
    [[ ! -x $(which cut 2>/dev/null) ]] ||
    [[ ! -x $(which realpath 2>/dev/null) ]] ||
    [[ ! -x $(which find 2>/dev/null) ]] ||
    [[ ! -x $(which grep 2>/dev/null) ]] ||
    [[ ! -x $(which test 2>/dev/null) ]] ||
    [[ ! -x $(which true 2>/dev/null) ]] ||
    [[ ! -x $(which false 2>/dev/null) ]] ||
    [[ ! -x $(which tr 2>/dev/null) ]] ||
    [[ ! -x $(which dd 2>/dev/null) ]] ||
    [[ ! -x $(which xxd 2>/dev/null) ]]; then
    echo "[-] Dependencies unmet.  Please verify that the following are installed, executable, and in the PATH:  openssl, md5sum, sha256sum, sha512sum, cat, cut, realpath, find, grep, test, true, false, tr, dd, xxd" >&2
    exit 1
fi


###############################################################################
# start operation
###############################################################################

# calculate SHA-256 of key, for ESSIV-like purposes.  see get_iv_hex() above.
KEY_HASH_HEX=$(echo "$KEY_HEX" | xxd -r -p | sha256sum | cut -d ' ' -f 1)
# export variable for use by child processes
export KEY_HASH_HEX

echo "[+] ${OPERATION}ing following files..." >&2
if [[ "$OPERATION_SWITCH" == '-d' ]] && [[ -r "$MANIFEST_PATH" ]]; then
    while IFS='' read -r LINE || [[ -n "$LINE" ]]; do
        FILE=$(echo -n "$LINE" | sed -r 's/^[0-9a-f]{128} .(.+)$/\1/g')
        crypt "$FILE"
    done < "$MANIFEST_PATH"

    echo "[+] Verifying decryption..." >&2
    sha512sum -c "$MANIFEST_PATH" --quiet
else
    find $(realpath "$ROOT_DIR") -type f -writable -exec bash -c 'crypt "$0"' {} \;
fi


###############################################################################
# report status
###############################################################################

echo "[+] Success" >&2
