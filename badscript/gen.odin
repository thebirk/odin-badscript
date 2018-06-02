package badscript

import "core:fmt"
import "core:os"
import "core:unicode/utf8"

Variable :: struct
{
	name: string,
	index: int,
	is_global: bool,
	is_func: bool,
	nodekind: NodeKind,
}

Function :: struct
{
	variables: [dynamic]Variable,
}

Scope :: struct
{
	parent: ^Scope,
	variables: [dynamic]int,
}

// TODO: This is messy. Figure out a better way to handle scopes and locals as its a little
//       more complex than you thought at first. Lets say we have a scope which belong to a
//       function. We add a few locals and we now have 3 of them. Then we create a block
//       inside the function and add a few more of them. Problem is now those variables 
//       have local indicis starting from zero again and we are overwriting the parent scope
//       variables. bummer...
//
//       Heres what I think you should do. Use the function as a sort of data storage for the scope.
//       And all it holds are the variable references, so when the scope need a new variable
//       it ask the function for a local index. This way the Scope can still check if the 
//       name is in the current scope but scopes are no longer overwriting each other.

// TODO: Figure out a way so that we can call from other vms, that way we dont have to compile everything into one vm
//       This allows us to store things like the vm in bytecode form and save some time.

// TODO: Assert that we give an error if we exceed the maximum allowed locals(256)
//       This has to be counted on a per-func level, as the function "owns" the locals
Program :: struct
{
	name: string,
	top_levels: []^Node,
	global_scope: ^Scope,
	current_scope: ^Scope,
	lexer_data: []rune,
	code: [dynamic]Bytecode,
}

gen_error :: proc(using program: ^Program, node: ^Node, fmt_str: string, args: ...any)
{
	//TODO: If we are on windows check in ANSICON env variable is set, if it is
	//      windows has ANSI support. Otherwise dont print color.
	fmt.printf("\x1B[94m%s(%d:%d)\x1B[0m \x1B[91merror:\x1B[0m ", node.loc.filename, node.loc.line, node.loc.char);	
	fmt.printf(fmt_str, ...args);
	fmt.printf("\n\n");
	
	start := find_rune_from_right(lexer_data[..], node.loc.fileoffset, '\n');
	end := find_rune_from_left(lexer_data[..], node.loc.fileoffset, '\n');
	if lexer_data[start] == '\n' do start += 1;	
	if end < len(lexer_data) && lexer_data[end] == '\n' do end -= 1;
	output := lexer_data[start..end];
	
	prefix := "    > ";
	fmt.printf(prefix);
	//TODO: Fancy over-the-top idea! Syntax highlighting! Wouldnt that be amazing!!
	for r in output
	{
		fmt.printf("%r", r);
	}
	fmt.printf("\n");
	
	for i in 0..len(prefix)
	{
		fmt.printf(" ");
	}
	for i := start; i < node.loc.fileoffset-1; i += 1
	{
		if lexer_data[i] == '\t'
		{
			fmt.printf("\t");
		}
		else
		{
			fmt.printf(" ");
		}
	}
	fmt.printf("\x1B[91m^");
	if node.loc.length > 1
	{
		for i in 1..node.loc.length
		{
			fmt.printf("~");
		}
	}
	fmt.printf("\n\x1B[0m");
	
	os.exit(1);
}

make_scope :: proc(program: ^Program) -> ^Scope
{
	return new(Scope);
}

// Returns the new scope
push_scope :: proc(program: ^Program) -> ^Scope
{
	scope := make_scope(program);
	scope.parent = program.current_scope;
	program.current_scope = scope;
	return scope;
}

// Returns the current scope after popping
pop_scope :: proc(program: ^Program) -> ^Scope
{
	old_scope := program.current_scope;
	program.current_scope = old_scope.parent;
	free(old_scope);
	return program.current_scope;
}

scope_get :: proc(program: ^Program, function: ^Function, name: string) -> ^Variable
{ // Traverses up the scope and finds the variable, returns nil if we dont find any.
  // Keep in mind the returned value is invalited when this scope is popped
	scope := program.current_scope;
	for scope != nil
	{
		for index in scope.variables
		{
			v := &function.variables[index];
			if v.name == name
			{
				return &scope.variables[it];
			}
		}
		scope = scope.parent;
	}
	
	return nil;
}

reserve_local :: proc(program: ^Program, function: ^Function, n: ^Node) -> int
{
	if len(function.variables < 256)
	{
		index := len(function.variables);
		append(&function.variables, Variable{});
		return index;
	}
	else
	{
		gen_error(program, n, "Too many locals. You can only have a total of 256 locals!");
		return -1;
	}
}

