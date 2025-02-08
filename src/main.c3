module c3calc;

import tokenizer;
import parser;
import interpreter;
import std::io;

fn int main(String[] args)
{
    Interpreter interpreter;
    interpreter.new_init();

    if (try result = interpreter.evaluate(args[1]))
    {
        io::printfn("%s = %f", interpreter.format(args[1])!!, result);
    }
    else
    {
        io::printn("ERROR!!!!");
    }

	return 0;
}
