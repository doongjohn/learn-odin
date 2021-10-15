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


    // read runes from stdin
    {
        input_builder := read_from_stdin()
        defer strings.destroy_builder(&input_builder)

        fmt.println(strings.to_string(input_builder))
    }
}


read_from_stdin :: proc() -> strings.Builder {
    stdin_stream := os.stream_from_handle(os.stdin)

    Data :: struct {
        stdin_reader: io.Rune_Reader,
        input_builder: strings.Builder,
        ch: rune,
        size: int,
        err: io.Error,
    }

    data := Data{}
    data.stdin_reader = io.to_rune_reader(stdin_stream)
    data.input_builder = strings.make_builder_none()

    append_to_builder :: proc(data: ^Data) -> bool {
        data.ch, data.size, data.err = io.read_rune(data.stdin_reader)
        not_ended := data.ch != '\n' && data.err != .Empty
        if not_ended {
            // TODO: use this results
            strings.write_rune_builder(&data.input_builder, data.ch)
        }
        return not_ended
    }

    if append_to_builder(&data) {
        for true {
            if !append_to_builder(&data) {
                break
            }
        }
    }

    return data.input_builder
}