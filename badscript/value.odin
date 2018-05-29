package badscript

GCObject :: struct
{
	next: ^Value,
}

Value :: struct
{
	gc: GCObject,
	variant: union {
		Null,
		True,
		False,
		Number,
		String,
		Table,
		Userdata,
	},
}

Null :: struct
{
	using value: ^Value,
}

True :: struct
{
	using value: ^Value,
}

False :: struct
{
	using value: ^Value,
}

Number :: struct
{
	using value: ^Value,
	number: f64,
}

String :: struct
{
	using value: ^Value,
	text: string,
}

Table :: struct
{
	using value: ^Value,
	
}

Userdata :: struct
{
	using value: ^Value,
	data: rawptr,
}

null_value:  ^Value;
true_value:  ^Value;
false_value: ^Value;

new_value :: proc(T: type) -> ^T
{
	v := new(Value);
	v.variant = T{value = v};
	return &(v.variant.(T));
}