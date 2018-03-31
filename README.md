# lockbox

Maintain a private lockbox of data, accessible only by you

[![Build Status](https://travis-ci.org/JElchison/lockbox.svg?branch=master)](https://travis-ci.org/JElchison/lockbox)


## Features
* Performs fast file-by-file encryption on every file in a directory recursively
* Uses [NSA Suite B Cryptography](https://en.wikipedia.org/wiki/NSA_Suite_B_Cryptography) algorithms with generally good cryptographic hygiene
* Skips all files that are not [regular files](https://en.wikipedia.org/wiki/Unix_file_types#Regular_file) (such as symbolic links)
* Skips all files that are not writable by current user (a la `find -writable`), to avoid accidentally encrypting OS files
* Encrypted (ciphertext) files consume exactly same space as original (plaintext) files.  No additional key/IV material needs to be stored on lockbox device.  Helpful when trying to maintain lockbox on storage device with little free space.
    * Same symmetrical key used for all files.  Avoids having to store individual keys on lockbox device.
    * IV dynamically calculated for each file.  Like an [ESSIV](https://en.wikipedia.org/wiki/Disk_encryption_theory#Encrypted_salt-sector_initialization_vector_(ESSIV)), but uses hash of full file path instead of sector number.
* In-place encryption/decryption.  Instead of using a temp file on storage device for every encryption operation, an attempt is made to reuse existing [inode](https://en.wikipedia.org/wiki/Inode).  Helpful when trying to maintain lockbox on storage device with little free space.


## Environment
* Any OS having a Bash environment
* The following tools must be installed, executable, and in the PATH:
    * `openssl`
    * `xxd`


## Prerequisites
To install necessary prerequisites on Ubuntu:

    sudo apt-get install coreutils vim-common


## Usage
```
Maintain a private lockbox of data, accessible only by you.
Performs fast file-by-file encryption on every file in a directory recursively.
This script should be capable of running in macOS or in Linux.
Usage:  ./lockbox.sh [-e] [-d] path key
        ./lockbox.sh -v
        ./lockbox.sh -h
    -e
        Encrypt mode (default).
    -d
        Decrypt mode.
    -h
        Display help information and exit.
    -v
        Display version information and exit.
    path
        Path to lockbox directory.
    key
        Key to be used for encryption/decryption.
        Must be represented as a string comprised of exactly 64 hex characters,
        corresponding to a 256-bit (or 32-byte) key.
Example:  ./lockbox.sh /tmp/lockbox aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
Example:  ./lockbox.sh /tmp/lockbox $(xxd -p test.key | tr -d '\n')
```

### Example usage
Running on a locally stored lockbox directory:
```
$ ls -li /tmp/lockbox
total 40
9830552 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 1
9830568 -rw-rw-r-- 1 user     user     8 Mar 31 16:20 10
9830553 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 2
9830560 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 3
9830561 -rw-rw-r-- 1 root     root     7 Mar 31 16:20 4
9830562 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 5
9830563 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 6
9830564 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 7
9830565 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 8
9830566 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 9

$ xxd -g4 /tmp/lockbox/1
00000000: 54657374 20310a                      Test 1.

$ ./gen_key.sh test.key
[+] Validating arguments...
[+] Key saved at test.key
[+] Success

$ ./lockbox.sh -e /tmp/lockbox $(xxd -p test.key | tr -d '\n')
[+] Validating arguments...
[+] Testing dependencies...
[*] Encrypting following files...
/tmp/lockbox/3
/tmp/lockbox/2
/tmp/lockbox/8
/tmp/lockbox/5
/tmp/lockbox/6
/tmp/lockbox/1
/tmp/lockbox/10
/tmp/lockbox/7
/tmp/lockbox/9
[+] Success

$ ls -li /tmp/lockbox
total 40
9830552 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 1
9830568 -rw-rw-r-- 1 user     user     8 Mar 31 16:20 10
9830553 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 2
9830560 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 3
9830561 -rw-rw-r-- 1 root     root     7 Mar 31 16:20 4
9830562 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 5
9830563 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 6
9830564 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 7
9830565 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 8
9830566 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 9

$ xxd -g4 /tmp/lockbox/1
00000000: 7b01114b f074cd                      {..K.t.

$ ./lockbox.sh -d /tmp/lockbox $(xxd -p test.key | tr -d '\n')
[+] Validating arguments...
[+] Testing dependencies...
[*] Decrypting following files...
/tmp/lockbox/3
/tmp/lockbox/2
/tmp/lockbox/8
/tmp/lockbox/5
/tmp/lockbox/6
/tmp/lockbox/1
/tmp/lockbox/10
/tmp/lockbox/7
/tmp/lockbox/9
[+] Success

$ ls -li /tmp/lockbox
total 40
9830552 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 1
9830568 -rw-rw-r-- 1 user     user     8 Mar 31 16:20 10
9830553 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 2
9830560 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 3
9830561 -rw-rw-r-- 1 root     root     7 Mar 31 16:20 4
9830562 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 5
9830563 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 6
9830564 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 7
9830565 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 8
9830566 -rw-rw-r-- 1 user     user     7 Mar 31 16:20 9

$ xxd -g4 /tmp/lockbox/1
00000000: 54657374 20310a                      Test 1.
```

Running on a remotely stored lockbox directory, leaving lockbox.sh local:
```
$ ./gen_key.sh test.key
[+] Validating arguments...
[+] Key saved at test.key
[+] Success

$ ssh user@remote-addr "bash -s" -- < ./lockbox.sh -e /tmp/remote-lockbox $(xxd -p test.key | tr -d '\n')
[+] Validating arguments...
[+] Testing dependencies...
[*] Encrypting following files...
/tmp/remote-lockbox/3
/tmp/remote-lockbox/2
/tmp/remote-lockbox/8
/tmp/remote-lockbox/5
/tmp/remote-lockbox/6
/tmp/remote-lockbox/1
/tmp/remote-lockbox/10
/tmp/remote-lockbox/7
/tmp/remote-lockbox/9
[+] Success

$ ssh user@remote-addr "bash -s" -- < ./lockbox.sh -d /tmp/remote-lockbox $(xxd -p test.key | tr -d '\n')
[+] Validating arguments...
[+] Testing dependencies...
[*] Decrypting following files...
/tmp/remote-lockbox/3
/tmp/remote-lockbox/2
/tmp/remote-lockbox/8
/tmp/remote-lockbox/5
/tmp/remote-lockbox/6
/tmp/remote-lockbox/1
/tmp/remote-lockbox/10
/tmp/remote-lockbox/7
/tmp/remote-lockbox/9
[+] Success
```
