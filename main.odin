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


    // read runes from stdin
    {
        stdin_stream := os.stream_from_handle(os.stdin)
        reader := io.to_rune_reader(stdin_stream)
        
        input_builder := strings.make_builder_none()
        input_len := 0
        
        ch, size, err := io.read_rune(reader, &input_len)
        
        num : int
        r_err : io.Error

        if ch != '\n' && err != .Empty {
            num, r_err = strings.write_rune_builder(&input_builder, ch)

            for true {
                ch, size, err = io.read_rune(reader, &input_len)
                
                if ch != '\n' && err != .Empty {
                    num, r_err = strings.write_rune_builder(&input_builder, ch)
                } else {
                    break
                }
            }
        }

        input := strings.to_string(input_builder)

        fmt.println(input)
    }
}
