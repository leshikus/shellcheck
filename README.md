# Rationale Behind Shell Scripting

## How to Check a Script?

Check the following function definitions.

```
variant1$ function f() {
  echo Use the keyword
}
```


```
variant2$ f() {
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

It is either a bash version or an empty string. For example, in newer versions of Debian `/bin/sh` points to `/bin/dash`.

</details>


`dash` does not have a number of advanced `bash` features including hash tables and lists.


<details>

<summary>Assuming you have a minimal shell version, how would you implement hash tables?</summary>

A file which is named as a hash key.

</details>


<details>

<summary>Assuming you have a minimal shell version, how would you implement a list? How would you effectively get all elements of `list1` which are not a part of `list2`?</summary>

A unix way to implement a list data structure is just a file with strings. You can use list operations as follows.
```
$ sort list1 list2 list2 | uniq -u
```
</details>



<details>

<summary>How many options do I have for a command line interpreter?</summary>

Most common and sufficiently compatible options include:

- `sh` POSIX shell standard`
- `bash`
- `dash`
- Korn shell `ksh`

There are also less compatible options like `csh`, `tcsh`, PowerShell, cmd, etc.

</details>


<details>What command line interpreter should I use?</summary>

This is a religious belief question, yet I think there is some rationale behind not using advanced bash functionality. In other words, I'd recommend using a minimal subset of functionality which is common for all interpreters.

- Command line interpreters really shine when you execute lists of commands and use other operating system features.
- All other language functinality, including arrays, hash tables, etc, is better to be written in a real programming language e.g. python. Better means cheaper to debug and support.

</details>




Не используйте новую функциональность
Если ваш скрипт требует использования новой функциональности bash, например, по соображениям скорости и работы с данными в памяти, то скорее всего его следует написать на python3.
1. Вместо [[ используйте test.
В некоторых установках Линукса, в том числе в новом Дебиан, /bin/sh указывает на dash вместо bash. У этого интерпретатора меньше возможностей. Например. поддерживаются {}, local a=b, export a=b.


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
Используйте IFS= read -r
Опция -r позволит читать бэкслэши \. Очистка IFS гарантирует, что будет прочитана ровно одна строка.
Используйте функции do_something
Использование имен функций, начинающихся с глагола, поможет не писать комментарии # here we do something, а также эффективно отлаживать код по частям. Вместо того, чтобы описывать в комментариях аргументы функций, используйте значимые имена переменных:
backup_package() {
  local package
  package="$1"

  cp "$package" "$package".old
}
Используйте trap для очистки состояния
Следующая команда гарантирует, что cleanup будет вызван при любом завершении скрипта, за исключением сигнала -KILL.
$ trap cleanup EXIT
Можно, например, отмонтировать временные пути.
Пишите компактно
Мало строк - проще читать. Например, HEREDOC:
$ cat <<EOF >autogen.sh
echo This is autogenerated $SCRIPT
EOF
Используйте || вместо if, не используйте &&:
$ do_action || report_error
Используйте { вместо (
Группа команд в фигурных скобках выполняется без запуска дополнительного процесса.
Удаляйте с возвратом
Вместо удаления можно переместить файл командой mv в папку trash/. Запускать чистку этой папки можно перед началом работы, при этом несколько явно указанных символов в названии папки гарантирует, что не будет стерто что-то полезное:
$ rm -rf trash/
