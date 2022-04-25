package main

import "core:io"
import "core:os"
import "core:fmt"
import "core:strings"
import "core:unicode/utf8"

main :: proc() {
	// pointer
	{
		p : ^int
		//	^^^^ --> pointer to int

		// new() allocates the memory in heap and free() deallocates the memory
		// (you can use the context system for a custom allocator)
		p = new(int)
		defer free(p)

		fmt.println(p^)
		p^ = 10 // --> dereference the pointer
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
			fmt.printf("what??")
		}
	}

	// string utf8 support is very nice
	{
		str : string
		str = "안녕"

		count := utf8.rune_count_in_string(str)
		fmt.printf("rune length: {}\n", count)

		for c in str {
			fmt.println(c)
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

		str2 = str1
		fmt.println(str1)
		fmt.println(str2)
		fmt.printf("str ptr1: {}\n", strings.ptr_from_string(str1))
		fmt.printf("str ptr2: {}\n", strings.ptr_from_string(str2))

		strings.ptr_from_string(str1)^ = 'W'
		fmt.println(str1)
		fmt.println(str2)
		fmt.printf("str ptr1: {}\n", strings.ptr_from_string(str1))
		fmt.printf("str ptr2: {}\n", strings.ptr_from_string(str2))
	}

	// read string from stdin
	{
		fmt.print("input: ")
		str_builder := readline_from_stdin()
		defer strings.destroy_builder(&str_builder)

		input := strings.to_string(str_builder)
		fmt.printf("read: {}\n", input)
	}
}


readline_from_stdin :: proc() -> strings.Builder {
	stdin_stream := os.stream_from_handle(os.stdin)
	stdin_reader := io.to_byte_reader(stdin_stream)
	input_builder := strings.make_builder_none()

	ch: byte
	err: io.Error

	for {
		ch, err = io.read_byte(stdin_reader)
		if ch == '\n' || err != .None { break }
		strings.write_byte(&input_builder, ch)
	}

	return input_builder
}
