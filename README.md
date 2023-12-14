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


Можно использовать синтаксис, который работает как в bash, так и в dash:
1. Вместо
Используйте останов по ошибке
В отличие от обычных программ скрипты после ошибки не останавливаются и могут поломать что-нибудь ещё.  Установите следующую опцию в начале работы, чтобы скрипт останавливался по ошибке:
$ set -e
Также для отладки полезно включать:
$ set -vx
При использовании пайпов используйте для корректной обработки ошибок:
$ set -o pipefail
Для того, чтобы ваш скрипт убивал свои подпроцессы используйте:
$ shopt -s huponexit
Если вы внимательно читали этот раздел, то знаете, что в шелле есть три разных синтаксиса для установки разных внутренних опций. Но главное здесь - не опции, а методологическое правило "сломайся быстро". Вместо сложной логики в любой непонятной ситуации скрипт должен выполнить простую проверку и остановиться с ошибкой.
Используйте кавычки вокруг аргументов
При наличии пробела в имени файла следующая команда будет интерпретирована неправильно.
$ cp $file $target
 Правильный вариант:
$ cp "$file" "$target"
Другой пример:
$ cp *.txt /dir
Если в имени какого-то из txt-файлов - пробел, он не будет скопирован. Правильный вариант:
$ cp "*.txt" /dir
Не используйте файлы с именем, начинающимся с -
Такие файлы не надо создавать самому. Но если файлы приходят откуда-то снаружи, потребуется добавить в скрипт -- перед передачей их в качестве аргументов системным командам.


По возможности лучше не использовать экспорт переменных.
Также, существуют ситуации, когда нестандартный синтаксис не выдает ошибку, но дает разный результат, например:
$ f() {
‍‍‍‍‍‍ ‍‍echo $a
}
$ a=0
$ a=1 f
$ echo $a

Используйте trap для очистки состояния
Следующая команда гарантирует, что cleanup будет вызван при любом завершении скрипта, за исключением сигнала -KILL.
$ trap cleanup EXIT
Можно, например, отмонтировать временные пути.
Пишите компактно
Мало строк - проще читать. Например, HEREDOC:
$ cat <<EOF >autogen.sh
echo This is autogenerated $SCRIPT
EOF



## Conditionals

Consider several conditionals:

```
test -f test && echo test exists
[ -f test ] && echo test exists
[[ -f test ]] && echo test exists
if [ -f test ]; then echo test exists; fi
```


<details>

<summary>What is the preferred variant?</summary>

The brackets were invented to make conditional look like in other languages. Masking one feature with another has when analogy breaks. For example, you cannot 

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
- `IFS=$table_separator read -r a b c` (`-r` is used for reading slashes)
- `awk -F$table_separator`, just don't use its arrays and hashtables
- `cut -d$table_separator`

Writing text tables:
- `import prettytable`

</details>
