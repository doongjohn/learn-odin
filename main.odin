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
        p = new(int)
        defer free(p)

        fmt.println(p^) 
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
            fmt.printf("what??")
        }
    }
    

    // utf8 string
    {
        str : string
        str = "안녕"
        
        count := utf8.rune_count_in_string(str)
        fmt.println("rune length: {0}", count)

        for c in str {
            fmt.println(c)
        }
    }


    // read string from stdin
    {
        input_builder := read_from_stdin()
        defer strings.destroy_builder(&input_builder)

        fmt.println(strings.to_string(input_builder))
    }
}


read_from_stdin :: proc() -> strings.Builder {
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
