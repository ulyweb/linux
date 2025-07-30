# linux
my linux commands


While `ls -lah` is a useful command for listing files with human-readable sizes, it doesn't directly show the *total size of each directory* within a given path. It shows the size of the directory *entry* itself (which is usually a small, fixed size), not the sum of its contents.

To display directories including the size of each directory (meaning the sum of the sizes of all files and subdirectories within them), the command you're looking for is `du`.

Here are a few variations of the `du` command that you might find helpful, along with explanations:

1.  **`du -h --max-depth=1 .`**

      * `du`: Stands for "disk usage."
      * `-h`: Human-readable format (e.g., K for kilobytes, M for megabytes, G for gigabytes).
      * `--max-depth=1`: This is crucial. It tells `du` to only show the total size of the current directory (`.`) and its immediate subdirectories. Without this, `du` would recursively list the size of every file and subdirectory, which can be overwhelming.
      * `.`: Represents the current directory. You can replace this with any path you want to examine (e.g., `/home/youruser/documents`).

    **Example Output:**

    ```
    4.0K    ./.cache
    12M     ./Pictures
    8.0K    ./Documents
    2.4G    ./Downloads
    4.0K    ./.ssh
    2.5G    .
    ```

    This output shows the size of each top-level directory within the current directory, and the total size of the current directory at the end.

2.  **`du -sh *`**

      * `du`: Disk usage.
      * `-s`: Summarize. This option tells `du` to only display a total for each argument. When combined with `*`, it will summarize the size of each file and directory in the current directory.
      * `-h`: Human-readable format.
      * `*`: A wildcard that expands to all files and directories in the current directory.

    **Example Output:**

    ```
    4.0K    .cache
    12M     Pictures
    8.0K    Documents
    2.4G    Downloads
    4.0K    .ssh
    ```

    This is very similar to the first command but doesn't include the total for the current directory itself at the end. It's good if you just want to see the individual sizes of items in the current directory.

3.  **`du -ach --max-depth=1 .`**

      * `du`: Disk usage.
      * `-a`: Include all files, not just directories (though with `--max-depth=1` and focusing on directories, this might not be strictly necessary, but good to know).
      * `-c`: Produce a grand total.
      * `-h`: Human-readable.
      * `--max-depth=1`: Limit to current directory and immediate subdirectories.
      * `.`: Current directory.

    This command combines the `max-depth` with a grand total, providing a good summary.

**Which one should you use?**

  * For a quick overview of the sizes of immediate subdirectories in your current location, **`du -h --max-depth=1 .`** is usually the most informative.
  * If you just want a summary of individual files and directories without the grand total of the current directory, use **`du -sh *`**.

Try these commands in your terminal on your Ubuntu or Debian system, and you'll see the directory sizes as you intended\!


### There are hundreds of Linux commands, but some are absolutely fundamental and used constantly, whether you're a new user or a seasoned system administrator.

Here's a list of some of the most useful and popular Linux commands, categorized for clarity:

**1. Navigating and Listing:**

* **`ls`** (list): Lists the contents of a directory.
    * `ls -l`: Long format, showing permissions, owner, size, date, etc.
    * `ls -a`: Show all files, including hidden ones (starting with a dot).
    * `ls -lh`: Long format, human-readable sizes (like 1.2M, 4K).
    * `ls -F`: Appends a character to filenames to indicate their type (`/` for directory, `*` for executable, `@` for symbolic link).
* **`pwd`** (print working directory): Shows the full path of your current directory.
* **`cd`** (change directory): Navigates between directories.
    * `cd ~` or `cd`: Go to your home directory.
    * `cd ..`: Go up one directory level.
    * `cd -`: Go back to the previous directory you were in.

**2. File and Directory Management:**

* **`mkdir`** (make directory): Creates a new directory.
    * `mkdir -p path/to/new/directory`: Creates parent directories if they don't exist.
