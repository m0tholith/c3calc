module calculator;

import tokenizer;
import parser;
import std::io;

fn int main(String[] args)
{
    TokenList tokens = tokenizer::tokenize(args[1]);

    Literal five = {"5"};
    Expression expFive = &five;
    Literal two = {"2"};
    Expression expTwo = &two;
    Binary bin = Binary {expFive, "+", expTwo};
    Expression exp = &bin;

    Literal nine = {"9"};
    Expression expNine = &nine;
    Binary bin2 = Binary {expNine, "*", exp};
    Expression exp2 = &bin2;


    io::printfn("%s", exp2.toString());

    tokens.free();
	return 0;
}
