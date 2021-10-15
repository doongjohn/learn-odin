package main

import "core:fmt"
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

    {
        stdin_stream := os.stream_from_handle(os.stdin)
        reader := io.to_rune_reader(stdin_stream)
        seeker := io.to_seeker(stdin_stream)
        
        input_len := 0
        ch, size, err := io.read_rune(reader, &input_len)
        fmt.print(ch)
        for true {
            ch, size, err = io.read_rune(reader, &input_len)
            if ch == '\n' || err == .Empty { break }
            fmt.print(ch)
        }
        fmt.print('\n')
    }
}
