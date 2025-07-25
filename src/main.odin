package main

import "base:intrinsics"
import "core:fmt"
import "core:io"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:slice"
import "core:strings"
import "core:sys/windows"
import "core:unicode/utf8"

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
// ...
// Zig goes to the logical limit more, with types-as-values.
// Odin doesn't, because it doesn't need to.
// Since Odin doesn't have CTE (Compile Time Execution), unlike Zig, there's really no need to have variables that are of type type, as you would not be able to use them anyway.
// i.e: You cannot declare a compile-time only variable in Odin; all variables are runtime.
// The constant-typeid thing is just a natural thing that comes from how Odin does parametric polymorphism.
// i.e: $n: int is the same as comptime n: isize in Zig, and $T: typeid follows from that.
// typeid is basically just an integer that uniquely identifies a type - and that can be known at runtime and compile-time -- which is why it's allowed to masquerade as an actual compile-time only type.
// ---

main :: proc() {
	// context
	context.logger = log.create_console_logger(.Debug)
	defer log.destroy_console_logger(context.logger)

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

		p2 := new_clone(100)
		//    ^^^^^^^^^^^^^^ --> allocate and initalize the value
		defer free(p2)

		fmt.println(p2^)
	}

	// arena allocator
	{
		arena: virtual.Arena
		assert(virtual.arena_init_growing(&arena) == nil)
		defer virtual.arena_destroy(&arena)
		context.allocator = virtual.arena_allocator(&arena)

		p1 := new(int)
		p2 := new(int)
		p3 := new(int)
		// no need to free individual allocation
		// `virtual.arena_destroy` will free all allocations at once
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

	// string and rune
	// (odin has nice utf8 support)
	{
		str: string = "안녕"

		byte_length := len(str)
		rune_count := utf8.rune_count_in_string(str)
		fmt.printf("byte length of \"{}\" is {}\n", str, byte_length)
		fmt.printf("rune count of \"{}\" is {}\n", str, rune_count)

		for c in str {
			// loop through a string per rune
			fmt.printf("type of \"{}\" is a {}\n", c, typeid_of(type_of(c)))
		}

		// string is immutable and does not copy on assign
		str1: string = "wow"
		str2: string = "yay"
		fmt.printf("str1: {}\n", str1)
		fmt.printf("str2: {}\n", str2)
		fmt.printf("str ptr1 == ptr2 is {}\n", raw_data(str1) == raw_data(str2))

		str2 = str1 // <-- array does not copy on assign
		//                 so both string points to the same memory
		fmt.printf("str1: {}\n", str1)
		fmt.printf("str2: {}\n", str2)
		fmt.printf("str ptr1 == ptr2 is {}\n", raw_data(str1) == raw_data(str2))
	}

	// read string from stdin
	{
		fmt.print("input: ")
		input, ok := stdin_readline()
		defer if ok do delete(input)
		if !ok {
			log.error("stdin_readline failed")
		} else {
			fmt.printf("read: {}\n", input)
			fmt.printf("rune count: {}\n", utf8.rune_count(input))
			fmt.printf("byte size: {}\n", len(input))
			for r in input do fmt.printf("rune: {}\n", r)
		}
	}

	// anonymous struct
	{
		anony_struct :: proc(s: struct {
				name: string,
				age:  int,
			}) {
			fmt.printf("{} is {} years old\n", s.name, s.age)
		}

		anony_struct({name = "John", age = 20})
	}

	// generic
	{
		Person :: struct {
			name: string,
		}

		Animal :: struct {
			name: int,
		}

		p :: proc(value: $T) where intrinsics.type_has_field(T, "name") {
			a: T = value
			fmt.printf("{}\n", a)
		}
		p(Person{name = "Tom"})
		p(Animal{name = 10})

		// geneic constraints (static assert)
		say_hello :: proc(
			somthing_with_name: $T,
		) where (intrinsics.type_field_type(T, "name") == string) {
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

	// iterator
	{
		// there is no iterator: just use a simple proc
		iter :: proc(i: ^int) -> (int, bool) {
			i^ += 2
			return i^, i^ < 10
		}

		i: int = 0
		for {
			n, next := iter(&i)
			if !next do break

			fmt.printf("{}\n", n)
		}
	}

	// allocator error
	{
		mem_alloc_test :: proc(
		) -> (
			data: ^int,
			err: mem.Allocator_Error,
		) #optional_allocator_error {
			log.info("mem_alloc_test")
			return nil, mem.Allocator_Error.Out_Of_Memory
		}

		// {
		// 	data := mem_alloc_test() // <-- Allocator_Error can be ignored because of #optional_allocator_error
		// 	num := data^ // <-- use -debug -sanitize:address to make the program crash
		// 	fmt.printf("this is fine: {}\n", num)
		// }

		{
			data, err := mem_alloc_test()
			if err != nil do log.errorf("{}", err)
		}
	}

	// file io
	{
		file_path :: "./hello.txt"
		file_content := "안녕, world!\n"

		fmt.printf("write file: \"{}\"\n", file_path)
		write_success := os.write_entire_file(file_path, transmute([]byte)file_content)
		if !write_success do return

		fmt.printf("read file: \"{}\"\n", file_path)
		bytes, read_success := os.read_entire_file(file_path)
		if !read_success do return
		defer delete(bytes)

		str := strings.string_from_ptr(&bytes[0], len(bytes))
		fmt.printf("file content: {}\n", strings.trim_right(str, "\n"))
	}

	// don't forget to free temp_allocator if your program has a infinite loop
	free_all(context.temp_allocator)
}

stdin_readline :: proc() -> (line: string = "", ok: bool = false) {
	when ODIN_OS == .Windows {
		utf16_buf: [10000]u16
		utf16_read_count: u32 = 0

		stdin_handle := windows.GetStdHandle(windows.STD_INPUT_HANDLE)
		read_console_success := windows.ReadConsoleW(
			stdin_handle,
			&utf16_buf,
			len(utf16_buf),
			&utf16_read_count,
			nil,
		)
		if !read_console_success do return

		utf8_str, alloc_err := windows.utf16_to_utf8(utf16_buf[0:utf16_read_count])
		if alloc_err != nil do return

		line, alloc_err = strings.clone(strings.trim_right(utf8_str, "\r\n"))
		if alloc_err != nil do return
	} else {
		stdin_reader := io.to_reader(os.stream_from_handle(os.stdin)) or_return

		str_builder, alloc_err := strings.builder_make()
		if alloc_err != nil do return
		defer strings.builder_destroy(&str_builder)

		io_err: io.Error = nil
		r: rune
		for {
			r, _, io_err = io.read_rune(stdin_reader)
			if io_err != nil do return

			// check delimiter
			if slice.contains([]rune{'\n', '\r'}, r) do break

			_, io_err = strings.write_rune(&str_builder, r)
			if io_err != nil do return
		}

		// clone the result to extend its lifetime
		// becuase `strings.builder_destroy` deallocates the buffer
		line, alloc_err = strings.clone(strings.to_string(str_builder))
		if alloc_err != nil do return
	}

	ok = true
	return
}
