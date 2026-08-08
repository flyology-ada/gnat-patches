#!/usr/bin/env bash

resolve_regression_toolchain() {
  local candidate
  REGRESSION_TOOLCHAIN=$1
  if [[ -d "$REGRESSION_TOOLCHAIN" ]]; then
    REGRESSION_TOOLCHAIN=$(cd "$REGRESSION_TOOLCHAIN" && pwd)
  fi

  REGRESSION_GNATMAKE="$REGRESSION_TOOLCHAIN/bin/gnatmake"
  if [[ ! -x "$REGRESSION_GNATMAKE" ]]; then
    candidate=$(command -v gnatmake || command -v gnatmake-13 || true)
    [[ -x "$candidate" ]] || {
      echo "error: no gnatmake in $REGRESSION_TOOLCHAIN or PATH" >&2
      return 1
    }
    REGRESSION_GNATMAKE=$candidate
  fi

  REGRESSION_GCC="$REGRESSION_TOOLCHAIN/bin/gcc"
  if [[ ! -x "$REGRESSION_GCC" ]]; then
    candidate=$(command -v gcc || command -v gcc-13 || true)
    [[ -x "$candidate" ]] || {
      echo "error: no gcc in $REGRESSION_TOOLCHAIN or PATH" >&2
      return 1
    }
    REGRESSION_GCC=$candidate
  fi

  REGRESSION_ENV=(env)
  if [[ $(uname -s) == Darwin && -d "$REGRESSION_TOOLCHAIN/lib" ]]; then
    REGRESSION_ENV+=("DYLD_LIBRARY_PATH=$REGRESSION_TOOLCHAIN/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}")
    REGRESSION_ENV+=("LD_LIBRARY_PATH=$REGRESSION_TOOLCHAIN/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}")
    REGRESSION_ENV+=("LD_RUN_PATH=$REGRESSION_TOOLCHAIN/lib${LD_RUN_PATH:+:$LD_RUN_PATH}")
  elif [[ -d "$REGRESSION_TOOLCHAIN/lib64" ]]; then
    REGRESSION_ENV+=("LIBRARY_PATH=$REGRESSION_TOOLCHAIN/lib64${LIBRARY_PATH:+:$LIBRARY_PATH}")
    REGRESSION_ENV+=("LD_LIBRARY_PATH=$REGRESSION_TOOLCHAIN/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}")
    REGRESSION_ENV+=("LD_RUN_PATH=$REGRESSION_TOOLCHAIN/lib64${LD_RUN_PATH:+:$LD_RUN_PATH}")
  elif [[ -d "$REGRESSION_TOOLCHAIN/lib" ]]; then
    REGRESSION_ENV+=("LIBRARY_PATH=$REGRESSION_TOOLCHAIN/lib${LIBRARY_PATH:+:$LIBRARY_PATH}")
    REGRESSION_ENV+=("LD_LIBRARY_PATH=$REGRESSION_TOOLCHAIN/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}")
    REGRESSION_ENV+=("LD_RUN_PATH=$REGRESSION_TOOLCHAIN/lib${LD_RUN_PATH:+:$LD_RUN_PATH}")
  fi
}
