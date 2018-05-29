package badscript

/*

Exmaple:
func main: 1 arg, 2 locals
	PUSHN 0                 ; [ 0 ]
	SETLOCAL 0              ; [ ]    
	PUSHARG 0               ; [ args_table ]
	CALL len 1              ; [ numargs ]
	SETLOCAL 1              ; [ ]
	GETLOCAL 0              ; [ 0 ]
	GETLOCAL 1              ; [ 0 numargs ]
	JG enough_args          ; [ ]
	PUSHS "Not enough args" ; [ "Not enough args" ]
	CALL println 1          ; [ ]
	RETURN
enough args:
	PUSHS "We have args"    ; [ "We have args" ]
	CALL println 1          ; [ ]
	RETURN

*/

Bytecode :: enum u8
{
	PUSHNUMBER,
	PUSHNULL,
	PUSHTRUE,
	PUSHFALSE,
	PUSHSTRING,
	PUSHTABLE,
	GETLOCAL,
	SETLOCAL,
	GETGLOBAL,
	SETGLOBAL,
	TABLESET,
	TABLEGET,
	CALL,
	METHODCALL,
	JE,
	JNE,
	JL,
	JLE,
	JG,
	JGE,
	JTRUE,
	JFALSE,
	ADD,
	SUB,
	MUL,
	DIV,
	MOD,
}