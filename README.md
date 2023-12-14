# Rationale Behind Shell Scripting

## How to Check?

Check the following function definitions.

```
$ function func1() {
  echo Use the keyword
}
```


```
$ func2() {
  echo Do not use the keyword
}
```

<details>

<summary>Which of two variants should one use?</summary>

`dash` does not understand `function` keyword. `dash` is a rewritten and shorter version of `bash`:

```
$ ls -l /bin/?ash
-rwxr-xr-x 1 root root 1183448 Apr 18  2022 /bin/bash
-rwxr-xr-x 1 root root  129816 Jul 18  2019 /bin/dash
```

Consider writing `dash`-aware scripts. Instead of `local a="$b"` use the following:

```
local a
a="$b"
```

Instead of `export a="$b"` use the following:

```
a="$b"
export a
```

</details>

<details>

<summary>How to guess the problems like this?</summary>


Use `shellcheck`, e.g.

```
$ shellcheck test.sh

In test.sh line 4:
function f() { echo $a; }
^-----------------------^ SC2112: 'function' keyword is non-standard. Delete it.

For more information:
  https://www.shellcheck.net/wiki/SC2112 -- 'function' keyword is non-standar...
```

</details>

## One-Liner

Consider the following script.

```
echo Test
```

<details>
<summary>Guess the basic problem with it</summary>

```
In test.sh line 1:
echo Test
^-- SC2148: Tips depend on target shell and yours is unknown. Add a shebang.

For more information:
  https://www.shellcheck.net/wiki/SC2148 -- Tips depend on target shell and y...
```

Note, each problem has a dedicated page with explanations.
<a href="https://en.wikipedia.org/wiki/Shebang_(Unix)">Shebang</a> is a way to indicate the command line interpreter. It looks like `#!/bin/sh` or `#!/bin/bash` in the first line.

</details>

Assume the script produces the following error

```
$ cat test.sh
echo Test
$ sh test.sh
test.sh: line 1: $'\357\273\277echo': command not found
```

<details>

<summary>Guess the problem</summary>

An UTF-8 editor added a <a href="https://en.wikipedia.org/wiki/Byte_order_mark">byte order mark</a> to the script.

</details>


## Bash or not Bash

Consider the following script

```
#!/bin/sh

echo "$BASH_VERSION"
```

<details>

<summary>What does this script print?</summary>

It is undefined. For example, in newer versions of Debian `/bin/sh` symbolically links to `/bin/dash`.
If the first line would be `#!/bin/bash`, would it guarantee the result?

</details>



<details>

<summary>How many options do I have for a command line interpreter?</summary>

Most common and sufficiently compatible options include:

- `sh` POSIX shell standard which is not a separate shell but a mode for running the implementation
- most popular `bash`
- `dash` which does not include a number of advanced `bash` features including hash tables and lists
- Korn shell `ksh`

There exist less compatible shells including like `csh`, `tcsh`, PowerShell, cmd, etc.

</details>



<details>

<summary>What command line interpreter should I use?</summary>

This is a religious belief question, yet I think there is some rationale behind not using advanced bash functionality and limit yourself to a POSIX shell.

- Command line interpreters really shine when you execute lists of commands and use other operating system features.
- All other language functinality, including arrays, hash tables, etc, is better to be written in a real programming language e.g. python3. Better means cheaper to debug and support.

</details>



## POSIX Shell

The following questions are about POSIX shell with no advanced bash functionality.



<details>

<summary>How would you implement hash tables?</summary>

A file which is named as a hash key.

</details>



<details>

<summary>How would you implement a list? How would you get all elements of list1 which are not a part of list2?</summary>

A unix way to implement a list data structure is just a file with strings. You can do list operations as follows.
```
$ sort list1 list2 list2 | uniq -u
```
</details>


## Fail Early

<details>

<summary>What makes shells different from other languages with respect to error handling?</summary>

By default shell scripts do not stop on errors. Fortunately this can be changed to some extent by setting the following options.
- `set -e` stop on error (which does make shell sometimes to stop if a statement return an error code),
- `set -u` stop on unset variables
- `set -o pipefail` stop if one of pipe components fail (does not work in POSIX)
- `set -vx` print commands which is being executed
- `shopt -s huponexit` kill child processes on interactive login shell exit (send SIGHUP)

One may notice here that there are three different ways to set a shell option. Two could be even combined in one command `set -eo pipefail`.

</details>

## Quoting

Consider the following program:

```
$ cat count_arguments.sh
#!/bin/sh

count_args() {
  echo $#
}

echo $# # print argument count
count_args $@ # pass all arguments
```

Here is an example how it works:
```
sh count_arguments.sh 1 2
2
2
```

<details>

<summary>When it won't count arguments correctly and how to fix it?</summary>

Here is an example:
```
sh count_arguments.sh 1 '2 3'
2
3
```

The correct program quotes function arguments, e.g. invokes `count_args "$@"`.


</details>



## Conditionals

Consider several conditionals:

```
/bin/test -f test && echo test exists
test -f test && echo test exists
/bin/[ -f test ] && echo test exists
[ -f test ] && echo test exists
[[ -f test ]] && echo test exists
if [ -f test ]; then echo test exists; fi
```


<details>

<summary>What are the differences? What is the preferred variant?</summary>

- Generally it's a good strategy to use the style of the original author.
- If the condition is somewhat complex, maybe it should not be a part of the script.
- I prefered `test` because it outlined the fact that conditional statements in shells process return codes of conditions. Now `test` becomes `bash` builtin, thus the choice is purely cosmetic.

Historically brackets were introduced to resembles how other languages. Double brackets appeared in Korn shell to support more different conditions.

The following issues can be disregarded in the modern versions:
- There was also a difference between `||` and `&&` with respect to `set -e` setting.
- `if` launched a separed subshell and exiting it caused different issues.

</details>


## Globs

Consider the following

```
rm -f $package*
```

<details>

<summary>What could be the problem with this?</summary>

This command may delete something unexpected if
- `package` var is not set,
- `package` var contains a space

</details>


Consider the following invocation.

```
mount.sh -o ro,sync,user
```
???
<details>

<summary>How would you parse this?</summary>

A switch statement can help

```
arg=ro,sync,user
case ",$arg," In
	*,ro,*)
		echo ro
		;;
	*,sync,*)
		echo sync
		;;
	*,user,*)
		echo user
		;;
esac
```


</details>

## Brackets

Consider two functions.

```
func1() { cd; }
```

```
func2() ( cd; )
```

<details>

<summary>What is the difference?</summary>

The curly bracket does not start a separate process. The second function will execute `cd` in a separate process and this won't affect the current directory of the calling shell.

</details>



## Comments

Consider the following comment

```
# delete the package dir
rm -rf "$p"
```


<details>

<summary>What would you change?</summary>

Delete the comment, use the function.
```
delete_package_dir() {
  local package_dir
  package_dir="$1"

  mv "$package_dir" "$package_dir".old
  rm -rf "$package_dir".old &
}

delete_package_dir "$p"
```

Why .old is important?

</details>



## .vimrc

<details>

<summary>Which one do you use?</summary>

I like this one:

```
set tabstop=4 expandtab
syntax on
```

Setting tabstop to two is less conventional.

</details>




## Tables

<details>

<summary>Which options does shell have to work with text tables?</summary>

Reading tables:
- `IFS="$table_separator" read -r a b c` (`-r` is used for reading slashes)
- `awk -F"$table_separator"`, just don't use its arrays and hashtables
- `cut -d"$table_separator"`

Writing text tables:
- `import prettytable`

</details>
