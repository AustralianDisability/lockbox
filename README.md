# lockbox

Maintain an encrypted lockbox of data, accessible only by you.  Performs fast file-by-file encryption on every file in a directory recursively.  This script should be capable of running in macOS or in Linux.

[![Build Status](https://travis-ci.org/JElchison/lockbox.svg?branch=master)](https://travis-ci.org/JElchison/lockbox)


## Features
* Performs fast file-by-file encryption on every file in a directory recursively
* Should be capable of running in macOS or in Linux
* Bash-based with minimal external dependencies (mainly OpenSSL's `enc` utility and `xxd`)
* Uses [NSA Suite B Cryptography](https://en.wikipedia.org/wiki/NSA_Suite_B_Cryptography) algorithms with generally good cryptographic hygiene
* Skips all files that are not [regular files](https://en.wikipedia.org/wiki/Unix_file_types#Regular_file) (such as symbolic links)
* Skips all files that are not writable by current user (a la `find -writable`), to avoid accidentally encrypting OS files
* Encrypted (ciphertext) files consume exactly same space as original (plaintext) files.  No additional key/IV material needs to be stored on lockbox device.  Helpful when trying to maintain lockbox on storage device with little free space.
    * Same symmetrical key used for all files.  Avoids having to store individual keys on lockbox device.
    * IV dynamically calculated for each file.  Like an [ESSIV](https://en.wikipedia.org/wiki/Disk_encryption_theory#Encrypted_salt-sector_initialization_vector_(ESSIV)), but uses hash of full file path instead of sector number.
* In-place encryption/decryption.  Instead of using a temp file on storage device for every encryption operation, an attempt is made to reuse existing [inode](https://en.wikipedia.org/wiki/Inode).  Helpful when trying to maintain lockbox on storage device with little free space.
    * Note:  The implication here is that you must be careful about version history and backups.  For example, it does no good to store your lockbox on Dropbox, since Dropbox will (forevermore) have plaintext versions of your encrypted files in its version history.
* Encrypted files leave little hint (if any) about what encrypted it
* (Recommended) use of manifest file verifies that all encrypted files (no more, no less) have been correctly decrypted to original state
* Local script can be run against remote lockbox, without local script ever existing on remote lockbox device
    * Still requires that remote lockbox device has OpenSSL's `enc` utility and `xxd` dependencies installed

Note:  This tool does not encrypt, rename, or otherwise attempt to mask the original (plaintext) filenames.  Thus, even when file contents are encrypted in the lockbox, it's still possible to see the original filenames.


## Environment
* Any OS having a Bash environment
* The following tools must be installed, executable, and in the PATH:
    * OpenSSL's `enc` utility
    * `xxd`

OpenSSL's `enc` must have the following ciphers available:
* `aes-256-ctr`
* `aes-256-ecb`


## Prerequisites
To install necessary prerequisites on Ubuntu:

    sudo apt install coreutils openssl vim-common

LibreSSL is also acceptable.

To install necessary prerequisites on macOS:

    brew install coreutils findutils gnu-sed openssl

Since lockbox assumes use of GNU versions of tools, you may have to modify your `PATH` such that GNU versions take precedence over native macOS versions.


## Getting Started

To encrypt:

1. Use `gen_key.sh` to generate a new key.  Always generate a new key for each encryption.
2. Invoke `lockbox.sh` to recursively encrypt the directory you deem as your lockbox.
3. Save your generated key in a safe/secure place.

To decrypt:

1. Invoke `lockbox.sh` (with the key you previously saved) to decrypt your lockbox.


## Usage
```
Maintain an encrypted lockbox of data, accessible only by you.
Performs fast file-by-file encryption on every file in a directory recursively.

This script should be capable of running in macOS or in Linux.

Usage:  ./lockbox.sh (-e lockbox_dir|-d (manifest_file|lockbox_dir)) key
        ./lockbox.sh -v
        ./lockbox.sh -h
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
    ./lockbox.sh -e /tmp/lockbox aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | tee manifest.txt
  Decrypt:
    ./lockbox.sh -d manifest.txt aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

Example 2:
  Encrypt:
    ./lockbox.sh -e /tmp/lockbox $(xxd -p test.key | tr -d '\n') | tee manifest.txt
  Decrypt:
    ./lockbox.sh -d manifest.txt $(xxd -p test.key | tr -d '\n')
```


### Example usage
Running on a locally stored lockbox directory:
```
$ ls -li /tmp/lockbox
total 40
9830451 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 1
9830562 -rw-rw-r-- 1 user     user     8 Apr  7 07:05 10
9830453 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 2
9830456 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 3
9830523 -rw-rw-r-- 1 root     root     7 Apr  7 07:05 4
9830535 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 5
9830552 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 6
9830553 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 7
9830560 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 8
9830561 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 9

$ xxd -g4 /tmp/lockbox/1
00000000: 54657374 20310a                      Test 1.

$ ./gen_key.sh test.key
[+] Validating arguments...
[+] Key saved at test.key
[+] Success

$ ./lockbox.sh -e /tmp/lockbox $(xxd -p test.key | tr -d '\n') | tee manifest.txt
[+] Validating arguments...
[+] Testing dependencies...
[+] Encrypting following files...
2cecfe6cd97a96ffa76c9e77b9e12eb057935bb71a0d62b08c2faf546949ddb71dc7af2483484ede72a544d511b7fc7c1d0c97649406fe1c63c1fb05155026dc  /tmp/lockbox/3
0670f66bebf4c6c6cbaf09f04cb7fe110dae6b638a156617e3c8440661572020e105d236d08afab6b0566b538fcb458efbb833a50f49711d187ef7c5ec03a367  /tmp/lockbox/2
edc9ee8d9db920514a43ecdfda0ee1f927f5383a8865aef1660b94e1f2ee0ac906a7934a25fc694da07838ec4e3a9b645a1af36bd0a5283c5bebf87de3e566c9  /tmp/lockbox/8
b369685ea1aba96a128fac154bb45caa265682042b5d3299bb39a542af54e3817e61a597c25c90cde8e66d311699d44d6ebbeb1601633e5bdba68efb7281a920  /tmp/lockbox/5
990f2b36730ac2941acb6642a818501205a94aa4c1dd511436ed696f914a92b12e962f7e78bdbdd8d5b8f39fe3f9fe580d8bb1885e06006279811a41a224e655  /tmp/lockbox/6
db7cf7d86a5fb5370585db489ec2affda2eb0eba79b7c20595759dd0d3489513b918fa2ec0bda35cbe6ddfb2fb8d3e3b2f77b8a39f2e0dd77fd5db0e10f931b5  /tmp/lockbox/1
1b76275c062fc0382a2eaf0e0f45078051c92551cff0a171bf5f93384ae9faa9b76388c4cbba52710b24f8c77853b04e3757835bade3ac2bc30ea8578b8120e7  /tmp/lockbox/10
dcaf7c17a80cd9c11ef995e1a1b5aa2d075d645495732e6dc13a868e2951b0f5cc097baf5c29d729ac421dc4a9b2c8a2243e3f2f5f60f590da5d8bc7dc4ae308  /tmp/lockbox/7
424d2adefb09cff4266a6fbefda7fc0dff1ae4e06d5e5d4bcb6351af55fcfd815a33706ce2a4a07ec829ae13fb60603c8c16e9fce4ae0a20fbaf07747bb8a6bb  /tmp/lockbox/9
[+] Success

$ ls -li /tmp/lockbox
total 40
9830451 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 1
9830562 -rw-rw-r-- 1 user     user     8 Apr  7 07:05 10
9830453 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 2
9830456 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 3
9830523 -rw-rw-r-- 1 root     root     7 Apr  7 07:05 4
9830535 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 5
9830552 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 6
9830553 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 7
9830560 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 8
9830561 -rw-rw-r-- 1 user     user     7 Apr  7 07:05 9

$ xxd -g4 /tmp/lockbox/1
00000000: 50c14f5c 894bcb                      P.O\.K.

$ ./lockbox.sh -d manifest.txt $(xxd -p test.key | tr -d '\n')
[+] Validating arguments...
[+] Testing dependencies...
[+] Decrypting following files...
/tmp/lockbox/3
/tmp/lockbox/2
/tmp/lockbox/8
/tmp/lockbox/5
/tmp/lockbox/6
/tmp/lockbox/1
/tmp/lockbox/10
/tmp/lockbox/7
/tmp/lockbox/9
[+] Verifying decryption...
[+] Success

$ ls -li /tmp/lockbox
total 40
9830451 -rw-rw-r-- 1 user     user     7 Apr  7 07:06 1
9830562 -rw-rw-r-- 1 user     user     8 Apr  7 07:06 10
9830453 -rw-rw-r-- 1 user     user     7 Apr  7 07:06 2
9830456 -rw-rw-r-- 1 user     user     7 Apr  7 07:06 3
9830523 -rw-rw-r-- 1 root     root     7 Apr  7 07:05 4
9830535 -rw-rw-r-- 1 user     user     7 Apr  7 07:06 5
9830552 -rw-rw-r-- 1 user     user     7 Apr  7 07:06 6
9830553 -rw-rw-r-- 1 user     user     7 Apr  7 07:06 7
9830560 -rw-rw-r-- 1 user     user     7 Apr  7 07:06 8
9830561 -rw-rw-r-- 1 user     user     7 Apr  7 07:06 9

$ xxd -g4 /tmp/lockbox/1
00000000: 54657374 20310a                      Test 1.
```

Running on a remotely stored lockbox directory, leaving lockbox.sh local:
```
$ ./gen_key.sh test.key
[+] Validating arguments...
[+] Key saved at test.key
[+] Success

$ ssh user@remote-addr "bash -s" -- < ./lockbox.sh -e /tmp/remote-lockbox $(xxd -p test.key | tr -d '\n') | tee manifest.txt
[+] Validating arguments...
[+] Testing dependencies...
[+] Encrypting following files...
2cecfe6cd97a96ffa76c9e77b9e12eb057935bb71a0d62b08c2faf546949ddb71dc7af2483484ede72a544d511b7fc7c1d0c97649406fe1c63c1fb05155026dc  /tmp/remote-lockbox/3
0670f66bebf4c6c6cbaf09f04cb7fe110dae6b638a156617e3c8440661572020e105d236d08afab6b0566b538fcb458efbb833a50f49711d187ef7c5ec03a367  /tmp/remote-lockbox/2
edc9ee8d9db920514a43ecdfda0ee1f927f5383a8865aef1660b94e1f2ee0ac906a7934a25fc694da07838ec4e3a9b645a1af36bd0a5283c5bebf87de3e566c9  /tmp/remote-lockbox/8
b369685ea1aba96a128fac154bb45caa265682042b5d3299bb39a542af54e3817e61a597c25c90cde8e66d311699d44d6ebbeb1601633e5bdba68efb7281a920  /tmp/remote-lockbox/5
990f2b36730ac2941acb6642a818501205a94aa4c1dd511436ed696f914a92b12e962f7e78bdbdd8d5b8f39fe3f9fe580d8bb1885e06006279811a41a224e655  /tmp/remote-lockbox/6
db7cf7d86a5fb5370585db489ec2affda2eb0eba79b7c20595759dd0d3489513b918fa2ec0bda35cbe6ddfb2fb8d3e3b2f77b8a39f2e0dd77fd5db0e10f931b5  /tmp/remote-lockbox/1
1b76275c062fc0382a2eaf0e0f45078051c92551cff0a171bf5f93384ae9faa9b76388c4cbba52710b24f8c77853b04e3757835bade3ac2bc30ea8578b8120e7  /tmp/remote-lockbox/10
dcaf7c17a80cd9c11ef995e1a1b5aa2d075d645495732e6dc13a868e2951b0f5cc097baf5c29d729ac421dc4a9b2c8a2243e3f2f5f60f590da5d8bc7dc4ae308  /tmp/remote-lockbox/7
424d2adefb09cff4266a6fbefda7fc0dff1ae4e06d5e5d4bcb6351af55fcfd815a33706ce2a4a07ec829ae13fb60603c8c16e9fce4ae0a20fbaf07747bb8a6bb  /tmp/remote-lockbox/9
[+] Success

$ scp manifest.txt user@remote-addr:/tmp/
manifest.txt                                                                                                         100% 1529     1.5KB/s   00:00

$ ssh user@remote-addr "bash -s" -- < ./lockbox.sh -d /tmp/manifest.txt $(xxd -p test.key | tr -d '\n')
[+] Validating arguments...
[+] Testing dependencies...
[+] Decrypting following files...
/tmp/remote-lockbox/3
/tmp/remote-lockbox/2
/tmp/remote-lockbox/8
/tmp/remote-lockbox/5
/tmp/remote-lockbox/6
/tmp/remote-lockbox/1
/tmp/remote-lockbox/10
/tmp/remote-lockbox/7
/tmp/remote-lockbox/9
[+] Verifying decryption...
[+] Success
```


## Disclaimer

Please use this tool responsibly.  If you interrupt its operation, mess up parameters, lose your key files, etc., your data may be lost--either temporarily or permanently.  Please test, rehearse, and automate your common operations, to reduce the likelihood of failure.  Consider using secure backups to make sure you don't lose anything truly critical.

No privacy tool is perfect.  This tool has been helpful for me.  If used properly, I hope it's helpful for you.  Unfortunately, I cannot provide any guarantees as to the completeness or soundness of this product with your machines, in your environment.  Please review my code before you trust this.  (PRs are welcome.)  Use at your own risk.
