module c3calc;

import tokenizer;
import parser;
import interpreter;
import std::io;

fn int main(String[] args)
{
    TokenList tokens = tokenizer::tokenize(args[1]);
    io::printn(tokens.toString());

    if (try expression = parser::parseExpression(tokens))
    {
        io::printn(expression.toString());
        double expressionValue = expression.evaluate();
        io::printfn("is equal to '%f'", expressionValue);
        expression.free();
    }
    else
    {
        io::printn("ERROR!!!!");
    }

    tokens.free();
	return 0;
}
