package badscript

import "core:fmt"

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
	RETURN,
	STOP,
}

// We should have some sort of frame call stack
VirtualMachine :: struct
{
	code: [dynamic]Bytecode,
	stack: [dynamic]^Value,
	globals: [dynamic]^Value,
	ip: int,
	running: bool,
}

make_vm :: proc() -> ^VirtualMachine
{
	vm := new(VirtualMachine);
	vm.ip = 0;		
	return vm;
}

runtime_error :: proc(using vm: ^VirtualMachine)
{
	//TODO: actually implement this thing
	assert(false);
}

write_f64 :: proc(using vm: ^VirtualMachine, number: f64)
{
	v := transmute(u64)number;
	for i in 0..8
	{
		append(&code, cast(Bytecode) (v & 0xFF));
		v = v >> 8;
	}
}

read_and_copy_utf8_string :: proc(using vm: ^VirtualMachine) -> string
{
	//TODO: We should probably prefix strings with 
	// a length, what size do we want. u64 wont waste that much as were arent going to have *that* many strings
	return "ello";
}

read_f64 :: proc(using vm: ^VirtualMachine) -> f64
{
	v: u64 = 0;
	offset := cast(u64)0;
	for i in 0..8
	{
		v |= cast(u64) code[ip] << offset;
		offset += 8;
		ip += 1;
	}
	return transmute(f64)v;
}

read_u8 :: proc(using vm: ^VirtualMachine) -> u8
{
	v := cast(u8)code[ip];
	ip += 1;
	return v;
}

run :: proc(using vm: ^VirtualMachine) -> [dynamic]^Value
{
	running = true;
	for running
	{
		op := code[ip];
		ip += 1;
		
		fmt.printf("Bytecode: %v", op);
		using Bytecode;
		switch op {
		case STOP:
			running = false;
		case PUSHNUMBER:
			num := new_value(Number);
			num.number = read_f64(vm);
			append(&stack, num);
		case PUSHSTRING:
			str := new_value(String);
			str.text = read_and_copy_utf8_string(vm);
			append(&stack, str);
		case PUSHNULL:
			append(&stack, null_value);
		case PUSHTRUE:
			append(&stack, true_value);
		case PUSHFALSE:
			append(&stack, false_value);
		case PUSHTABLE:
			append(&stack, new_value(Table));
		case ADD:
			rhs := pop(&stack);
			lhs := pop(&stack);
			append(&stack, value_add(lhs, rhs));
		case GETGLOBAL:
			global := read_u8(vm);
			append(&stack, globals[global]);
		case SETGLOBAL:
			global := read_u8(vm);
			globals[global] = pop(&stack);
		}
		
		fmt.printf(", stack: %v\n", stack);
	}
	
	return stack;
}