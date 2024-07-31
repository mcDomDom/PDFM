#!/bin/sh

#ASMOPT=/mx
ASMOPT=

wine tasm32 $ASMOPT head.asm
wine tasm32 $ASMOPT tail.asm

