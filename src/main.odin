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

import "core:io"
import "core:os"
import "core:mem"
import "core:log"
import "core:fmt"
import "core:slice"
import "core:strings"
import "core:unicode/utf8"
import "core:intrinsics"
import "core:runtime"

main :: proc() {
	context.logger = log.create_console_logger()

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

		// default case
		case:
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
			fmt.printf("type of \"{}\" is a {}\n", c, type_info_of(type_of(c)))
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
		stdin_reader, ok := io.to_reader(os.stream_from_handle(os.stdin))
		if !ok {
			log.error("io.to_reader failed")
		} else {
			input, ok := stdin_readline(stdin_reader)
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
	}

	// generic
	{
		Person :: struct {
			name: string,
		}

		Animal :: struct {
			name: int,
		}

		// geneic constraints (static assert)
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

	// memory error
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
			if err != nil {
				log.errorf("{}", err)
			}
		}
	}

	// file io
	{
		fmt.println("file io")

		file_path :: "./wow.txt"

		if os.exists(file_path) {
			fmt.printf("removing: {}\n", file_path)
			err := os.remove(file_path)
			if err != os.ERROR_NONE {
				log.errorf("os.remove err: {}", err)
			}
		}

		fmt.printf("creating: {}\n", file_path)
		// https://manpages.opensuse.org/Tumbleweed/man-pages/open.2.en.html
		fd, err := os.open(
			file_path,
			os.O_CREATE | os.O_RDWR,
			os.S_IWUSR | os.S_IRUSR | os.S_IRGRP | os.S_IROTH,
		)
		defer os.close(fd)

		if err != os.ERROR_NONE {
			log.errorf("os.open err: {}", err)
		} else {
			s, ok := io.to_writer(os.stream_from_handle(fd))
			if ok {
				_, write_err := io.write_string(s, "안녕하세요!\n")
				if write_err != nil {
					log.errorf("io.write_string err: {}", write_err)
				} else {
					fmt.print("text written: ")
					_, seek_err := os.seek(fd, 0, 0)
					if seek_err != os.ERROR_NONE {
						log.errorf("os.seek err: {}", seek_err)
					} else {
						content, ok := os.read_entire_file(fd)
						if !ok {
							log.error("os.read_entire_file failed")
						} else {
							fmt.print(strings.string_from_ptr(&content[0], len(content)))
						}
					}
				}
			}
		}
	}
}

stdin_readline :: proc(stdin_reader: io.Reader) -> (str: string = "", ok: bool = false) {
	mem_err: mem.Allocator_Error = nil

	str_builder: strings.Builder
	str_builder, mem_err = strings.builder_make()
	defer if mem_err != nil do strings.builder_destroy(&str_builder)
	if mem_err != nil do return

	io_err: io.Error = nil
	r: rune
	for {
		r, _, io_err = io.read_rune(stdin_reader)
		if io_err != nil do return

		if slice.contains([]rune{'\n', '\r'}, r) do break

		_, io_err = strings.write_rune(&str_builder, r)
		if io_err != nil do return
	}

	// clone the result to extend its lifetime
	// becuase `strings.builder_destroy` deallocates the buffer
	str, mem_err = strings.clone(strings.to_string(str_builder))
	if mem_err != nil do return

	return str, true
}
