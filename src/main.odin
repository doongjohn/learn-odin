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
// ...
// Zig goes to the logical limit more, with types-as-values.
// Odin doesn't, because it doesn't need to.
// Since Odin doesn't have CTE (Compile Time Execution), unlike Zig, there's really no need to have variables that are of type type, as you would not be able to use them anyway.
// i.e: You cannot declare a compile-time only variable in Odin; all variables are runtime.
// The constant-typeid thing is just a natural thing that comes from how Odin does parametric polymorphism.
// i.e: $n: int is the same as comptime n: isize in Zig, and $T: typeid follows from that.
// typeid is basically just an integer that uniquely identifies a type - and that can be known at runtime and compile-time -- which is why it's allowed to masquerade as an actual compile-time only type.
// ---

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:io"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:slice"
import "core:strings"
import "core:unicode/utf8"

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
			fmt.println("mem_alloc_test()")
			return nil, mem.Allocator_Error.Out_Of_Memory
		}

		// {
		// 	data := mem_alloc_test() // <-- Allocator_Error is ignored ???
		// 	num := data^ // <-- program crashes without printing any error
		// 	fmt.printf("this is fine: {}\n", num)
		// }

		{
			data, err := mem_alloc_test()
			if err != nil do log.errorf("{}", err)
		}
	}

	// file io
	{
		fmt.println("file io")

		file_path :: "./wow.txt"

		write_success := write_string_to_file(file_path, "안녕하세요\n")
		if !write_success do return

		content, read_success := read_string_from_file(file_path)
		if !read_success do return
		defer delete(content)

		fmt.printf("file content: {}\n", strings.trim_space(content))
	}
}

read_string_from_file :: proc(
	file_path: string,
	allocator := context.allocator,
) -> (
	content: string = "",
	ok: bool = false,
) {
	// https://manpages.opensuse.org/Tumbleweed/man-pages/open.2.en.html
	fd, open_err := os.open(file_path, os.O_RDONLY)
	defer if open_err == os.ERROR_NONE {
		close_err := os.close(fd)
		if close_err != os.ERROR_NONE {
			log.errorf("os.close err: {}", close_err)
		}
	}
	if open_err != os.ERROR_NONE {
		log.errorf("os.open err: {}", open_err)
		return
	}

	_, seek_err := os.seek(fd, 0, 0)
	if seek_err != os.ERROR_NONE {
		log.errorf("os.seek err: {}", seek_err)
		return
	}

	bytes, read_file_success := os.read_entire_file(fd, allocator)
	if !read_file_success {
		log.error("os.read_entire_file failed")
		return
	}

	content = strings.string_from_ptr(&bytes[0], len(bytes))
	ok = true

	return
}

write_string_to_file :: proc(file_path: string, content: string) -> (ok: bool = false) {
	fd, open_err := proc(file_path: string) -> (os.Handle, os.Errno) {
		when ODIN_OS == .Linux {
			// https://manpages.opensuse.org/Tumbleweed/man-pages/open.2.en.html
			flag := os.O_CREATE | os.O_WRONLY
			mode := os.S_IWUSR | os.S_IRUSR | os.S_IRGRP | os.S_IROTH
			return os.open(file_path, flag, mode)
		}

		when ODIN_OS == .Windows {
			mode := os.O_CREATE | os.O_WRONLY
			return os.open(file_path, mode)
		}

		fmt.panicf("Unsupported OS \"{}\"", ODIN_OS_STRING)
	}(file_path)

	defer if open_err == os.ERROR_NONE {
		close_err := os.close(fd)
		if close_err != os.ERROR_NONE {
			log.errorf("os.close err: {}", close_err)
		}
	}
	if open_err != os.ERROR_NONE {
		log.errorf("os.open err: {}", open_err)
		return
	}

	s, to_writer_success := io.to_writer(os.stream_from_handle(fd))
	if !to_writer_success {
		log.errorf("io.to_writer failed")
		return
	}

	if _, err := io.write_string(s, content); err != nil {
		log.errorf("io.write_string err: {}", err)
		return
	}

	ok = true
	return
}

stdin_readline :: proc() -> (str: string = "", ok: bool = false) {
	stdin_reader := io.to_reader(os.stream_from_handle(os.stdin)) or_return

	str_builder, alloc_err := strings.builder_make()
	if alloc_err != nil do return
	defer strings.builder_destroy(&str_builder)

	io_err: io.Error = nil
	r: rune
	for {
		// NOTE: io.read_rune can not read unicode in windows
		r, _, io_err = io.read_rune(stdin_reader)
		if io_err != nil do return

		// check delimiter
		if slice.contains([]rune{'\n', '\r'}, r) do break

		_, io_err = strings.write_rune(&str_builder, r)
		if io_err != nil do return
	}

	// clone the result to extend its lifetime
	// becuase `strings.builder_destroy` deallocates the buffer
	str, alloc_err = strings.clone(strings.to_string(str_builder))
	if alloc_err != nil do return

	ok = true
	return
}
