package main

// more about type system of odin
// https://discord.com/channels/568138951836172421/568871298428698645/1008856568424575178
// @Tetralux
// struct { ... } is not a struct literal, but a struct type value.
// In Odin, typeid is actually a -runtime- concept, but you can make a constant one via polymorphism ($T: typeid) in order to use it where a type is otherwise needed. (e.g: The return type of a procedure.)
// type is the type returned by type_of.
// type cannot actually be named anywhere however, as it's actually an internal compiler detail; you'd just use a constant typeid instead, via polymorphism.
// In your example, it's actually not possible to name that struct type like that, as it would be A : type : struct { .. }, but type isn't something you can use yourself like that.
// i.e: type and a constant typeid are in practical terms, interchangable.
// But typeid is otherwise just a runtime value.
// ------
// Zig goes to the logical limit more, with types-as-values.
// Odin doesn't, because it doesn't need to.
// Since Odin doesn't have CTE (Compile Time Execution), unlike Zig, there's really no need to have variables that are of type type, as you would not be able to use them anyway.
// i.e: You cannot declare a compile-time only variable in Odin; all variables are runtime.
// The constant-typeid thing is just a natural thing that comes from how Odin does parametric polymorphism.
// i.e: $n: int is the same as comptime n: isize in Zig, and $T: typeid follows from that.
// typeid is basically just an integer that uniquely identifies a type - and that can be known at runtime and compile-time -- which is why it's allowed to masquerade as an actual compile-time only type.

import "core:io"
import "core:os"
import "core:fmt"
import "core:slice"
import "core:strings"
import "core:unicode/utf8"
import "core:intrinsics"

main :: proc() {
	// pointer
	{
		p: ^int
		// ^^^^ --> pointer to int

		// new() allocates the memory and free() deallocates the memory
		// (you can use the context system to use a custom allocator)
		p = new(int)
		defer free(p)

		fmt.println(p^)
		//          ^^ --> dereference the pointer
		p^ = 10
		fmt.println(p^)
	}

	// switch case
	{
		a := 10
		b := "hello"

		switch {
		case a == 10 && b == "hi":
			fmt.printf("{}, {}\n", a, b)

		case a == 10 && b == "hello":
			fmt.printf("{}, {}\n", a, b)

		case:
			// default case
			fmt.println("what??")
		}
	}

	// string
	// (odin has nice utf8 support)
	{
		str: string = "안녕"
		fmt.printf("str = {}\n", str)
		fmt.printf("str length: {}\n", len(str))
		//                             ^^^^^^^^ --> this is a byte length

		rune_count := utf8.rune_count_in_string(str)
		fmt.printf("rune count: {}\n", rune_count)

		for c in str {
			fmt.println(c)
			//          ^ --> this is utf8 rune (not a byte)
		}
	}

	// string is immutable and does not copy on assign
	// so you must allocate a new string to modify the string
	{
		str1: string = "wow"
		str2: string = "yay"
		fmt.println(str1)
		fmt.println(str2)
		fmt.printf("str ptr1: {}\n", strings.ptr_from_string(str1))
		fmt.printf("str ptr2: {}\n", strings.ptr_from_string(str2))

		str2 = str1 // <-- array does not copy on assign
		//                 so both string points to the same buffer
		fmt.println(str1)
		fmt.println(str2)
		fmt.printf("str ptr1: {}\n", strings.ptr_from_string(str1))
		fmt.printf("str ptr2: {}\n", strings.ptr_from_string(str2))

		// strings.ptr_from_string(str1)^ = 'W' // --> Segmentation fault
	}

	// read string from stdin
	{
		fmt.print("input: ")
		input, err := stdin_readline()
		if err == .None {
			fmt.printf("read: {}\n", input)
			delete(input)
		}
	}

	// generic
	{
		Person :: struct {
			name: string,
		}

		Animal :: struct {
			name: int,
		}

		say_hello :: proc(somthing_with_name: $T)
			where intrinsics.type_field_type(T, "name") == string {
			fmt.printf("Hello, {}!\n", somthing_with_name.name)
		}

		person := Person {
			name = "John",
		}

		dog := Animal {
			name = 100,
		}

		say_hello(person)
		// say_hello(dog) // --> compile-time error (where clause fails)
	}

	// TODO: procedure group
	// TODO: context system
	// TODO: some core lib functions
}

stdin_readline :: proc() -> (str: string, error: io.Error) {
	stdin_stream := os.stream_from_handle(os.stdin)
	stdin_reader := io.to_reader(stdin_stream)
	str_builder := strings.builder_make()
	defer strings.builder_destroy(&str_builder)

	char: rune
	delimiter: rune = '\n'
	for {
		char, _ = io.read_rune(stdin_reader) or_return
		if char == delimiter {
			break
		} else {
			_ = strings.write_rune(&str_builder, char) or_return
		}
	}

	str = strings.clone(strings.to_string(str_builder))
	return
}
