module calculator;

import tokenizer;
import parser;
import std::io;

const String ZERO  = "0";
const String ONE   = "1";
const String TWO   = "2";
const String THREE = "3";
const String FOUR  = "4";
const String FIVE  = "5";
const String SIX   = "6";
const String SEVEN = "7";
const String EIGHT = "8";
const String NINE  = "9";

fn int main(String[] args)
{
    TokenList tokens = tokenizer::tokenize(args[1]);

    Primary seven = { &SEVEN };

    Grouping group1 = { &seven };
    Grouping group2 = { &group1 };

    Primary idk = { &group1 };

    Unary idk2 = { UnaryOperator.PLUS, idk };
    Unary idk3 = { UnaryOperator.MINUS, idk };

    FactorRHS[] rhs = { { FactorOperator.DIV, idk2 } };
    Factor factor = { idk3, rhs };

    io::printn(factor.toString());

    tokens.free();
	return 0;
}