* **`rmdir`** (remove directory): Deletes an empty directory.
* **`rm`** (remove): Deletes files or directories. **Use with caution!** Deleted files are typically not recoverable from the command line (they don't go to a "recycle bin").
    * `rm file.txt`: Deletes a file.
    * `rm -r directory_name`: Deletes a directory and its contents recursively.
    * `rm -rf directory_name`: **Forcefully** deletes a directory and its contents recursively, without prompting. **Extremely dangerous if used incorrectly.**
* **`cp`** (copy): Copies files and directories.
    * `cp file.txt /path/to/destination/`: Copies `file.txt` to the specified destination.
    * `cp -r directory_name /path/to/destination/`: Copies a directory and its contents recursively.
* **`mv`** (move/rename): Moves files or directories, or renames them.
    * `mv file.txt /path/to/new_location/`: Moves `file.txt`.
    * `mv oldname.txt newname.txt`: Renames `oldname.txt` to `newname.txt`.
* **`touch`**: Creates an empty file or updates the timestamp of an existing file.
    * `touch new_file.txt`
* **`cat`** (concatenate): Displays the content of a file. Good for small files.
    * `cat file.txt`
* **`less`**: View file content page by page. Useful for large files. Press `q` to quit.
    * `less large_log_file.log`
* **`head`**: Displays the first few lines of a file (default 10).
    * `head -n 5 file.txt`: Shows the first 5 lines.
* **`tail`**: Displays the last few lines of a file (default 10).
    * `tail -n 5 file.txt`: Shows the last 5 lines.
    * `tail -f file.log`: Follows the file as it grows (useful for live logs).

**3. Searching and Filtering:**

* **`grep`** (global regular expression print): Searches for patterns in files.
    * `grep "search_term" file.txt`: Finds lines containing "search\_term" in `file.txt`.
    * `grep -i "search_term" file.txt`: Case-insensitive search.
    * `grep -r "search_term" /path/to/directory`: Recursive search through a directory.
* **`find`**: Searches for files and directories based on various criteria.
    * `find . -name "*.txt"`: Finds all `.txt` files in the current directory and subdirectories.
    * `find /home/user -type d -name "Documents"`: Finds a directory named "Documents" under `/home/user`.

**4. Disk and System Information:**

* **`du`** (disk usage): Estimates file space usage (as you just learned!).
    * `du -h --max-depth=1 .`: Shows size of immediate subdirectories.
    * `du -sh /path/to/directory`: Summarizes the total size of a specific directory.
* **`df`** (disk free): Displays free and used disk space on filesystems.
    * `df -h`: Human-readable format.
* **`top`**: Displays real-time system process activity. Press `q` to quit. `htop` is a more user-friendly alternative often preferred.
* **`free`**: Displays amount of free and used memory.
    * `free -h`: Human-readable format.
* **`ps`** (process status): Reports information about current processes.
    * `ps aux`: Shows all processes by all users.
* **`uname`**: Prints system information.
    * `uname -a`: Prints all system information.

**5. Permissions and Ownership:**

* **`chmod`** (change mode): Changes file permissions.
    * `chmod 755 script.sh`: Makes a script executable by owner, readable and executable by group and others.
* **`chown`** (change owner): Changes file ownership.
    * `chown user:group file.txt`: Changes owner to `user` and group to `group`.
* **`sudo`** (super user do): Executes a command with administrative (root) privileges. **Use with caution!**
    * `sudo apt update`: Updates package lists (on Debian/Ubuntu).

**6. Networking:**

* **`ping`**: Tests connectivity to a network host.
    * `ping google.com`
* **`ip a`** (IP address): Shows network interface information (modern alternative to `ifconfig`).
* **`ssh`** (secure shell): Connects to a remote server securely.
    * `ssh username@remote_host`
* **`wget`** or **`curl`**: Downloads files from the web.
    * `wget https://example.com/file.zip`

**7. Miscellaneous but Important:**

* **`man`** (manual): Displays the manual page for a command. Your best friend for learning about new commands or options.
    * `man ls`
* **`history`**: Shows previously executed commands.
* **`clear`**: Clears the terminal screen.
* **`echo`**: Displays text to the terminal.
    * `echo "Hello, world!"`

This list provides a solid foundation. As you get more comfortable, you'll naturally discover more specialized commands for specific tasks. The key is to practice and use `man` whenever you're unsure about a command's options!
