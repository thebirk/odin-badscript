package main

using import "core:fmt"
import bs "badscript"

Indenter :: struct
{
	offset: int,
	size: int,
}

indent :: proc(using i: ^Indenter)
{
	offset += 1;
}

dedent :: proc(using i: ^Indenter)
{
	offset -= 1;
}

print_indent :: proc(using i: ^Indenter)
{
	for i := 0; i < offset; i += 1
	{
		for j := 0; j < size; j += 1
		{
			fmt.printf(" ");
		}
	}
}

print_node :: proc(using i: ^Indenter, n: ^bs.Node)
{
	print_indent(i);
	if n == nil
	{
		printf("nil\n");
		return;
	}
	else
	{
		printf("%v\n", n.kind);
	}
	indent(i);
	using bs.NodeKind;
	switch n.kind
	{
	case NAME:
	{
		print_indent(i);
		printf("name: %v\n", n.name.name);
	}
	case STRING:
	{
		print_indent(i);
		printf("string: %v\n", n.str.str);
	}
	case NUMBER:
	{
		print_indent(i);
		printf("value: %f\n", n.number.value);
	}
	case BINARY:
	{
		print_indent(i);
		printf("op: %v\n", n.binary.op);
		print_indent(i);
		printf("lhs:\n");
		indent(i);
		print_node(i, n.binary.lhs);
		dedent(i);
		print_indent(i);
		printf("rhs:\n");
		indent(i);
		print_node(i, n.binary.rhs);
		dedent(i);
	}
	case UNARY:
	{
		print_indent(i);
		printf("op: %v\n", n.unary.op);
		print_indent(i);
		printf("expr:\n");
		indent(i);
		print_node(i, n.unary.expr);
		dedent(i);
	}
	case INDEX:
	{
		print_indent(i);
		printf("expr:\n");
		indent(i);
		print_node(i, n.index.expr);
		dedent(i);
		print_indent(i);
		printf("index_expr:\n");
		indent(i);
		print_node(i, n.index.index_expr);
		dedent(i);
	}
	case VAR:
	{
		print_indent(i);
		printf("name: %v\n", n._var.name);
		print_indent(i);
		printf("expr:\n");
		indent(i);
		print_node(i, n._var.expr);
		dedent(i);
	}
	case BLOCK:
	{
		print_indent(i);
		printf("stmts:\n");	
		for stmt in n.block.stmts
		{
			indent(i);
			print_node(i, stmt);
			dedent(i);
		}
	}
	case FUNC:
	{
		print_indent(i);
		printf("name: %v\n", n.func.name);
		print_indent(i);
		printf("args: %v\n", n.func.args);
		print_indent(i);
		printf("block:\n");
		indent(i);
		print_node(i, n.func.block);
		dedent(i);
	}
	case RETURN:
	{
		print_indent(i);
		printf("expr:\n");
		indent(i);
		print_node(i, n.ret.expr);
		dedent(i);
	}
	case IF:
	{
		print_indent(i);
		printf("cond:\n");
		indent(i);
		print_node(i, n._if.cond);
		dedent(i);
		print_indent(i);
		printf("block:\n");
		indent(i);
		print_node(i, n._if.block);
		dedent(i);
		print_indent(i);
		printf("else_block:\n");
		indent(i);
		print_node(i, n._if.else_block);
		dedent(i);
	}
	case WHILE:
	{
		print_indent(i);
		printf("cond:\n");
		indent(i);
		print_node(i, n._while.cond);
		dedent(i);
		print_indent(i);
		printf("block:\n");
		indent(i);
		print_node(i, n._while.block);
		dedent(i);
	}
	case INCDEC:
	{
		print_indent(i);
		printf("op: %v\n", n.incdec.op);
		print_indent(i);
		printf("post: %v\n", n.incdec.post);
		print_indent(i);
		printf("expr:\n");
		indent(i);
		print_node(i, n.incdec.expr);
		dedent(i);
	}
	case ASSIGN:
	{
		print_indent(i);
		printf("lhs:\n");
		indent(i);
		print_node(i, n.assign.lhs);
		dedent(i);
		print_indent(i);
		printf("rhs:\n");
		indent(i);
		print_node(i, n.assign.rhs);
		dedent(i);
	}
	}
	dedent(i);
}

main :: proc()
{
	parser := bs.make_parser("test.bs");
	/*for t in parser.lexer.tokens
	{
		printf("%v\n", t.kind);
	}*/
	nodes := bs.parse(parser);
	//fmt.printf("%v\n", nodes[0]^);
	
	a := bs.new_value(bs.Number);
	
	i := Indenter{0, 4};
	for n in nodes
	{
		print_node(&i, n);
	}
}