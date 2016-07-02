#!/bin/sh

LOADER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOADER_SCRIPTS_DIR=$LOADER_DIR/.
LOADER_DEST_DIR=$LOADER_DIR/.
LOADER_TARGET_FILE=loader.zip

#安卓的自行在上层脚本里面配置好使用JIT的选项
#USE_JIT='-jit'  #需要使用则打开
USE_JIT=''  #留空则关闭JIT编译

LOADER_COMPILE_BIN=$QUICK_V3_ROOT/quick/bin/compile_scripts.sh $USE_JIT

# 编译游戏脚本文件
rm -f $LOADER_DEST_DIR/$LOADER_TARGET_FILE
$LOADER_COMPILE_BIN -i $LOADER_SCRIPTS_DIR -o $LOADER_DEST_DIR/$LOADER_TARGET_FILE

