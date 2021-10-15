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
}
