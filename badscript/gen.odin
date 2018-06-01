package badscript

import "core:fmt"
import "core:unicode/utf8"

Variable :: struct
{
	name: string,
	index: int,
	is_global: bool,
	nodekind: NodeKind,
}

Scope :: struct
{
	parent: ^Scope,
	variables: [dynamic]Variable,
}

// TODO: Assert that we give an error if we exceed the maximum allowed locals(256)
//       This has to be counted on a per-func level, as the function "owns" the locals
Program :: struct
{
	name: string,
	top_levels: []^Node,
	global_scope: ^Scope,
	current_scope: ^Scope,
	code: [dynamic]Bytecode,
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

scope_get :: proc(program: ^Program, name: string) -> ^Variable
{ // Traverses up the scope and finds the variable, returns nil if we dont find any.
  // Keep in mind the returned value is invalited when this scope is popped
	scope := program.current_scope;
	for scope != nil
	{
		for v, it in scope.variables
		{
			if v.name == name
			{
				return &scope.variables[it];
			}
		}
		scope = scope.parent;
	}
	
	return nil;
}

scope_add :: proc(program: ^Program, _name: string, n: ^Node) -> int
{ // Returns index of the added variable
	_is_global := program.global_scope == program.current_scope;
	v := Variable{
		name = _name,
		index = len(&program.current_scope.variables),
		is_global = _is_global,
		nodekind = n.kind,
	};
	append(&program.current_scope.variables, v);
	return v.index;
}

generate_bytecode_for_program :: proc(using program: ^Program)
{
	// Where do we put this code? At the start of main()?
	
	{
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
}

make_program :: proc(name: string, top_levels: []^Node) -> ^Program
{
	p := new(Program);
	
	p.name = name;
	p.top_levels = top_levels;
	p.global_scope = make_scope(p);
	p.current_scope = p.global_scope;
	
	generate_bytecode_for_program(p);
	append(&p.code, Bytecode.GETGLOBAL);
	append(&p.code, cast(Bytecode) 0);
	append(&p.code, Bytecode.GETGLOBAL);
	append(&p.code, cast(Bytecode) 1);
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
	append(&bytes, 0);
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
		fmt.printf("op: %v\n", n.binary.op);
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