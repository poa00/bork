# helpers related to the "compile" operation

# are we compiling?
is_compiling () {
  [ $operation = "compile" ] && return 0 || return 1
}
# are we running from a compiled script?
is_compiled () { return 1; }

# multiline, keeps list of compiled types
bag init compiled_types

# TODO: test
# interface for the compiled_type multiline
compiled_type_push () {
  bag push compiled_types "$1"
}
# TODO: test
# interface for the compiled_type multiline
compiled_type_exists () {
  exists=$(bag find compiled_types "^$1\$")
  [ -n "$exists" ]
  return $?
}

# if compiling, echoes a function that contains the given assertion
# include_assertion_for_compiling $assertion_type $file_path
# - $assertion_type: key for the assertion
# - $file_path: absolute/relative path to the file
#
# returns immediately with 0 if not compiling
include_assertion () {
  if ! is_compiling; then return 0; fi
  if compiled_type_exists $1; then return 0; fi
  compiled_type_push $1
  echo "type_$1 () {"
  cat $2 | strip_blanks | awk '{print "  " $0}'
  echo "}"
}

strip_blanks () {
  awk '!/^($|[:space:]*#)/{print $0}' <&0
}

base_compile () {
cat <<DONE
#!/usr/bin/env bash
$setupFn
BORK_SCRIPT_DIR=\$PWD
BORK_WORKING_DIR=\$PWD
operation="satisfy"
case "\$1" in
  status) operation="\$1"
esac
is_compiled () { return 0; }
DONE
  for file in $BORK_SOURCE_DIR/lib/*; do
    case $(basename $file .sh) in
      compiler | runner | include ) : ;;
      *) cat $file | strip_blanks ;;
    esac
  done
  cat $1 | while read line; do
    first_token=$(str_get_field "$line" 1)
    case $first_token in
      ok)
        type=$(str_get_field "$line" 2)
        fn=$(lookup_type $type)
        if [ -z "$fn" ]; then
          echo "type $type not found, can't proceed" 1>&2
          exit 1
        fi
        include_assertion $type $fn
        . $fn compile
        echo "$line"
        ;;
      register) eval "$line" ;;
      include)
        echo "include not supported for 'compile' operation yet" 1>&2
        exit 1
        ;;
      *) echo "$line" ;;
    esac
  done
}