scope_add :: proc(program: ^Program, function: ^Function, _name: string, n: ^Node) -> ^Variable
{ // Returns index of the added variable
	_is_global := program.global_scope == program.current_scope;
	_is_func := n.kind == NodeKind.FUNC;
	index := reserve_local(program, function, n);
	v := Variable{
		name = _name,
		index = index,
		is_global = _is_global,
		is_func = _is_func,
		nodekind = n.kind,
	};
	function.variables[index] = v;
	append(&program.current_scope.variables, index);
	return &function.variables[index];
}

generate_block :: proc(using program: ^Program, node: ^Node)
{
	assert(node.kind == NodeKind.BLOCK);
	push_scope(program);
	
	pop_scope(program);
}

generate_func :: proc(program: ^Program, node: ^Node)
{
	assert(node.kind == NodeKind.FUNC);
	address := len(program.code) + 1;
	name := make_string_from_runes(node.func.name);
	function := new(Function);
	v := scope_add(program, name, node);
	v.index = address;
}

generate_bytecode_for_program :: proc(using program: ^Program)
{
	// Where do we put this code? At the start of main()?
	
	{
		// I think we should only do this for func, and replace used addresses later.
		// Populate the global scope before generating code from the global scope
		for n in program.top_levels
		{
			switch n.kind {
			case NodeKind.VAR:
			{
				name := make_string_from_runes(n._var.name);
				scope_add(program, name, n);
			}
			case NodeKind.FUNC:
			{
				name := make_string_from_runes(n.func.name);
				scope_add(program, name, n);
			}
			case: assert(false, "Invalid switch case");
			}
		}
	}
	{
		// Generate code for global variables
		for n in program.top_levels
		{
			if(n.kind == NodeKind.VAR)
			{
				name := make_string_from_runes(n._var.name);
				v := scope_get(program, name);
				if n._var.expr != nil
				{
					generate_expr(program, n._var.expr);
					append(&code, Bytecode.SETGLOBAL);
					append(&code, cast(Bytecode) v.index);
				}
			}
		}
	}
	
	{
		// Generate functions
		for n in program.top_levels
		{
			if(n.kind == NodeKind.FUNC)
			{
				generate_func(program, n);
			}
		}
	}
}

make_program :: proc(name: string, top_levels: []^Node, lexer_data: []rune) -> ^Program
{
	p := new(Program);
	
	p.name = name;
	p.top_levels = top_levels;
	p.global_scope = make_scope(p);
	p.current_scope = p.global_scope;
	p.lexer_data = lexer_data;
	
	generate_bytecode_for_program(p);
	append(&p.code, Bytecode.GETGLOBAL);
	append(&p.code, cast(Bytecode) 0);
	append(&p.code, Bytecode.GETGLOBAL);
	append(&p.code, cast(Bytecode) 1);
	append(&p.code, Bytecode.GETGLOBAL);
	append(&p.code, cast(Bytecode) 2);
	append(&p.code, Bytecode.STOP);
	
	return p;
}


make_string_from_runes :: proc(runes: []rune) -> string
{
	bytes: [dynamic]u8;
	for r in runes
	{
		buffer, length := utf8.encode_rune(r);
		append(&bytes, ...buffer[..length]);
	}
	return string(bytes[..]);
}

generate_expr :: proc(using program: ^Program, n: ^Node)
{
	using NodeKind;
	switch n.kind {
	case NAME:
	{
		name := make_string_from_runes(n.name.name);
		v := scope_get(program, name);
		if v == nil
		{
			gen_error(program, n, "Undeclared variable: '%s'", name);
			assert(false, "Handle error and display call stack, and print error on n.loc");
		}
		if v.is_global
		{
			append(&code, Bytecode.GETGLOBAL);
		}
		else
		{
			append(&code, Bytecode.GETLOCAL);
		}
		append(&code, cast(Bytecode) v.index);
	}
	case NUMBER:
	{
		append(&code, Bytecode.PUSHNUMBER);
		write_f64(&code, n.number.value);
	}
	case BINARY:
	{
		assert(n.binary.op == TokenKind.ADD, "Temp assert! Incomplete");
		generate_expr(program, n.binary.lhs);
		generate_expr(program, n.binary.rhs);
		append(&code, Bytecode.ADD);
	}
	
	case: assert(false, "Incomplete or invalid switch case");
	}
	}
	}
}